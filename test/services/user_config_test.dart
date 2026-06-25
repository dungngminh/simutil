import 'dart:io';

import 'package:simutil/services/user_config.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late String configPath;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('simutil_user_config_');
    configPath = '${dir.path}/settings.yaml';
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  test('creates combined default when no files exist', () async {
    await ensureConfigFile(configPath);

    final content = File(configPath).readAsStringSync();
    expect(content, contains('theme: dark'));
    expect(content, contains('last_selected_device_id:'));
    expect(content, contains('plugins:'));
    expect(content, contains('id: scrcpy'));
  });

  test('does not overwrite an existing config file', () async {
    File(configPath).writeAsStringSync('theme: light\nlast_selected_device_id: dev-1\n');
    await ensureConfigFile(configPath);

    final content = File(configPath).readAsStringSync();
    expect(content, contains('theme: light'));
    expect(content, isNot(contains('id: scrcpy')));
  });

  group('mergeSettingsScalars', () {
    test('replaces theme and device id in place', () {
      const content = '''
# header
theme: dark
last_selected_device_id: ~

plugins:
  - id: scrcpy
''';

      final merged = mergeSettingsScalars(
        content,
        themeName: 'light',
        lastSelectedDeviceId: 'dev-1',
      );

      expect(merged, contains('theme: light'));
      expect(merged, contains('last_selected_device_id: dev-1'));
      expect(merged, contains('id: scrcpy'));
      expect(merged, isNot(contains('theme: dark')));
    });

    test('preserves plugins block and comments on save', () {
      const content = '''
# Simutil configuration
theme: dark
last_selected_device_id: ~

# Plugins section
plugins:
  - id: custom
    label: Custom
    commands:
      - id: run
        label: Run
        command: echo
''';

      final merged = mergeSettingsScalars(
        content,
        themeName: 'light',
        lastSelectedDeviceId: null,
      );

      expect(merged, contains('# Plugins section'));
      expect(merged, contains('id: custom'));
      expect(merged, contains('theme: light'));
      expect(merged, contains('last_selected_device_id: ~'));
    });
  });
}
