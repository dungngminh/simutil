class WirelessConnectRequest {
  const WirelessConnectRequest({required this.host, this.pairingCode});

  final String host;
  final String? pairingCode;
}
