/// Runtime state of a simulator or emulator device.
enum DeviceState {
  /// The device is powered off.
  shutdown('Shutdown'),

  /// The device is fully booted and running.
  booted('Booted'),

  /// The device is currently booting up.
  booting('Booting');

  const DeviceState(this.label);

  /// Human-readable label shown in the UI.
  final String label;

  /// Whether the device is currently active (booted or booting).
  bool get isRunning => this == booted || this == booting;

  /// Parse a raw state string from `simctl` / `adb` output.
  ///
  /// Defaults to [shutdown] for unrecognised values.
  static DeviceState fromString(String raw) {
    return switch (raw.toLowerCase()) {
      'booted' || 'running' => booted,
      'booting' => booting,
      _ => shutdown,
    };
  }
}
