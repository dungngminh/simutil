import 'package:simutil/models/device_type.dart';
import 'package:test/test.dart';

void main() {
  test('isPhysical is true only for physical', () {
    expect(DeviceType.physical.isPhysical, isTrue);
    expect(DeviceType.simulator.isPhysical, isFalse);
  });

  test('isSimulator is true only for simulator', () {
    expect(DeviceType.simulator.isSimulator, isTrue);
    expect(DeviceType.physical.isSimulator, isFalse);
  });
}
