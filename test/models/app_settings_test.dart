import 'package:simutil/models/app_settings.dart';
import 'package:test/test.dart';

void main() {
  group('AppSettings defaults', () {
    test('defaults theme to dark with no selected device', () {
      const settings = AppSettings();

      expect(settings.themeName, 'dark');
      expect(settings.lastSelectedDeviceId, isNull);
    });
  });

  group('fromJson', () {
    test('parses provided values', () {
      final settings = AppSettings.fromJson({
        'themeName': 'light',
        'lastSelectedDeviceId': 'emulator-5554',
      });

      expect(settings.themeName, 'light');
      expect(settings.lastSelectedDeviceId, 'emulator-5554');
    });

    test('falls back to defaults for missing keys', () {
      final settings = AppSettings.fromJson({});

      expect(settings.themeName, 'dark');
      expect(settings.lastSelectedDeviceId, isNull);
    });
  });

  group('copyWith', () {
    test('overrides only the given fields', () {
      const settings = AppSettings(
        themeName: 'dark',
        lastSelectedDeviceId: 'a',
      );

      final updated = settings.copyWith(themeName: 'light');

      expect(updated.themeName, 'light');
      expect(updated.lastSelectedDeviceId, 'a');
    });

    test('keeps existing values when nothing is passed', () {
      const settings = AppSettings(
        themeName: 'light',
        lastSelectedDeviceId: 'b',
      );

      final copy = settings.copyWith();

      expect(copy.themeName, 'light');
      expect(copy.lastSelectedDeviceId, 'b');
    });
  });

  group('toJson', () {
    test('round-trips through fromJson', () {
      const settings = AppSettings(
        themeName: 'light',
        lastSelectedDeviceId: 'c',
      );

      final restored = AppSettings.fromJson(settings.toJson());

      expect(restored.themeName, settings.themeName);
      expect(restored.lastSelectedDeviceId, settings.lastSelectedDeviceId);
    });
  });
}
