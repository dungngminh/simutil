import '../models/device.dart';
import '../models/launch_options.dart';

/// Common interface for device management services (adb, simctl).
abstract class DeviceService {
  /// Whether this service's tooling is installed and available.
  Future<bool> isAvailable();

  /// List all devices managed by this service.
  Future<List<Device>> listDevices();

  /// Launch/boot a device by its ID with the given options.
  Future<void> launchDevice(String deviceId, LaunchOptions options);
}
