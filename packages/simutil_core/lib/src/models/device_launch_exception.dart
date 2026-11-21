/// Thrown by `DeviceService.launchDevice` when a simulator or emulator does
/// not start. Platform packages extend it with their own exception, so
/// callers can catch launch failures of any device with this one type.
class DeviceLaunchException implements Exception {
  /// Creates an exception for [deviceId] with the tool's own [message].
  const DeviceLaunchException(this.deviceId, this.message);

  /// The device that failed to start (an AVD name, a simulator UDID, …).
  final String deviceId;

  /// Why it did not start, as the platform tool reported it.
  final String message;

  @override
  String toString() => message;
}
