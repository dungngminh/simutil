enum DeviceState {
  shutdown('Shutdown'),

  booted('Booted'),

  booting('Booting');

  const DeviceState(this.label);

  final String label;

  bool get isRunning => this == booted || this == booting;

  static DeviceState fromString(String raw) {
    return switch (raw.toLowerCase()) {
      'booted' || 'running' => booted,
      'booting' => booting,
      _ => shutdown,
    };
  }
}
