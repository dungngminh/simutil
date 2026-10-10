import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';
import 'package:simutil_adb/src/models/wifi_pairing_device.dart';
import 'package:simutil_adb/src/wifi_discovery_service.dart';
import 'package:test/test.dart';

void main() {
  final validUntil = DateTime.now()
      .add(const Duration(minutes: 5))
      .millisecondsSinceEpoch;

  FakeMDnsClient client({required List<PtrResourceRecord> ptr}) {
    return FakeMDnsClient(
      ptr: ptr,
      srv: SrvResourceRecord(
        'Pixel_8_Pro._adb-tls-pairing._tcp.local',
        validUntil,
        target: 'Pixel-8-Pro.local',
        port: 37123,
        priority: 0,
        weight: 0,
      ),
      ip: IPAddressResourceRecord(
        'Pixel-8-Pro.local',
        validUntil,
        address: InternetAddress('192.168.1.50'),
      ),
    );
  }

  Future<List<WifiPairingDevice>> collect(WifiDiscoveryService service) async {
    final events = <WifiPairingDevice>[];
    final sub = service.watchPairingDevices().listen(events.add);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();
    return events;
  }

  test('emits a device with friendly name and host:port', () async {
    final fake = client(
      ptr: [
        PtrResourceRecord(
          '_adb-tls-pairing._tcp.local',
          validUntil,
          domainName: 'Pixel_8_Pro._adb-tls-pairing._tcp.local',
        ),
      ],
    );
    final service = MdnsWifiDiscoveryService(clientFactory: () => fake);

    final events = await collect(service);

    expect(events, hasLength(1));
    expect(events.single.name, 'Pixel_8_Pro');
    expect(events.single.host, '192.168.1.50');
    expect(events.single.port, 37123);
    expect(events.single.hostPort, '192.168.1.50:37123');
  });

  test('deduplicates devices sharing the same host:port', () async {
    final fake = client(
      ptr: [
        PtrResourceRecord(
          '_adb-tls-pairing._tcp.local',
          validUntil,
          domainName: 'Pixel_8_Pro._adb-tls-pairing._tcp.local',
        ),
        PtrResourceRecord(
          '_adb-tls-pairing._tcp.local',
          validUntil,
          domainName: 'Pixel_8_Pro._adb-tls-pairing._tcp.local',
        ),
      ],
    );
    final service = MdnsWifiDiscoveryService(clientFactory: () => fake);

    final events = await collect(service);

    expect(events, hasLength(1));
  });

  test('watchConnectDevices looks up the connect service', () async {
    final fake = client(
      ptr: [
        PtrResourceRecord(
          '_adb-tls-connect._tcp.local',
          validUntil,
          domainName: 'adb-1A2B3C-xyz._adb-tls-connect._tcp.local',
        ),
      ],
    );
    final service = MdnsWifiDiscoveryService(clientFactory: () => fake);
    final events = <WifiPairingDevice>[];
    final sub = service.watchConnectDevices().listen(events.add);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await sub.cancel();

    expect(fake.queries.first, '_adb-tls-connect._tcp');
    expect(events.single.hostPort, '192.168.1.50:37123');
  });
}

/// Minimal [MDnsClient] stand-in that replays canned resource records.
class FakeMDnsClient implements MDnsClient {
  FakeMDnsClient({required this.ptr, required this.srv, required this.ip});

  final List<PtrResourceRecord> ptr;
  final SrvResourceRecord srv;
  final IPAddressResourceRecord ip;

  /// Names looked up, in order.
  final queries = <String>[];

  @override
  Future<Iterable<NetworkInterface>> allInterfacesFactory(
    InternetAddressType type,
  ) async => const [];

  @override
  Future<void> start({
    InternetAddress? listenAddress,
    NetworkInterfacesFactory? interfacesFactory,
    int mDnsPort = 5353,
    InternetAddress? mDnsAddress,
    Function? onError,
  }) async {}

  @override
  void stop() {}

  @override
  Stream<T> lookup<T extends ResourceRecord>(
    ResourceRecordQuery query, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    queries.add(query.fullyQualifiedName);
    switch (query.resourceRecordType) {
      case ResourceRecordType.serverPointer:
        return Stream<ResourceRecord>.fromIterable(ptr).cast<T>();
      case ResourceRecordType.service:
        return Stream<ResourceRecord>.fromIterable([srv]).cast<T>();
      case ResourceRecordType.addressIPv4:
        return Stream<ResourceRecord>.fromIterable([ip]).cast<T>();
      default:
        return const Stream.empty();
    }
  }
}
