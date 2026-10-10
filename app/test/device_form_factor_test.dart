import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/devices/device_form_factor.dart';
import 'package:simutil_core/simutil_core.dart';

void main() {
  DeviceFormFactor of(String name, [String platform = 'Android']) =>
      DeviceFormFactor.of(
        Device(
          id: name,
          name: name,
          os: DeviceOs.android,
          platform: platform,
          state: DeviceState.shutdown,
          type: DeviceType.simulator,
        ),
      );

  test('guesses form factor from name and platform', () {
    expect(of('Pixel_7_Pro_big_Android_15'), DeviceFormFactor.phone);
    expect(of('Television_1080p_Android_TV_14'), DeviceFormFactor.tv);
    expect(of('Pixel_Tablet_API_35'), DeviceFormFactor.tablet);
    expect(of('iPad Pro 13-inch (M5)', 'iOS 26.5'), DeviceFormFactor.tablet);
    expect(of('Apple TV 4K', 'tvOS 26.0'), DeviceFormFactor.tv);
    expect(of('Apple Watch Ultra 3', 'watchOS 26.0'), DeviceFormFactor.watch);
    expect(of('iPhone 18 Pro', 'iOS 27.0'), DeviceFormFactor.phone);
    expect(of('Wear_OS_Large_Round'), DeviceFormFactor.watch);
  });
}
