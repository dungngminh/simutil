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
    Future<bool> Function()? cameraAccess,
  }) : _android = android,
       _cameraAccess = cameraAccess ?? _requestCameraAccess,
       _slimOnLaunch = slimOnLaunch,
       _pollInterval = pollInterval,
       _ios = ios,
       _slim = slim,
       _loadIos = loadIos ?? Platform.isMacOS,
       super(initialState: const DevicesState());

  static const _loadTimeout = Duration(seconds: 20);

  /// How long [restart] waits for the old process to exit.
  static const _stopTimeout = Duration(seconds: 30);

  final DeviceService _android;
  final DeviceService _ios;

  /// Asks for Camera access before an emulator boots with a host webcam.
  final Future<bool> Function() _cameraAccess;
  final SlimControl? _slim;

  /// Whether simulators are written slim before they boot (Slim mode).
  final bool Function()? _slimOnLaunch;

  /// Gap between [restart]'s shutdown checks.
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

  /// Reloads every list; [silent] keeps the loading flag off. Single-flight:
  /// a call while a reload runs joins it instead of stacking another one
  /// (polls must never pile up behind slow adb / simctl).
  Future<void> refresh({bool silent = false}) {
    if (!silent && !stateValue.loading) {
      emit(stateValue.copyWith(loading: true));
    }
    return _refreshing ??= _reload().whenComplete(() => _refreshing = null);
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
      launching.catchError(
        (Object e) => _setMessage('Failed to start ${device.name}: $e'),
      ),
    );
    await _settle(device.id);
  }

  /// Shuts an emulator/simulator down.
  Future<void> shutdown(Device device) async {
    if (device.type.isPhysical) return;
    _setBusy(device.id, true, 'Stopping ${device.name}…');
    final ok = await _serviceFor(device).shutdownSimulator(deviceId: device.id);
    if (!ok) _setMessage('Failed to stop ${device.name}');
    await _settle(device.id);
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
        ? await _waitForShutdown(service, device)
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

  /// Polls until [device] is listed as shut down; an Android emulator comes
  /// back under its AVD name instead of its serial.
  Future<Device?> _waitForShutdown(DeviceService service, Device device) async {
    final deadline = DateTime.now().add(_stopTimeout);
    while (!isClosed && DateTime.now().isBefore(deadline)) {
      final match = (await _load(service.getSimulators))
          .where(
            (d) => device.os == DeviceOs.android
                ? d.name == device.name
                : d.id == device.id,
          )
          .firstOrNull;
      if (match?.state == DeviceState.shutdown) return match;
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
