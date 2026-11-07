import 'package:simutil_core/simutil_core.dart';

/// Thrown by `IOSDeviceService.launchDevice` when `simctl boot` fails (for
/// example an unknown UDID or a missing runtime) or the Simulator app cannot
/// be opened. [deviceId] is the simulator's UDID.
class SimulatorLaunchException extends DeviceLaunchException {
  /// Creates an exception for the simulator with UDID [deviceId], with what
  /// `simctl` or `open` reported as [message].
  const SimulatorLaunchException(super.deviceId, super.message);
}
