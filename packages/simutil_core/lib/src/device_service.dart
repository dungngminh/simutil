import 'package:simutil_core/src/models/device.dart';

/// Discovers, launches, and shuts down devices for one platform.
abstract class DeviceService {
  /// Whether the platform tooling is installed and responding.
  Future<bool> isAvailable();

  /// Connected physical devices (phones, tablets, watches, …).
  Future<List<Device>> getPhysicalDevices();

  /// Fires whenever devices may have appeared, disappeared or changed state,
  /// so callers re-read [getSimulators] / [getPhysicalDevices] instead of
  /// polling. Each listen starts the platform watchers and cancelling stops
  /// them. Events come in bursts: debounce before reloading. Empty when the
  /// platform cannot be watched.
  Stream<void> watchDevices();

  /// Emulators / simulators known to the platform SDK.
  Future<List<Device>> getSimulators();

  /// Boots or starts [deviceId], passing [additionalArgs] to the launcher.
  ///
  /// [headless] starts it without its own window (no Android emulator
  /// window, no Simulator app), for UIs that stream the screen themselves.
  Future<void> launchDevice({
    required String deviceId,
    List<String> additionalArgs = const [],
    bool headless = false,
  });

  /// Shuts down a simulator/emulator. Returns whether the command succeeded.
  Future<bool> shutdownSimulator({required String deviceId});

  /// Permanently deletes a shut-down simulator/emulator. Returns whether it
  /// was deleted.
  Future<bool> deleteSimulator({required String deviceId});
}
