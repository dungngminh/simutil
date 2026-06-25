import 'dart:io';

import 'package:simutil/models/app_settings.dart';
import 'package:simutil/services/settings_service.dart';
import 'package:test/test.dart';

import 'fake_command_exec.dart';

void main() {
  late Directory dir;
  late String settingsPath;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('simutil_settings_');
    settingsPath = '${dir.path}/nested/settings.yaml';
  });

  tearDown(() {
    dir.deleteSync(recursive: true);
  });

  SettingsServiceImpl service() => SettingsServiceImpl(
    FakeCommandExec((_, _) => FakeCommandExec.ok()),
    settingsFilePath: settingsPath,
  );

  test('load creates a default settings file when missing', () async {
    final settings = await service().load();

    expect(settings.themeName, 'dark');
    expect(settings.lastSelectedDeviceId, isNull);
    expect(File(settingsPath).existsSync(), isTrue);
  });

  test('load parses theme and last_selected_device_id', () async {
    File(settingsPath)
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'theme: light\nlast_selected_device_id: emulator-5554\n',
      );

    final settings = await service().load();

    expect(settings.themeName, 'light');
    expect(settings.lastSelectedDeviceId, 'emulator-5554');
  });

  test('save then load round-trips values', () async {
    await service().save(
      const AppSettings(themeName: 'light', lastSelectedDeviceId: 'dev-1'),
    );

    final settings = await service().load();

    expect(settings.themeName, 'light');
    expect(settings.lastSelectedDeviceId, 'dev-1');
  });

  test('save writes null device id as YAML null', () async {
    await service().save(const AppSettings());

    final settings = await service().load();

    expect(settings.lastSelectedDeviceId, isNull);
  });

  test('update applies the updater and persists the result', () async {
    await service().save(const AppSettings(themeName: 'dark'));

    final updated = await service().update(
      (s) => s.copyWith(themeName: 'light', lastSelectedDeviceId: 'dev-2'),
    );

    expect(updated.themeName, 'light');
    expect(updated.lastSelectedDeviceId, 'dev-2');

    final reloaded = await service().load();
    expect(reloaded.themeName, 'light');
    expect(reloaded.lastSelectedDeviceId, 'dev-2');
  });

  test('malformed yaml falls back to default settings', () async {
    File(settingsPath)
      ..createSync(recursive: true)
      ..writeAsStringSync('this: is: not: valid: yaml: ::::');

    final settings = await service().load();

    expect(settings.themeName, 'dark');
    expect(settings.lastSelectedDeviceId, isNull);
  });

  test('configFilePath returns the injected path', () {
    expect(service().configFilePath, settingsPath);
  });

  test('save preserves plugins block and comments', () async {
    File(settingsPath)
      ..createSync(recursive: true)
      ..writeAsStringSync('''
# Simutil configuration
theme: dark
last_selected_device_id: ~

# My plugins
plugins:
  - id: custom
    label: Custom
    commands:
      - id: run
        label: Run
        command: echo
''');

    await service().save(
      const AppSettings(themeName: 'light', lastSelectedDeviceId: 'dev-1'),
    );

    final content = File(settingsPath).readAsStringSync();
    expect(content, contains('theme: light'));
    expect(content, contains('last_selected_device_id: dev-1'));
    expect(content, contains('# My plugins'));
    expect(content, contains('id: custom'));
  });
}
