import 'package:simutil_adb/src/adb_device_watch.dart';
import 'package:test/test.dart';

void main() {
  test('splits track-devices frames across chunks', () {
    final decoder = AdbTrackDevicesDecoder();
    expect(decoder.add('0000'), ['']);
    expect(decoder.add('0015emulator-5554\tdev'), isEmpty);
    expect(decoder.add('ice\n0000'), ['emulator-5554\tdevice\n', '']);
  });

  test('drops unknown framing instead of stalling', () {
    final decoder = AdbTrackDevicesDecoder();
    expect(decoder.add('error: no adb'), isEmpty);
    expect(decoder.add('0000'), ['']);
  });
}
