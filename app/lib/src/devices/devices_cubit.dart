import 'dart:async';
import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_shared/simutil_shared.dart';

import 'devices_state.dart';

/// Loads Android and iOS device lists, refreshes them periodically, and
/// launches emulators/simulators.
class DevicesCubit extends CubitSignal<DevicesState> {
  DevicesCubit({
    required DeviceService android,
    required DeviceService ios,
    bool? loadIos,
  }) : _android = android,
       _ios = ios,
       _loadIos = loadIos ?? Platform.isMacOS,
       super(initialState: const DevicesState());

  static const _loadTimeout = Duration(seconds: 20);

  final DeviceService _android;
  final DeviceService _ios;
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
    if (isClosed) return;
    emit(
      DevicesState(
        androidEmulators: results[0],
        androidDevices: results[1],
        iosSimulators: _loadIos ? results[2] : const [],
        iosDevices: _loadIos ? results[3] : const [],
        message: stateValue.message,
      ),
    );
  }

  /// Boots an emulator/simulator. Physical devices are ignored.
  Future<void> launch(Device device) async {
    if (device.type.isPhysical || device.state != DeviceState.shutdown) return;
    emit(stateValue.copyWith(message: 'Launching ${device.name}…'));
    final service = device.os == DeviceOs.android ? _android : _ios;
    // ponytail: not awaited; the Android launcher may block until the
    // emulator exits.
    unawaited(
      service
          .launchDevice(deviceId: device.id)
          .catchError(
            (Object e) => _setMessage('Failed to launch ${device.name}: $e'),
          ),
    );
    await Future<void>.delayed(kReloadAfterActionInterval);
    await refresh(silent: true);
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
