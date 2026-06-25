import 'package:simutil/models/wireless_connect_request.dart';
import 'package:test/test.dart';

void main() {
  test('pairingCode is optional', () {
    const request = WirelessConnectRequest(host: '192.168.1.10:5555');

    expect(request.host, '192.168.1.10:5555');
    expect(request.pairingCode, isNull);
  });

  test('keeps provided pairingCode', () {
    const request = WirelessConnectRequest(
      host: '192.168.1.10:5555',
      pairingCode: '123456',
    );

    expect(request.pairingCode, '123456');
  });
}
