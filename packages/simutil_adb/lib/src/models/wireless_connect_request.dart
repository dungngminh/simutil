/// User-supplied host (and optional pairing code) for wireless ADB.
class WirelessConnectRequest {
  /// Creates a connect/pair request for [host].
  const WirelessConnectRequest({required this.host, this.pairingCode});

  /// `host:port` or hostname.
  final String host;

  /// Six-digit pairing code when pairing, otherwise `null`.
  final String? pairingCode;
}
