import 'package:simutil/models/app_settings.dart';
import 'package:test/test.dart';

void main() {
  group('AppSettings', () {
    test('constructor returns correct instance with default params', () {
      final settings = AppSettings();
      expect(settings, isA<AppSettings>());
      expect(settings.themeName, 'dark');
      expect(settings.lastSelectedDeviceId, null);
    });
    test('fromJson', () {
      final json = {
        'themeName': 'dark',
        'defaultLaunchOptions': {'args': [], 'env': {}},
        'lastSelectedDeviceId': 'device_id',
      };

      final settings = AppSettings.fromJson(json);

      expect(settings.themeName, 'dark');
      expect(settings.lastSelectedDeviceId, 'device_id');
    });
    test('toJson', () {
      final settings = AppSettings(
        themeName: 'dark',
        lastSelectedDeviceId: 'device_id',
      );

      final json = settings.toJson();

      expect(json['themeName'], 'dark');
      expect(json['lastSelectedDeviceId'], 'device_id');
    });
  });
}
