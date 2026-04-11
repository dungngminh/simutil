import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

// ---------- Model -------------------------------------------------------

class WifiPairingDevice {
  const WifiPairingDevice({
    required this.name,
    required this.host,
    required this.port,
  });

  final String name;
  final String host;
  final int port;

  String get hostPort => '$host:$port';
}

// ---------- Abstraction (DIP) -------------------------------------------

abstract class WifiDiscoveryService {
  /// Continuously watches for ADB-connectable devices via mDNS (`_adb-tls-connect._tcp`).
  /// Emits each newly discovered device as it is found.
  /// Cancel the subscription to stop scanning.
  Stream<WifiPairingDevice> watchConnectableDevices();
}

// ---------- Injectable factory typedef (for testability) ----------------

typedef MdnsClientFactory = MDnsClient Function();

// ---------- Concrete mDNS implementation --------------------------------

class MdnsWifiDiscoveryService implements WifiDiscoveryService {
  MdnsWifiDiscoveryService({MdnsClientFactory? clientFactory})
    : _clientFactory = clientFactory ?? _defaultClientFactory;

  final MdnsClientFactory _clientFactory;

  // Devices in wireless-debugging mode advertise this service.
  static const _connectService = '_adb-tls-connect._tcp';

  // Pause between successive mDNS scan cycles.
  static const _scanInterval = Duration(seconds: 2);

  static MDnsClient _defaultClientFactory() =>
      MDnsClient(rawDatagramSocketFactory: _socketFactory);

  @override
  Stream<WifiPairingDevice> watchConnectableDevices() {
    late StreamController<WifiPairingDevice> controller;
    var cancelled = false;
    final seen = <String>{};

    Future<void> scan() async {
      while (!cancelled) {
        MDnsClient? client;
        try {
          client = _clientFactory();
          await client.start();

          await for (final ptr in client.lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_connectService),
          )) {
            if (cancelled) break;
            try {
              final device = await _resolveDevice(client, ptr.domainName);
              if (device != null && seen.add(device.hostPort)) {
                controller.add(device);
              }
            } catch (e) {
              log(
                'MdnsWifiDiscoveryService: error resolving '
                '${ptr.domainName}: $e',
              );
            }
          }
        } catch (e) {
          log('MdnsWifiDiscoveryService.watchConnectableDevices error: $e');
        } finally {
          client?.stop();
        }

        if (!cancelled) {
          await Future<void>.delayed(_scanInterval);
        }
      }

      if (!controller.isClosed) controller.close();
    }

    controller = StreamController<WifiPairingDevice>(
      onListen: () => scan().ignore(),
      onCancel: () => cancelled = true,
    );
    return controller.stream;
  }

  /// Resolves PTR domain → SRV (port) → A (IPv4) and returns a [WifiPairingDevice],
  /// or `null` if any record is missing.
  Future<WifiPairingDevice?> _resolveDevice(
    MDnsClient client,
    String domainName,
  ) async {
    // Resolve SRV record to get host + port.
    final srvStream = client.lookup<SrvResourceRecord>(
      ResourceRecordQuery.service(domainName),
    );

    await for (final srv in srvStream) {
      final port = srv.port;
      final target = srv.target;

      // Only IPv4 addresses are queried by this implementation.
      final ipStream = client.lookup<IPAddressResourceRecord>(
        ResourceRecordQuery.addressIPv4(target),
      );

      await for (final ip in ipStream) {
        return WifiPairingDevice(
          name: _extractFriendlyName(domainName),
          host: ip.address.address,
          port: port,
        );
      }
    }
    return null;
  }

  /// Extracts a human-readable name from the mDNS service domain name.
  /// e.g. "Pixel_8_Pro._adb-tls-connect._tcp.local" → "Pixel_8_Pro"
  String _extractFriendlyName(String domainName) {
    final parts = domainName.split('.');
    return parts.isNotEmpty ? parts.first : domainName;
  }

  static Future<RawDatagramSocket> _socketFactory(
    dynamic host,
    int port, {
    bool reuseAddress = true,
    bool reusePort = true,
    int ttl = 1,
  }) =>
      RawDatagramSocket.bind(
        host,
        port,
        reuseAddress: reuseAddress,
        reusePort: reusePort,
        ttl: ttl,
      );
}
