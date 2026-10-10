import 'dart:async';
import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_core/simutil_core.dart';

import '../settings/device_settings_cubit.dart';
import 'ios/ios_sim_session.dart';
import 'streams_state.dart';

/// Creates the platform session for a device, or throws a user-facing
/// message when it cannot.
typedef DeviceSessionFactory = Future<DeviceSession> Function(Device device);

/// Open device sessions shown in the grid.
class StreamsCubit extends CubitSignal<StreamsState> {
  StreamsCubit(this._create, {this.onSaved})
    : super(initialState: const StreamsState());

  final DeviceSessionFactory _create;

  /// Called with each finished recording.
  final void Function(String path)? onSaved;
  final _sessions = <String, DeviceSession>{};
  final _subscriptions = <String, StreamSubscription<SessionStatus>>{};

  /// Device names to stream as soon as they show up booted. Names, because
  /// an Android emulator's id changes from AVD name to serial on boot.
  final _pendingByName = <String>{};

  /// The live session behind an entry, if it was created.
  DeviceSession? sessionFor(String deviceId) => _sessions[deviceId];

  /// Whether [device] can be streamed on this host.
  static bool canStream(Device device) =>
      device.state == DeviceState.booted &&
      (device.os == DeviceOs.android ||
          (Platform.isMacOS && !device.type.isPhysical));

  Future<void> open(Device device) async {
    if (stateValue.isOpen(device.id)) return;
    _setEntries([
      ...stateValue.entries,
      StreamEntry(device: device, status: const SessionConnecting()),
    ]);
    final DeviceSession session;
    try {
      session = await _create(device);
    } catch (e) {
      _update(device.id, (e0) => e0.copyWith(status: SessionFailed('$e')));
      return;
    }
    if (!stateValue.isOpen(device.id)) return;
    _sessions[device.id] = session;
    _subscriptions[device.id] = session.statusChanges.listen(
      (status) => _update(device.id, (e) => e.copyWith(status: status)),
    );
    await session.start();
  }

  /// Opens [device] once it is booted (after a headless start).
  void openWhenBooted(Device device) => _pendingByName.add(device.name);

  /// When an open stream's device was first seen not running.
  final _missingSince = <String, DateTime>{};

  /// How long a device may be missing from the lists before its stream is
  /// closed; longer than one refresh so a single failed load is ignored.
  static const missingGrace = Duration(seconds: 15);

  /// Feed of device lists: opens pending devices that are now booted and
  /// closes streams whose device was shut down outside the app.
  void onDevices(Iterable<Device> devices, {DateTime? now}) {
    final time = now ?? DateTime.now();
    final booted = {
      for (final d in devices)
        if (d.state == DeviceState.booted) d.id,
    };
    for (final entry in stateValue.entries) {
      final id = entry.device.id;
      if (booted.contains(id)) {
        _missingSince.remove(id);
      } else if (time.difference(_missingSince.putIfAbsent(id, () => time)) >=
          missingGrace) {
        _missingSince.remove(id);
        unawaited(closeStream(id));
      }
    }

    if (_pendingByName.isEmpty) return;
    for (final device in devices) {
      if (_pendingByName.contains(device.name) && canStream(device)) {
        _pendingByName.remove(device.name);
        unawaited(open(device));
      }
    }
  }

  Future<void> closeStream(String deviceId) async {
    _setEntries([
      for (final e in stateValue.entries)
        if (e.device.id != deviceId) e,
    ]);
    await _subscriptions.remove(deviceId)?.cancel();
    await _sessions.remove(deviceId)?.stop();
  }

  /// Starts or stops recording [deviceId] into [directory].
  Future<String?> toggleRecording(String deviceId, String directory) async {
    final session = _sessions[deviceId];
    if (session == null) return null;
    if (session.isRecording) {
      final path = await session.stopRecording();
      _update(deviceId, (e) => e.copyWith(recording: false));
      if (path != null) onSaved?.call(path);
      return path;
    }
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    await session.startRecording('$directory/simutil-$deviceId-$stamp.mp4');
    _update(deviceId, (e) => e.copyWith(recording: true));
    return null;
  }

  void _update(String deviceId, StreamEntry Function(StreamEntry) change) {
    if (isClosed) return;
    _setEntries([
      for (final e in stateValue.entries)
        e.device.id == deviceId ? change(e) : e,
    ]);
  }

  void _setEntries(List<StreamEntry> entries) => emit(StreamsState(entries));

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    for (final session in _sessions.values) {
      await session.stop();
    }
    _sessions.clear();
    await super.close();
  }
}

/// Default factory: scrcpy for Android, the native capture for iOS
/// simulators.
DeviceSessionFactory defaultSessionFactory({
  required CommandExec exec,
  required String Function() adbPath,
  required DeviceSettings Function(Device device) settings,
}) {
  Future<ScrcpyInstall?>? scrcpy;
  return (device) async {
    switch (device.os) {
      case DeviceOs.android:
        final install = await (scrcpy ??= ScrcpyInstall.locate(exec));
        if (install == null) {
          scrcpy = null;
          throw ScrcpyInstall.installHint;
        }
        final options = settings(device);
        return ScrcpySession(
          serial: device.id,
          adbPath: adbPath(),
          install: install,
          exec: exec,
          maxSize: options.maxSize,
          maxFps: options.maxFps,
          videoBitRate: options.bitRateMbps * 1000000,
        );
      case DeviceOs.ios:
        if (!Platform.isMacOS || device.type.isPhysical) {
          throw 'Only iOS simulators on macOS can be streamed';
        }
        return IosSimSession(device.id, exec: exec);
    }
  };
}
