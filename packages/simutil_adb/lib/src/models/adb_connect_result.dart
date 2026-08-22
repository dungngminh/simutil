/// Result of `adb connect` or `adb pair`.
class AdbConnectResult {
  /// Creates a result with [success] and a tool [message].
  const AdbConnectResult({required this.success, required this.message});

  /// Whether adb reported success.
  final bool success;

  /// stdout/stderr (or exception text) from adb.
  final String message;
}
