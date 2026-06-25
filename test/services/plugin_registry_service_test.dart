import 'dart:io';

import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/services/plugin_registry_service.dart';
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

  PluginRegistryServiceImpl serviceWith(String yaml) {
    File(pluginsPath).writeAsStringSync(yaml);
    return PluginRegistryServiceImpl(pluginsFilePath: pluginsPath);
  }

  test('creates a default settings.yaml when missing', () async {
    final service = PluginRegistryServiceImpl(pluginsFilePath: pluginsPath);
    final plugins = await service.load();

    expect(File(pluginsPath).existsSync(), isTrue);
    expect(plugins, isNotEmpty);
    expect(plugins.any((p) => p.id == 'scrcpy'), isTrue);
    expect(File(pluginsPath).readAsStringSync(), contains('theme: dark'));
  });

  test('loads plugins from a combined settings file with theme section', () async {
    final service = serviceWith('''
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
    final plugins = await service.load();
    expect(plugins, hasLength(1));
    expect(plugins.first.id, 'scrcpy');
  });

  test('loads and caches plugins from file', () async {
    final service = serviceWith('''
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
    final plugins = await service.load();
    expect(plugins, hasLength(1));
    expect(service.plugins, hasLength(1));
  });

  test('skips invalid entries but keeps valid ones', () async {
    final service = serviceWith('''
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
    final plugins = await service.load();
    expect(plugins, hasLength(1));
    expect(plugins.first.id, 'good');
  });

  test('drops duplicate plugin ids', () async {
    final service = serviceWith('''
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
    final plugins = await service.load();
    expect(plugins, hasLength(1));
    expect(plugins.first.label, 'First');
  });

  test('excludes disabled plugins', () async {
    final service = serviceWith('''
plugins:
  - id: off
    label: Off
    enabled: false
    commands:
      - id: a
        label: A
        command: echo
''');
    final plugins = await service.load();
    expect(plugins, isEmpty);
  });

  test('pluginsForDevice filters by command availability', () async {
    final service = serviceWith('''
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
    await service.load();

    final forAndroid = service.pluginsForDevice(androidRunning);
    expect(forAndroid, hasLength(1));
    expect(forAndroid.first.id, 'android-tool');

    final forIos = service.pluginsForDevice(iosRunning);
    expect(forIos, hasLength(1));
    expect(forIos.first.id, 'ios-tool');
  });

  test('commandByShortcut resolves command-level shortcut', () async {
    final service = serviceWith('''
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
    await service.load();

    final ref = service.commandByShortcut('s', androidRunning);
    expect(ref, isNotNull);
    expect(ref!.command.id, 'mirror');
    expect(ref.plugin.id, 'scrcpy');

    expect(service.commandByShortcut('s', iosRunning), isNull);
    expect(service.commandByShortcut('z', androidRunning), isNull);
  });

  test('pluginByShortcut resolves plugin-level shortcut', () async {
    final service = serviceWith('''
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
    await service.load();

    final plugin = service.pluginByShortcut('t', androidRunning);
    expect(plugin, isNotNull);
    expect(plugin!.id, 'tools');
    expect(service.pluginByShortcut('t', iosRunning), isNull);
  });

  test('returns empty list on malformed yaml', () async {
    final service = serviceWith('this: : : not valid: [');
    final plugins = await service.load();
    expect(plugins, isEmpty);
  });
}
