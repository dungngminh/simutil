import 'package:simutil_core/simutil_core.dart';

/// Thrown by `AndroidDeviceService.launchDevice` when the emulator exits
/// right after it was started (e.g. the AVD is already running or locked)
/// or cannot be started at all. [deviceId] is the AVD name; [message] is
/// the emulator's error output (its `FATAL` / `ERROR` lines when present).
class EmulatorLaunchException extends DeviceLaunchException {
  /// Creates an exception for the AVD [deviceId] with the emulator's own
  /// [message].
  const EmulatorLaunchException(super.deviceId, super.message);
}
