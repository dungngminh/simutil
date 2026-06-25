import 'package:simutil/models/wireless_pairing_info.dart';
import 'package:test/test.dart';

void main() {
  test('holds device ip, default port and capability flag', () {
    const info = WirelessPairingInfo(
      deviceIp: '192.168.1.10',
      defaultPort: 5555,
      supportsWirelessDebugging: true,
    );

    expect(info.deviceIp, '192.168.1.10');
    expect(info.defaultPort, 5555);
    expect(info.supportsWirelessDebugging, isTrue);
  });
}
