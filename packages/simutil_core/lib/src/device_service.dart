import 'package:simutil_core/src/models/device.dart';

/// Discovers, launches, and shuts down devices for one platform.
abstract class DeviceService {
  /// Whether the platform tooling is installed and responding.
  Future<bool> isAvailable();

  /// Connected physical devices (phones, tablets, watches, …).
  Future<List<Device>> getPhysicalDevices();

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
}
