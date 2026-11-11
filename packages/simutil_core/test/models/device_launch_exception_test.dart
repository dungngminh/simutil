import 'package:simutil_core/simutil_core.dart';
import 'package:test/test.dart';

class _PlatformLaunchException extends DeviceLaunchException {
  const _PlatformLaunchException(super.deviceId, super.message);
}

void main() {
  test('shows the tool message and keeps the device id', () {
    const e = DeviceLaunchException('Pixel_7', 'AVD is already running');

    expect(e.deviceId, 'Pixel_7');
    expect('$e', 'AVD is already running');
  });

  test('platform exceptions are caught as DeviceLaunchException', () {
    Object? caught;
    try {
      throw const _PlatformLaunchException('udid', 'boot failed');
    } on DeviceLaunchException catch (e) {
      caught = e;
    }

    expect(caught, isA<_PlatformLaunchException>());
  });
}
