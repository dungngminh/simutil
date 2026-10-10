import 'package:simutil_core/simutil_core.dart';

/// Rough device shape for icons, guessed from names like `iPad Pro`,
/// `Television_1080p_Android_TV_14`, `Pixel_Tablet` or a `tvOS` runtime.
enum DeviceFormFactor {
  phone,
  tablet,
  tv,
  watch;

  static final _tv = RegExp(
    r'(^|[^a-z])(tv|television)([^a-z]|$)|tvos|apple tv',
  );
  static final _watch = RegExp(r'watch|wear');
  static final _tablet = RegExp(r'ipad|tablet|(^|[^a-z])tab([^a-z]|$)');

  static DeviceFormFactor of(Device device) {
    final text = '${device.name} ${device.platform}'.toLowerCase();
    if (_tv.hasMatch(text)) return tv;
    if (_watch.hasMatch(text)) return watch;
    if (_tablet.hasMatch(text)) return tablet;
    return phone;
  }
}
