import 'package:simutil/models/device_os.dart';
import 'package:test/test.dart';

void main() {
  test('label maps each value to a display string', () {
    expect(DeviceOs.android.label, 'Android');
    expect(DeviceOs.ios.label, 'iOS');
  });
}
