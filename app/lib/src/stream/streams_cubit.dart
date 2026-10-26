import 'dart:async';
import 'dart:io';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/services.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_core/simutil_core.dart';

import 'package:simutil_app/src/recording/recording_lock.dart';
import 'package:simutil_app/src/settings/device_settings_cubit.dart';
import 'package:simutil_app/src/stream/ios/ios_device_session.dart';
import 'package:simutil_app/src/stream/ios/ios_sim_session.dart';
import 'package:simutil_app/src/stream/streams_state.dart';

/// Creates the platform session for a device, or throws a user-facing
/// message when it cannot.
typedef DeviceSessionFactory = Future<DeviceSession> Function(Device device);

/// Open device sessions shown in the grid.
class StreamsCubit extends CubitSignal<StreamsState> {
  /// Opens sessions with [_create]; [onSaved] gets each finished recording.
  /// [openElsewhere] returns true when the device is already streaming in
  /// its own window (and brings that window up), so it opens no tile.
  StreamsCubit(
    this._create, {
    this.onSaved,
    this.openElsewhere,
    RecordingLock? recordingLock,
  }) : _recordingLock = recordingLock ?? RecordingLock(),
       super(initialState: const StreamsState());

  /// One recording at a time, shared with the grid recorder.
  final RecordingLock _recordingLock;

  final DeviceSessionFactory _create;

  /// Called with each finished recording.
  final void Function(String path)? onSaved;

  /// See the constructor.
  final Future<bool> Function(Device device)? openElsewhere;
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
      (device.os == DeviceOs.android || Platform.isMacOS);

  /// Session starts waiting to run; they run one at a time (adb
  /// push/forward, simulator capture) in FIFO order.
  final _startQueue = <(Device, Object, Completer<void>)>[];
  bool _draining = false;

  /// The pending start per device; closing or reopening replaces it so a
  /// stale queued start is skipped.
  final _queued = <String, Object>{};

  /// Adds [device]'s tile as connecting and queues its session start;
  /// completes once that start ran (or was skipped). Opening a device that
  /// is already open does nothing. [here] skips [openElsewhere].
  Future<void> open(Device device, {bool here = false}) async {
    if (stateValue.isOpen(device.id)) return;
    // No hook: the tile is added synchronously, before the first await.
    if (openElsewhere case final elsewhere? when !here) {
      if (await elsewhere(device) || isClosed) return;
      if (stateValue.isOpen(device.id)) return;
    }
    _setEntries([
      ...stateValue.entries,
      StreamEntry(device: device, status: const SessionConnecting()),
    ]);
    final ticket = _queued[device.id] = Object();
    final done = Completer<void>();
    _startQueue.add((device, ticket, done));
    unawaited(_drain());
    await done.future;
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
    _subscriptions[device.id] = session.statusChanges.listen((status) {
      final wasLive = stateValue.entries.any(
        (e) => e.device.id == device.id && e.status is SessionLive,
      );
      _update(device.id, (e) => e.copyWith(status: status));
      // A stream that was live and dropped closes its tile; one that never
      // came up keeps showing why.
      if (wasLive && status is SessionFailed) {
        unawaited(_closeDisconnected(device.id));
      }
    });
    try {
      await session.start();
    } catch (e) {
      _update(device.id, (e0) => e0.copyWith(status: SessionFailed('$e')));
    }
  }

  /// Opens [device] once it is booted (after a headless start).
  void openWhenBooted(Device device) {
    if (_pendingByName.add(device.name)) _setEntries(stateValue.entries);
  }

  /// When an open stream's device was first seen not running.
  final _missingSince = <String, DateTime>{};

  /// How long a device may be missing from the lists before its stream is
  /// closed; longer than one refresh so a single failed load is ignored.
  static const missingGrace = Duration(seconds: 15);
  Timer? _missingCheck;

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
    // The list only changes on device events, so look again once the grace
    // ran out instead of waiting for the next one.
    _missingCheck?.cancel();
    _missingCheck = null;
    if (_missingSince.isNotEmpty && !isClosed) {
      final last = devices.toList();
      _missingCheck = Timer(
        missingGrace,
        () => onDevices(last, now: time.add(missingGrace)),
      );
    }

    if (_pendingByName.isEmpty) return;
    for (final device in devices) {
      if (_pendingByName.contains(device.name) && canStream(device)) {
        _pendingByName.remove(device.name);
        _setEntries(stateValue.entries); // drops it from `booting`
        unawaited(open(device));
      }
    }
  }

  /// Saves a running recording (it gets announced like any other), then
  /// closes the tile.
  Future<void> _closeDisconnected(String deviceId) async {
    if (_sessions[deviceId]?.isRecording ?? false) {
      try {
        await toggleRecording(deviceId, '');
      } catch (_) {
        // Closing still releases the session and the recording lock.
      }
    }
    await closeStream(deviceId);
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

  /// Moves stream [deviceId] to position [to]; the streams in between
  /// shift by one.
  void moveStream(String deviceId, int to) {
    final entries = [...stateValue.entries];
    final from = entries.indexWhere((e) => e.device.id == deviceId);
    if (from < 0 || to < 0 || to >= entries.length || from == to) return;
    entries.insert(to, entries.removeAt(from));
    _setEntries(entries);
  }

  void _update(String deviceId, StreamEntry Function(StreamEntry) change) {
    if (isClosed) return;
    _setEntries([
      for (final e in stateValue.entries)
        e.device.id == deviceId ? change(e) : e,
    ]);
  }

  void _setEntries(List<StreamEntry> entries) =>
      emit(StreamsState(entries, Set.unmodifiable(_pendingByName)));

  @override
  Future<void> close() async {
    _missingCheck?.cancel();
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

/// Default factory: the emulator's own gRPC API for Android emulators on
/// macOS (scrcpy when it has none), scrcpy for other Android devices, the
/// native capture for iOS simulators and USB devices.
DeviceSessionFactory defaultSessionFactory({
  required CommandExec exec,
  required String Function() adbPath,
  required DeviceSettings Function(Device device) settings,
}) {
  Future<ScrcpyInstall>? scrcpy;
  return (device) async {
    switch (device.os) {
      case DeviceOs.android:
        if (Platform.isMacOS && device.type.isSimulator) {
          if (await _emulatorEndpoint(device.id) case final endpoint?) {
            return EmulatorGrpcSession(
              serial: device.id,
              endpoint: endpoint,
              adbPath: adbPath(),
              exec: exec,
            );
          }
        }
        final install = await (scrcpy ??= _locateScrcpy(exec));
        final options = settings(device);
        return ScrcpySession(
          serial: device.id,
          adbPath: adbPath(),
          install: install,
          exec: exec,
          maxSize: options.maxSize,
          maxFps: options.maxFps,
          videoBitRate: options.bitRateMbps * 1000000,
          showTouches: options.showTouches,
          stayAwake: options.stayAwake,
          turnScreenOff: options.turnScreenOff,
          powerOffOnClose: options.powerOffOnClose,
        );
      case DeviceOs.ios:
        if (!Platform.isMacOS) {
          throw 'iOS devices can only be streamed on macOS';
        }
        if (device.type.isPhysical) {
          return IosDeviceSession(device.id, name: device.name, exec: exec);
        }
        return IosSimSession(device.id, exec: exec);
    }
  };
}

/// The emulator writes its discovery file a moment after adb lists it.
/// ponytail: macOS only until Linux / Windows get a shared-frame texture.
Future<EmulatorEndpoint?> _emulatorEndpoint(String serial) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    if (await EmulatorEndpoint.find(serial) case final endpoint?) {
      return endpoint;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return null;
}

/// Version of `assets/scrcpy-server` (Genymobile/scrcpy release, Apache-2.0).
const _bundledScrcpyVersion = '4.0';

/// An installed scrcpy (or `SCRCPY_SERVER_PATH`) wins; otherwise the server
/// shipped in the app, so streaming works without installing scrcpy.
Future<ScrcpyInstall> _locateScrcpy(CommandExec exec) async {
  final installed = await ScrcpyInstall.locate(exec);
  if (installed != null) return installed;

  // adb pushes from a file path. Each process copies the asset into its own
  // fresh temp dir (owner-only on macOS / Linux), so it never trusts or
  // races a file left by another process or user.
  final dir = await Directory.systemTemp.createTemp('simutil-scrcpy-');
  final file = File('${dir.path}/scrcpy-server');
  final data = await rootBundle.load('assets/scrcpy-server');
  await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
  return ScrcpyInstall(serverPath: file.path, version: _bundledScrcpyVersion);
}
