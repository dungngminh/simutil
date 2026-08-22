/// Power / boot state of a device.
enum DeviceState {
  /// Not running.
  shutdown('Shutdown'),

  /// Fully booted.
  booted('Booted'),

  /// In the process of starting.
  booting('Booting');

  /// Creates a state with a display [label].
  const DeviceState(this.label);

  /// Human-readable label matching common `adb` / `simctl` strings.
  final String label;

  /// Whether the device is [booted] or [booting].
  bool get isRunning => this == booted || this == booting;

  /// Parses a tool-reported state string. Unknown values become [shutdown].
  static DeviceState fromString(String raw) {
    return switch (raw.toLowerCase()) {
      'booted' || 'running' => booted,
      'booting' => booting,
      _ => shutdown,
    };
  }
}
