/// Wireless debugging details for an Android 11+ device.
class WirelessPairingInfo {
  /// Creates pairing info for [deviceIp].
  const WirelessPairingInfo({
    required this.deviceIp,
    required this.defaultPort,
    required this.supportsWirelessDebugging,
  });

  /// Device IPv4 address on the LAN.
  final String deviceIp;

  /// Default `adb tcpip` port (usually 5555).
  final int defaultPort;

  /// Whether the device SDK supports wireless debugging.
  final bool supportsWirelessDebugging;
}
