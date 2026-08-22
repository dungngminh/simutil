/// Whether a [Device] is hardware or a virtual image.
enum DeviceType {
  /// USB / Wi-Fi attached hardware.
  physical,

  /// Emulator (Android) or Simulator (Apple).
  simulator;

  /// Whether this is [physical].
  bool get isPhysical => this == DeviceType.physical;

  /// Whether this is [simulator].
  bool get isSimulator => this == DeviceType.simulator;
}
