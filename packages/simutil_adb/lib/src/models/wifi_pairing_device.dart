/// An ADB wireless pairing endpoint discovered via mDNS.
class WifiPairingDevice {
  /// Creates a device advertising [host]:[port].
  const WifiPairingDevice({
    required this.name,
    required this.host,
    required this.port,
  });

  /// Friendly name parsed from the mDNS domain.
  final String name;

  /// IPv4 host.
  final String host;

  /// Pairing port.
  final int port;

  /// `host:port` suitable for `adb pair`.
  String get hostPort => '$host:$port';
}
