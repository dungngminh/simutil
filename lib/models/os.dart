/// The type of simulator/emulator device.
enum Os {
  /// Android emulator managed via `emulator` CLI and `adb`.
  android,

  /// iOS simulator managed via `xcrun simctl` (macOS only).
  ios,
}
