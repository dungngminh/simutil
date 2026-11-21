import 'package:simutil_apple/src/apple_device_watch.dart';
import 'package:test/test.dart';

void main() {
  const udid = '030D9BD6-3A81-49E1-97E5-9B2A8C069EDE';

  test('only device state / set changes count', () {
    expect(isSimulatorSetChange('/$udid/device.plist'), isTrue);
    expect(isSimulatorSetChange('/device_set.plist'), isTrue);
    expect(isSimulatorSetChange('/$udid'), isTrue);
    expect(isSimulatorSetChange('/$udid/device.plist.sb-0248-Ti7oRY'), isFalse);
    expect(isSimulatorSetChange('/$udid/data/Library/x.db'), isFalse);
    expect(isSimulatorSetChange('/.DS_Store'), isFalse);
  });
}
