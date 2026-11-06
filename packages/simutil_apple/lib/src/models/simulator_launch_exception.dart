/// Thrown by `IOSDeviceService.launchDevice` when `simctl boot` fails (for
/// example an unknown UDID or a missing runtime) or the Simulator app cannot
/// be opened.
class SimulatorLaunchException implements Exception {
  /// Creates an exception for [udid] with the tool's own [message].
  const SimulatorLaunchException(this.udid, this.message);

  /// The simulator that failed to start.
  final String udid;

  /// What `simctl` or `open` reported.
  final String message;

  @override
  String toString() => message;
}
