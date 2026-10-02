import 'dart:io';

import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_plugins/simutil_plugins.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String pluginsPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('simutil_plugins_test');
    pluginsPath = '${tempDir.path}/plugins.yaml';
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final androidRunning = Device.android(
    id: 'emulator-5554',
    name: 'Pixel 7',
    state: DeviceState.booted,
    type: DeviceType.simulator,
  );
  final iosRunning = Device.ios(
    id: 'sim-1',
    name: 'iPhone 15',
    state: DeviceState.booted,
    type: DeviceType.simulator,
  );

  test('loadPluginCatalog seeds the default plugins when missing', () async {
    final catalog = await loadPluginCatalog(path: pluginsPath);

    expect(File(pluginsPath).existsSync(), isTrue);
    expect(catalog.plugin('scrcpy'), isNotNull);
    expect(catalog.warnings, isEmpty);
    expect(File(pluginsPath).readAsStringSync(), isNot(contains('theme:')));
  });

  test('loads plugins from a combined settings file with theme section', () {
    final catalog = PluginCatalog.parse('''
theme: light
last_selected_device_id: ~

plugins:
  - id: scrcpy
    label: scrcpy
    commands:
      - id: mirror
        label: Screen Mirror
        command: scrcpy
        platforms: [android]
        shortcut: s
''');
    final plugins = catalog.plugins;
    expect(plugins, hasLength(1));
    expect(plugins.first.id, 'scrcpy');
  });

  test('parses plugins', () {
    final catalog = PluginCatalog.parse('''
plugins:
  - id: scrcpy
    label: scrcpy
    commands:
      - id: mirror
        label: Screen Mirror
        command: scrcpy
        platforms: [android]
        shortcut: s
''');
    final plugins = catalog.plugins;
    expect(plugins, hasLength(1));
  });

  test('skips invalid entries but keeps valid ones', () {
    final catalog = PluginCatalog.parse('''
plugins:
  - id: good
    label: Good
    commands:
      - id: run
        label: Run
        command: echo
  - label: missing-id
    commands:
      - id: run
        label: Run
        command: echo
  - id: no-commands
    label: No Commands
''');
    final plugins = catalog.plugins;
    expect(plugins, hasLength(1));
    expect(plugins.first.id, 'good');
    expect(catalog.warnings, hasLength(2));
  });

  test('drops duplicate plugin ids', () {
    final catalog = PluginCatalog.parse('''
plugins:
  - id: dup
    label: First
    commands:
      - id: a
        label: A
        command: echo
  - id: dup
    label: Second
    commands:
      - id: b
        label: B
        command: echo
''');
    final plugins = catalog.plugins;
    expect(plugins, hasLength(1));
    expect(plugins.first.label, 'First');
    expect(catalog.warnings, ['Duplicate plugin id "dup" ignored']);
  });

  test('excludes disabled plugins', () {
    final catalog = PluginCatalog.parse('''
plugins:
  - id: off
    label: Off
    enabled: false
    commands:
      - id: a
        label: A
        command: echo
''');
    final plugins = catalog.plugins;
    expect(plugins, isEmpty);
  });

  test('forDevice filters by command availability', () {
    final catalog = PluginCatalog.parse('''
plugins:
  - id: android-tool
    label: Android Tool
    commands:
      - id: a
        label: A
        command: echo
        platforms: [android]
  - id: ios-tool
    label: iOS Tool
    commands:
      - id: b
        label: B
        command: echo
        platforms: [ios]
''');
    final forAndroid = catalog.forDevice(androidRunning);
    expect(forAndroid, hasLength(1));
    expect(forAndroid.first.id, 'android-tool');

    final forIos = catalog.forDevice(iosRunning);
    expect(forIos, hasLength(1));
    expect(forIos.first.id, 'ios-tool');
  });

  test('commandByShortcut resolves command-level shortcut', () {
    final catalog = PluginCatalog.parse('''
plugins:
  - id: scrcpy
    label: scrcpy
    commands:
      - id: mirror
        label: Screen Mirror
        command: scrcpy
        platforms: [android]
        shortcut: s
''');
    final ref = catalog.commandByShortcut('s', androidRunning);
    expect(ref, isNotNull);
    expect(ref!.command.id, 'mirror');
    expect(ref.plugin.id, 'scrcpy');

    expect(catalog.commandByShortcut('s', iosRunning), isNull);
    expect(catalog.commandByShortcut('z', androidRunning), isNull);
  });

  test('pluginByShortcut resolves plugin-level shortcut', () {
    final catalog = PluginCatalog.parse('''
plugins:
  - id: tools
    label: Tools
    shortcut: t
    commands:
      - id: a
        label: A
        command: echo
        platforms: [android]
''');
    final plugin = catalog.pluginByShortcut('t', androidRunning);
    expect(plugin, isNotNull);
    expect(plugin!.id, 'tools');
    expect(catalog.pluginByShortcut('t', iosRunning), isNull);
  });

  test('malformed yaml yields no plugins and a warning', () {
    final catalog = PluginCatalog.parse('this: : : not valid: [');
    expect(catalog.plugins, isEmpty);
    expect(catalog.warnings.single, startsWith('Invalid YAML'));
  });

  test('command finds a command by plugin and command id', () {
    final catalog = PluginCatalog.parse('''
plugins:
  - id: tools
    label: Tools
    commands:
      - id: a
        label: A
        command: echo
''');

    expect(catalog.command('tools', 'a')!.command.label, 'A');
    expect(catalog.command('tools', 'missing'), isNull);
    expect(catalog.command('missing', 'a'), isNull);
  });
}
