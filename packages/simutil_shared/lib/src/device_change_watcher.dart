import 'dart:async';

import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_shared/src/constants.dart';

/// Calls [onChange] when any of [services] reports a device change
/// ([DeviceService.watchDevices], debounced so one boot's burst of events
/// reloads once), plus every [safetyInterval] in case a watcher missed one.
class DeviceChangeWatcher {
  /// Creates a stopped watcher; call [start].
  DeviceChangeWatcher(
    this.services,
    this.onChange, {
    this.debounce = const Duration(milliseconds: 300),
    this.safetyInterval = kReloadInterval,
  });

  /// Platforms to watch.
  final List<DeviceService> services;

  /// Reloads the device lists.
  final void Function() onChange;

  /// Quiet period after the last event before [onChange] runs.
  final Duration debounce;

  /// Fallback reload period.
  final Duration safetyInterval;

  StreamSubscription<void>? _subscription;
  Timer? _debounceTimer;
  Timer? _safetyTimer;

  /// Starts the platform watchers. Safe to call more than once.
  void start() {
    _subscription ??=
        mergeStreams([
          for (final service in services) service.watchDevices(),
        ]).listen((_) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(debounce, onChange);
        });
    _safetyTimer ??= Timer.periodic(safetyInterval, (_) => onChange());
  }

  /// Stops the watchers and timers.
  Future<void> stop() async {
    _debounceTimer?.cancel();
    _safetyTimer?.cancel();
    _safetyTimer = null;
    await _subscription?.cancel();
    _subscription = null;
  }
}
