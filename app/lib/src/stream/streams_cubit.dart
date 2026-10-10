import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:simutil_core/simutil_core.dart';

import 'android/scrcpy_install.dart';
import 'android/scrcpy_stream.dart';
import 'device_stream.dart';
import 'ios/ios_sim_stream.dart';
import 'streams_state.dart';

/// Creates the platform stream for a device, or throws a user-facing
/// message when it cannot.
typedef DeviceStreamFactory = Future<DeviceStream> Function(Device device);

/// Open device streams shown in the grid.
class StreamsCubit extends CubitSignal<StreamsState> {
  StreamsCubit(this._create) : super(initialState: const StreamsState());

  final DeviceStreamFactory _create;
  final _streams = <String, DeviceStream>{};

  /// The live stream behind an entry, if it was created.
  DeviceStream? streamFor(String deviceId) => _streams[deviceId];

  /// Whether [device] can be streamed on this host.
  static bool canStream(Device device) =>
      device.state == DeviceState.booted &&
      (device.os == DeviceOs.android ||
          (Platform.isMacOS && !device.type.isPhysical));

  Future<void> open(Device device) async {
    if (stateValue.isOpen(device.id)) return;
    _setEntries([
      ...stateValue.entries,
      StreamEntry(device: device, status: const StreamConnecting()),
    ]);
    final DeviceStream stream;
    try {
      stream = await _create(device);
    } catch (e) {
      _setStatus(device.id, StreamFailed('$e'));
      return;
    }
    if (!stateValue.isOpen(device.id)) return;
    _streams[device.id] = stream;
    await stream.start((status) => _setStatus(device.id, status));
  }

  Future<void> closeStream(String deviceId) async {
    _setEntries([
      for (final e in stateValue.entries)
        if (e.device.id != deviceId) e,
    ]);
    await _streams.remove(deviceId)?.stop();
  }

  void _setStatus(String deviceId, StreamStatus status) {
    if (isClosed) return;
    _setEntries([
      for (final e in stateValue.entries)
        e.device.id == deviceId ? e.withStatus(status) : e,
    ]);
  }

  void _setEntries(List<StreamEntry> entries) => emit(StreamsState(entries));

  @override
  Future<void> close() async {
    for (final stream in _streams.values) {
      await stream.stop();
    }
    _streams.clear();
    await super.close();
  }
}

/// Default factory: scrcpy for Android, the native capture for iOS
/// simulators.
DeviceStreamFactory defaultStreamFactory({
  required CommandExec exec,
  required String Function() adbPath,
}) {
  Future<ScrcpyInstall?>? scrcpy;
  return (device) async {
    switch (device.os) {
      case DeviceOs.android:
        final install = await (scrcpy ??= ScrcpyInstall.locate(exec));
        if (install == null) {
          scrcpy = null; // retry after the user installs it
          throw ScrcpyInstall.installHint;
        }
        return ScrcpyStream(
          serial: device.id,
          adbPath: adbPath(),
          install: install,
          exec: exec,
        );
      case DeviceOs.ios:
        if (!Platform.isMacOS || device.type.isPhysical) {
          throw 'Only iOS simulators on macOS can be streamed';
        }
        return IosSimStream(device.id, exec: exec);
    }
  };
}
