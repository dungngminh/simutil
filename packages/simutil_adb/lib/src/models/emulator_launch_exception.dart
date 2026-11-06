/// Thrown by `AndroidDeviceService.launchDevice` when the emulator exits
/// right after it was started (e.g. the AVD is already running or locked).
class EmulatorLaunchException implements Exception {
  /// Creates an exception for [avd] with the emulator's own [message].
  const EmulatorLaunchException(this.avd, this.message);

  /// The AVD that failed to start.
  final String avd;

  /// The emulator's error output (its `FATAL` / `ERROR` lines when present).
  final String message;

  @override
  String toString() => message;
}
