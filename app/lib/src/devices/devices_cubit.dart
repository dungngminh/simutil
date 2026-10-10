import 'dart:async';
import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_shared/simutil_shared.dart';

import 'devices_state.dart';

/// Reads and toggles slim mode for an iOS simulator.
abstract interface class SlimControl {
  Future<bool> isSlim(String udid);
  Future<void> setSlim(String udid, {required bool slim});
}

/// Loads Android and iOS device lists, refreshes them periodically, and
/// starts, stops and slims emulators/simulators.
class DevicesCubit extends CubitSignal<DevicesState> {
  DevicesCubit({
    required DeviceService android,
    required DeviceService ios,
    SlimControl? slim,
    bool? loadIos,
  }) : _android = android,
       _ios = ios,
       _slim = slim,
       _loadIos = loadIos ?? Platform.isMacOS,
       super(initialState: const DevicesState());

  static const _loadTimeout = Duration(seconds: 20);

  /// Emulator flags for streaming-only runs: no window, audio or boot
  /// animation, so many emulators fit at once.
  static const headlessAndroidArgs = [
    '-no-window',
    '-no-audio',
    '-no-boot-anim',
  ];

  final DeviceService _android;
  final DeviceService _ios;
  final SlimControl? _slim;
  final bool _loadIos;
  Timer? _timer;

  /// Loads once, then refreshes every [kReloadInterval].
  void start() {
    unawaited(refresh());
    _timer ??= Timer.periodic(kReloadInterval, (_) => refresh(silent: true));
  }

  /// Reloads every list; [silent] keeps the loading flag off.
  Future<void> refresh({bool silent = false}) async {
    if (stateValue.loading) return;
    if (!silent) emit(stateValue.copyWith(loading: true));

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
        message: stateValue.message,
      ),
    );
  }

  /// Boots an emulator/simulator; [headless] skips its window, [coldBoot]
  /// skips the Android snapshot.
  Future<void> launch(
    Device device, {
    bool headless = false,
    bool coldBoot = false,
  }) async {
    if (device.type.isPhysical || device.state != DeviceState.shutdown) return;
    _setBusy(device.id, true, 'Starting ${device.name}…');
    final service = device.os == DeviceOs.android ? _android : _ios;
    final launching = service.launchDevice(
      deviceId: device.id,
      headless: headless,
      additionalArgs: [
        if (coldBoot && device.os == DeviceOs.android) '-no-snapshot-load',
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
    final service = device.os == DeviceOs.android ? _android : _ios;
    final ok = await service.shutdownSimulator(deviceId: device.id);
    if (!ok) _setMessage('Failed to stop ${device.name}');
    await _settle(device.id);
  }

  /// Turns slim mode on or off; reboots the simulator when it is running.
  Future<void> toggleSlim(Device device) async {
    final slim = _slim;
    if (slim == null || device.os != DeviceOs.ios || device.type.isPhysical) {
      return;
    }
    final on = !stateValue.slimmed.contains(device.id);
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
        message: message,
      ),
    );
  }

  void _setMessage(String message) {
    if (!isClosed) emit(stateValue.copyWith(message: message));
  }

  Future<List<Device>> _load(Future<List<Device>> Function() loader) async {
    try {
      return await loader().timeout(_loadTimeout);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}
