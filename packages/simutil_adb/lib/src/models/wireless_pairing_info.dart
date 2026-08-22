class WirelessPairingInfo {
  const WirelessPairingInfo({
    required this.deviceIp,
    required this.defaultPort,
    required this.supportsWirelessDebugging,
  });

  final String deviceIp;
  final int defaultPort;
  final bool supportsWirelessDebugging;
}
