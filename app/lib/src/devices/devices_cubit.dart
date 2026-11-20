import 'dart:async';
import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/services.dart';
import 'package:simutil_app/src/devices/devices_state.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_shared/simutil_shared.dart';

/// Reads and toggles slim mode for an iOS simulator.
abstract interface class SlimControl {
  Future<bool> isSlim(String udid);
  Future<void> setSlim(String udid, {required bool slim});
}

/// How a [DeviceNotice] reads: [busy] stays up (with a spinner) until the
/// next notice for the same device replaces it.
enum DeviceNoticeKind { info, busy, success, error }

/// A [DevicesCubit.notices] message. [deviceId] ties a [DeviceNoticeKind.busy]
/// notice to the result that replaces it.
typedef DeviceNotice = ({String text, DeviceNoticeKind kind, String? deviceId});

/// Loads Android and iOS device lists, reloads them when a platform
/// reports a change, and starts, stops and slims emulators/simulators.
class DevicesCubit extends CubitSignal<DevicesState> {
  DevicesCubit({
    required DeviceService android,
    required DeviceService ios,
    SlimControl? slim,
    bool Function()? slimOnLaunch,
    bool? loadIos,
    Duration pollInterval = const Duration(seconds: 1),
    Duration launchTimeout = const Duration(minutes: 2),
    Duration stopTimeout = const Duration(seconds: 30),
    Future<bool> Function()? cameraAccess,
  }) : _android = android,
       _launchTimeout = launchTimeout,
       _stopTimeout = stopTimeout,
       _cameraAccess = cameraAccess ?? _requestCameraAccess,
       _slimOnLaunch = slimOnLaunch,
       _pollInterval = pollInterval,
       _ios = ios,
       _slim = slim,
       _loadIos = loadIos ?? Platform.isMacOS,
       super(initialState: const DevicesState());

  static const _loadTimeout = Duration(seconds: 20);

  /// How long [shutdown] and [restart] wait for the process to exit.
  final Duration _stopTimeout;

  /// How long [launch] waits for the device to list as booted; a cold boot
  /// can take a while before adb sees the emulator.
  final Duration _launchTimeout;

  final DeviceService _android;
  final DeviceService _ios;

  /// Asks for Camera access before an emulator boots with a host webcam.
  final Future<bool> Function() _cameraAccess;
  final SlimControl? _slim;

  /// Whether simulators are written slim before they boot (Slim mode).
  final bool Function()? _slimOnLaunch;

  /// Gap between the state checks of [launch], [shutdown] and [restart].
  final Duration _pollInterval;
  final bool _loadIos;
  DeviceChangeWatcher? _watcher;
  final _notices = StreamController<DeviceNotice>.broadcast();

  /// One-off progress and error messages ("Stopping Pixel 7…"), shown as
  /// toasts; not state, so nothing lingers once the action is done.
  Stream<DeviceNotice> get notices => _notices.stream;

  /// Loads once, then reloads whenever adb / CoreSimulator / usbmuxd report
  /// a change (no polling beyond a slow [kReloadInterval] fallback).
  void start() {
    unawaited(refresh());
    _watcher ??= DeviceChangeWatcher([
      _android,
      if (_loadIos) _ios,
    ], () => refresh(silent: true))..start();
  }

  Future<void>? _refreshing;
  Future<void>? _refreshAgain;

  /// Reloads every list; [silent] keeps the loading flag off. A call while a
  /// reload runs queues one more reload after it, shared by every caller
  /// meanwhile: the running one may have read its lists before the change
  /// that triggered this call (e.g. adb reporting a booted emulator), and
  /// joining it would lose that change until the next fallback reload.
  /// Reloads never pile up beyond that one.
  Future<void> refresh({bool silent = false}) {
    if (!silent && !stateValue.loading) {
      emit(stateValue.copyWith(loading: true));
    }
    final running = _refreshing;
    if (running == null) {
      return _refreshing = _reload().whenComplete(() => _refreshing = null);
    }
    // Runs after a failed reload too (its caller gets the error), or the
    // queued one would stay stuck on that failure.
    return _refreshAgain ??= running.catchError((Object _) {}).then((_) {
      _refreshAgain = null;
      return refresh(silent: true);
    });
  }

  Future<void> _reload() async {
    final results = await Future.wait([
      _load(_android.getSimulators),
      _load(_android.getPhysicalDevices),
      if (_loadIos) ...[
        _load(_ios.getSimulators),
        _load(_ios.getPhysicalDevices),
      ],
    ]);
    final iosSimulators = _loadIos ? results[2] : const <Device>[];
    final slimmed = <String>{};
    if (_slim case final slim?) {
      for (final sim in iosSimulators) {
        if (await slim.isSlim(sim.id)) slimmed.add(sim.id);
      }
    }
    if (isClosed) return;
    emit(
      DevicesState(
        androidEmulators: results[0],
        androidDevices: results[1],
        iosSimulators: iosSimulators,
        iosDevices: _loadIos ? results[3] : const [],
        slimmed: slimmed,
        busy: stateValue.busy,
      ),
    );
  }

  /// Boots an emulator/simulator; [headless] skips its window, [coldBoot]
  /// skips the Android snapshot, [noAudio] boots an Android emulator mute,
  /// [cameraArgs] (from `emulatorCameraArgs`) pick its camera sources.
  Future<void> launch(
    Device device, {
    bool headless = false,
    bool coldBoot = false,
    bool noAudio = false,
    List<String> cameraArgs = const [],
  }) async {
    if (device.type.isPhysical || device.state != DeviceState.shutdown) return;
    _setBusy(device.id, true, 'Starting ${device.name}…');
    final android = device.os == DeviceOs.android;
    // Slim mode: write the slim config while the simulator is still shut
    // down, so it boots slim without an extra reboot.
    if (!android &&
        (_slimOnLaunch?.call() ?? false) &&
        !stateValue.slimmed.contains(device.id)) {
      try {
        await _slim?.setSlim(device.id, slim: true);
      } catch (e) {
        _setMessage('Slim failed for ${device.name}: $e');
      }
    }
    // The emulator reads the webcam under SimUtil's Camera permission;
    // without it the camera gets no frames and the emulator's screen hangs.
    var camera = android ? cameraArgs : const <String>[];
    if (camera.any((a) => a.startsWith('webcam')) && !await _cameraAccess()) {
      _setMessage(
        'Allow SimUtil in System Settings › Privacy & Security › Camera to '
        'use a webcam; starting ${device.name} with its own cameras',
      );
      camera = const [];
    }
    var failed = false;
    final launching = _serviceFor(device).launchDevice(
      deviceId: device.id,
      headless: headless,
      additionalArgs: [
        if (coldBoot && android) '-no-snapshot-load',
        if (noAudio && android) '-no-audio',
        ...camera,
      ],
    );
    unawaited(
      launching.catchError((Object e) {
        failed = true;
        _setMessage('Failed to start ${device.name}: $e');
      }),
    );
    // Busy (a spinner, not Start) until the device lists as booted: an
    // emulator takes seconds before adb reports it.
    await _waitForState(
      device,
      DeviceState.booted,
      timeout: _launchTimeout,
      abort: () => failed,
    );
    _setBusy(device.id, false);
    await refresh(silent: true);
  }

  /// Shuts an emulator/simulator down.
  Future<void> shutdown(Device device) async {
    if (device.type.isPhysical) return;
    _setBusy(device.id, true, 'Stopping ${device.name}…');
    final ok = await _serviceFor(device).shutdownSimulator(deviceId: device.id);
    if (ok) {
      // The emulator takes a moment to exit after `emu kill`; until then it
      // still lists as booted.
      await _waitForState(device, DeviceState.shutdown, timeout: _stopTimeout);
    } else {
      _setMessage('Failed to stop ${device.name}');
    }
    _setBusy(device.id, false);
    await refresh(silent: true);
  }

  /// Shuts a running emulator/simulator down, waits for it to stop, then
  /// boots it again with the [launch] options.
  Future<void> restart(
    Device device, {
    bool headless = false,
    bool coldBoot = false,
    bool noAudio = false,
    List<String> cameraArgs = const [],
  }) async {
    if (device.type.isPhysical || device.state != DeviceState.booted) return;
    _setBusy(device.id, true, 'Restarting ${device.name}…');
    final service = _serviceFor(device);
    final stopped = await service.shutdownSimulator(deviceId: device.id)
        ? await _waitForState(
            device,
            DeviceState.shutdown,
            timeout: _stopTimeout,
          )
        : null;
    _setBusy(device.id, false);
    if (stopped == null) {
      _setMessage('Failed to restart ${device.name}');
      return refresh(silent: true);
    }
    await launch(
      stopped,
      headless: headless,
      coldBoot: coldBoot,
      noAudio: noAudio,
      cameraArgs: cameraArgs,
    );
  }

  /// Polls until [device] lists in state [want] and returns it, or null
  /// after [timeout] or once [abort] returns true. An Android emulator
  /// lists under its serial while it runs and under its AVD name when it
  /// is off, so it is matched by name.
  Future<Device?> _waitForState(
    Device device,
    DeviceState want, {
    required Duration timeout,
    bool Function()? abort,
  }) async {
    final service = _serviceFor(device);
    final deadline = DateTime.now().add(timeout);
    // Checks at least once, also with a zero timeout.
    while (!isClosed && !(abort?.call() ?? false)) {
      final match = (await _load(service.getSimulators))
          .where(
            (d) => device.os == DeviceOs.android
                ? d.name == device.name
                : d.id == device.id,
          )
          .firstOrNull;
      if (match?.state == want) return match;
      if (!DateTime.now().isBefore(deadline)) return null;
      await Future<void>.delayed(_pollInterval);
    }
    return null;
  }

  /// Permanently deletes a shut-down emulator/simulator.
  Future<void> delete(Device device) async {
    if (device.type.isPhysical || device.state != DeviceState.shutdown) return;
    _setBusy(device.id, true);
    _progress(device, 'Deleting ${device.name}…');
    final ok = await _serviceFor(device).deleteSimulator(deviceId: device.id);
    _result(device, ok, 'Deleted ${device.name}', 'Failed to delete');
    await _settle(device.id);
  }

  /// Erases a shut-down simulator / emulator's data (factory reset).
  Future<void> wipeData(Device device) async {
    if (device.type.isPhysical || device.state != DeviceState.shutdown) return;
    _setBusy(device.id, true);
    _progress(device, 'Wiping ${device.name}…');
    final ok = await _serviceFor(device).wipeData(deviceId: device.id);
    _result(device, ok, 'Wiped ${device.name}', 'Failed to wipe');
    await _settle(device.id);
  }

  /// A loading toast for [device], replaced by its [_result].
  void _progress(Device device, String text) =>
      _notify(text, DeviceNoticeKind.busy, deviceId: device.id);

  void _result(Device device, bool ok, String done, String failed) => _notify(
    ok ? done : '$failed ${device.name}',
    ok ? DeviceNoticeKind.success : DeviceNoticeKind.error,
    deviceId: device.id,
  );

  DeviceService _serviceFor(Device device) =>
      device.os == DeviceOs.android ? _android : _ios;

  /// Turns slim mode on or off; reboots the simulator when it is running.
  /// Turns slim on or off for an iOS simulator, rebooting it when booted.
  /// Streams are not touched: go through `SlimModeCubit` to keep them.
  Future<void> setSlim(Device device, {required bool on}) async {
    final slim = _slim;
    if (slim == null || device.os != DeviceOs.ios || device.type.isPhysical) {
      return;
    }
    if (stateValue.slimmed.contains(device.id) == on) return;
    _setBusy(
      device.id,
      true,
      '${on ? 'Slimming' : 'Restoring'} ${device.name}…',
    );
    try {
      await slim.setSlim(device.id, slim: on);
    } catch (e) {
      _setMessage('Slim failed for ${device.name}: $e');
    }
    await _settle(device.id);
  }

  Future<void> _settle(String deviceId) async {
    await Future<void>.delayed(kReloadAfterActionInterval);
    _setBusy(deviceId, false);
    await refresh(silent: true);
  }

  void _setBusy(String id, bool busy, [String? message]) {
    if (isClosed) return;
    emit(
      stateValue.copyWith(
        busy: busy
            ? {...stateValue.busy, id}
            : ({...stateValue.busy}..remove(id)),
      ),
    );
    if (message != null) _notify(message, DeviceNoticeKind.info);
  }

  /// Shows [text] as a toast, e.g. progress of an MCP tool.
  void notify(String text, {bool error = false}) =>
      _notify(text, error ? DeviceNoticeKind.error : DeviceNoticeKind.info);

  void _notify(String text, DeviceNoticeKind kind, {String? deviceId}) {
    if (!isClosed) {
      _notices.add((text: text, kind: kind, deviceId: deviceId));
    }
  }

  void _setMessage(String message) => notify(message, error: true);

  Future<List<Device>> _load(Future<List<Device>> Function() loader) async {
    try {
      return await loader().timeout(_loadTimeout);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> close() async {
    await _notices.close();
    await _watcher?.stop();
    await super.close();
  }
}

/// macOS asks the user once; other platforms have no camera permission.
Future<bool> _requestCameraAccess() async =>
    !Platform.isMacOS ||
    (await const MethodChannel(
          'simutil/ios_device_stream',
        ).invokeMethod<bool>('camera_access') ??
        false);
