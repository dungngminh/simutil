import 'dart:async';
import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_core/simutil_core.dart';

import 'package:simutil_app/src/recording/recording_lock.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/stream/ios/ios_sim_session.dart';
import 'package:simutil_app/src/stream/streams_state.dart';

/// Creates the platform session for a device, or throws a user-facing
/// message when it cannot.
typedef DeviceSessionFactory = Future<DeviceSession> Function(Device device);

/// Open device sessions shown in the grid.
class StreamsCubit extends CubitSignal<StreamsState> {
  /// Opens sessions with [_create]; [onSaved] gets each finished recording.
  StreamsCubit(this._create, {this.onSaved, RecordingLock? recordingLock})
    : _recordingLock = recordingLock ?? RecordingLock(),
      super(initialState: const StreamsState());

  /// One recording at a time, shared with the grid recorder.
  final RecordingLock _recordingLock;

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

  /// Session starts waiting to run; they run one at a time (adb
  /// push/forward, simulator capture) in FIFO order.
  final _startQueue = <(Device, Object, Completer<void>)>[];
  bool _draining = false;

  /// The pending start per device; closing or reopening replaces it so a
  /// stale queued start is skipped.
  final _queued = <String, Object>{};

  /// Adds [device]'s tile as connecting and queues its session start;
  /// completes once that start ran (or was skipped). Opening a device that
  /// is already open does nothing.
  Future<void> open(Device device) {
    if (stateValue.isOpen(device.id)) return Future.value();
    _setEntries([
      ...stateValue.entries,
      StreamEntry(device: device, status: const SessionConnecting()),
    ]);
    final ticket = _queued[device.id] = Object();
    final done = Completer<void>();
    _startQueue.add((device, ticket, done));
    unawaited(_drain());
    return done.future;
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    while (_startQueue.isNotEmpty) {
      final (device, ticket, done) = _startQueue.removeAt(0);
      try {
        await _start(device, ticket);
      } catch (_) {
        // A failed start must not stall the queue.
      }
      done.complete();
    }
    _draining = false;
  }

  Future<void> _start(Device device, Object ticket) async {
    if (isClosed || _queued[device.id] != ticket) return;
    final DeviceSession session;
    try {
      session = await _create(device);
    } catch (e) {
      if (_queued.remove(device.id) == ticket) {
        _update(device.id, (e0) => e0.copyWith(status: SessionFailed('$e')));
      }
      return;
    }
    if (isClosed || _queued[device.id] != ticket) {
      await session.stop();
      return;
    }
    _queued.remove(device.id);
    _sessions[device.id] = session;
    _subscriptions[device.id] = session.statusChanges.listen(
      (status) => _update(device.id, (e) => e.copyWith(status: status)),
    );
    try {
      await session.start();
    } catch (e) {
      _update(device.id, (e0) => e0.copyWith(status: SessionFailed('$e')));
    }
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

  /// Closes [deviceId]'s tile and stops its session (or drops its queued start).
  Future<void> closeStream(String deviceId) async {
    _queued.remove(deviceId);
    _setEntries([
      for (final e in stateValue.entries)
        if (e.device.id != deviceId) e,
    ]);
    await _subscriptions.remove(deviceId)?.cancel();
    await _sessions.remove(deviceId)?.stop();
    _recordingLock.release(deviceId);
  }

  /// Starts or stops recording [deviceId] into [directory]. Throws
  /// [RecordingInProgress] when the grid or another device is recording.
  Future<String?> toggleRecording(String deviceId, String directory) async {
    final session = _sessions[deviceId];
    if (session == null) return null;
    if (session.isRecording) {
      final path = await session.stopRecording();
      _recordingLock.release(deviceId);
      _update(deviceId, (e) => e.copyWith(recordingSince: () => null));
      if (path != null) onSaved?.call(path);
      return path;
    }
    final name = stateValue.entries
        .where((e) => e.device.id == deviceId)
        .firstOrNull
        ?.device
        .name;
    _recordingLock.acquire(deviceId, label: name ?? deviceId);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    try {
      await session.startRecording('$directory/simutil-$deviceId-$stamp.mp4');
    } catch (_) {
      _recordingLock.release(deviceId);
      rethrow;
    }
    final since = DateTime.now();
    _update(deviceId, (e) => e.copyWith(recordingSince: () => since));
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
