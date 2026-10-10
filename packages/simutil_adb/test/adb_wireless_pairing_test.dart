import 'dart:async';

import 'package:simutil_adb/simutil_adb.dart';
import 'package:test/test.dart';

class _FakeDiscovery implements WifiDiscoveryService {
  final pairing = StreamController<WifiPairingDevice>.broadcast();
  final connect = StreamController<WifiPairingDevice>.broadcast();

  @override
  Stream<WifiPairingDevice> watchPairingDevices() => pairing.stream;

  @override
  Stream<WifiPairingDevice> watchConnectDevices() => connect.stream;
}

class _FakeAdb implements AndroidDeviceService {
  final calls = <String>[];
  var pairOk = true;

  @override
  Future<AdbConnectResult> pairDevice(String host, String code) async {
    calls.add('pair $host $code');
    return AdbConnectResult(success: pairOk, message: pairOk ? 'ok' : 'bad');
  }

  @override
  Future<AdbConnectResult> connectDevice(String host) async {
    calls.add('connect $host');
    return AdbConnectResult(success: true, message: 'connected to $host');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WifiPairingDevice _endpoint(String name, String host, int port) =>
    WifiPairingDevice(name: name, host: host, port: port);

void main() {
  late _FakeDiscovery discovery;
  late _FakeAdb adb;
  late AdbWirelessPairing pairing;

  setUp(() {
    discovery = _FakeDiscovery();
    adb = _FakeAdb();
    pairing = AdbWirelessPairing(adb, discovery);
  });

  test('pairs, then connects to the connect endpoint on that host', () async {
    final result = pairing.pairAndConnect('192.168.1.5:37000', '123456');
    await pumpEventQueue();
    discovery.connect
      ..add(_endpoint('other', '192.168.1.9', 40001))
      ..add(_endpoint('adb-xyz', '192.168.1.5', 41234));
    final r = await result;
    expect(r.success, isTrue);
    expect(adb.calls, [
      'pair 192.168.1.5:37000 123456',
      'connect 192.168.1.5:41234',
    ]);
    expect(discovery.connect.hasListener, isFalse); // scanning stopped
  });

  test('a failed pair never connects', () async {
    adb.pairOk = false;
    final r = await pairing.pairAndConnect('192.168.1.5:37000', '000000');
    expect(r.success, isFalse);
    expect(adb.calls, ['pair 192.168.1.5:37000 000000']);
  });

  test('reports when no connect endpoint shows up', () async {
    final r = await pairing.pairAndConnect(
      '192.168.1.5:37000',
      '123456',
      connectWait: const Duration(milliseconds: 20),
    );
    expect(r.success, isFalse);
    expect(r.message, contains('connect by IP'));
    expect(discovery.connect.hasListener, isFalse);
  });

  test('QR session pairs with the phone that scanned it', () async {
    final session = pairing.startQr();
    expect(
      session.payload,
      'WIFI:T:ADB;S:${session.serviceName};P:${session.password};;',
    );
    expect(session.serviceName, matches(RegExp(r'^simutil-[a-z0-9]{6}$')));
    expect(session.password, hasLength(10));

    var found = false;
    final result = session.result(onFound: () => found = true);
    await pumpEventQueue();
    discovery.pairing
      ..add(_endpoint('someone-else', '192.168.1.7', 30000))
      ..add(_endpoint(session.serviceName, '192.168.1.5', 37000));
    await pumpEventQueue();
    discovery.connect.add(_endpoint('adb-xyz', '192.168.1.5', 41234));

    final r = await result;
    expect(found, isTrue);
    expect(r.success, isTrue);
    expect(adb.calls, [
      'pair 192.168.1.5:37000 ${session.password}',
      'connect 192.168.1.5:41234',
    ]);
  });

  test('QR session times out or cancels without pairing', () async {
    final timedOut = await pairing.startQr().result(
      timeout: const Duration(milliseconds: 20),
    );
    expect(timedOut.success, isFalse);

    final session = pairing.startQr();
    final result = session.result();
    session.cancel();
    expect((await result).message, 'Cancelled');
    expect(adb.calls, isEmpty);
    expect(discovery.pairing.hasListener, isFalse);
  });
}
