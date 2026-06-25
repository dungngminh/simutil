import 'package:simutil/models/wifi_pairing_device.dart';
import 'package:test/test.dart';

void main() {
  test('hostPort joins host and port', () {
    const device = WifiPairingDevice(
      name: 'Pixel 7',
      host: '192.168.1.10',
      port: 37123,
    );

    expect(device.hostPort, '192.168.1.10:37123');
    expect(device.name, 'Pixel 7');
  });
}
