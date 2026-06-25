import 'package:simutil/models/device.dart';
import 'package:simutil/models/device_os.dart';
import 'package:simutil/models/device_state.dart';
import 'package:simutil/models/device_type.dart';
import 'package:simutil/models/plugin_config.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

PluginConfig _pluginFromYaml(String yaml) {
  final doc = loadYaml(yaml) as YamlMap;
  return PluginConfig.fromMap(doc);
}

void main() {
  final androidRunning = Device.android(
    id: 'emulator-5554',
    name: 'Pixel 7',
    state: DeviceState.booted,
    type: DeviceType.simulator,
  );
  final androidStopped = Device.android(
    id: 'avd-1',
    name: 'Pixel 4',
    state: DeviceState.shutdown,
    type: DeviceType.simulator,
  );
  final iosRunning = Device.ios(
    id: 'sim-1',
    name: 'iPhone 15',
    state: DeviceState.booted,
    type: DeviceType.simulator,
  );

  group('PluginRunMode', () {
    test('parses inherit and defaults to detached', () {
      expect(PluginRunMode.fromString('inherit'), PluginRunMode.inherit);
      expect(PluginRunMode.fromString('detached'), PluginRunMode.detached);
      expect(PluginRunMode.fromString(null), PluginRunMode.detached);
      expect(PluginRunMode.fromString('garbage'), PluginRunMode.detached);
    });
  });

  group('PluginConfig.fromMap', () {
    test('parses a full plugin with multiple commands', () {
      final plugin = _pluginFromYaml('''
id: scrcpy
label: scrcpy
description: Screen mirroring
availability:
  command: scrcpy
  args: [--version]
commands:
  - id: mirror
    label: Screen Mirror
    command: scrcpy
    args: [-s, "{device.id}"]
    platforms: [android]
    requires_running: true
    mode: detached
    shortcut: S
  - id: no-audio
    label: No Audio
    command: scrcpy
    args: [-s, "{device.id}", --no-audio]
    platforms: [android]
''');

      expect(plugin.id, 'scrcpy');
      expect(plugin.label, 'scrcpy');
      expect(plugin.enabled, isTrue);
      expect(plugin.commands, hasLength(2));
      expect(plugin.availability?.command, 'scrcpy');

      final mirror = plugin.commands.first;
      expect(mirror.id, 'mirror');
      expect(mirror.platforms, [DeviceOs.android]);
      expect(mirror.requiresRunning, isTrue);
      expect(mirror.mode, PluginRunMode.detached);
      expect(mirror.shortcut, 's', reason: 'shortcut is normalized to lower');
    });

    test('throws when commands list is missing or empty', () {
      expect(
        () => _pluginFromYaml('id: x\nlabel: X\ncommands: []'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _pluginFromYaml('id: x\nlabel: X'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when required fields are missing', () {
      expect(
        () => _pluginFromYaml(
          'label: X\ncommands:\n  - id: a\n    label: A\n    command: c',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on unknown platform', () {
      expect(
        () => _pluginFromYaml('''
id: x
label: X
commands:
  - id: a
    label: A
    command: c
    platforms: [windows]
'''),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PluginCommandConfig.matches', () {
    test('filters by platform', () {
      final plugin = _pluginFromYaml('''
id: x
label: X
commands:
  - id: a
    label: A
    command: c
    platforms: [android]
''');
      final command = plugin.commands.first;
      expect(command.matches(androidRunning), isTrue);
      expect(command.matches(iosRunning), isFalse);
      expect(command.matches(null), isFalse);
    });

    test('filters by requires_running', () {
      final plugin = _pluginFromYaml('''
id: x
label: X
commands:
  - id: a
    label: A
    command: c
    platforms: [android]
    requires_running: true
''');
      final command = plugin.commands.first;
      expect(command.matches(androidRunning), isTrue);
      expect(command.matches(androidStopped), isFalse);
    });

    test('empty platforms matches any device', () {
      final plugin = _pluginFromYaml('''
id: x
label: X
commands:
  - id: a
    label: A
    command: c
''');
      final command = plugin.commands.first;
      expect(command.matches(androidRunning), isTrue);
      expect(command.matches(iosRunning), isTrue);
      expect(command.matches(null), isTrue);
    });
  });

  group('PluginCommandConfig.resolveArgs', () {
    test('interpolates device template variables', () {
      final plugin = _pluginFromYaml('''
id: x
label: X
commands:
  - id: a
    label: A
    command: c
    args: ["{device.id}", "--name={device.name}", "{device.os}"]
''');
      final command = plugin.commands.first;
      expect(command.resolveArgs(androidRunning), [
        'emulator-5554',
        '--name=Pixel 7',
        'android',
      ]);
    });

    test('leaves templates untouched when device is null', () {
      final plugin = _pluginFromYaml('''
id: x
label: X
commands:
  - id: a
    label: A
    command: c
    args: ["{device.id}"]
''');
      final command = plugin.commands.first;
      expect(command.resolveArgs(null), ['{device.id}']);
    });
  });

  group('PluginConfig.commandsFor', () {
    test('returns only matching commands', () {
      final plugin = _pluginFromYaml('''
id: x
label: X
commands:
  - id: android-only
    label: Android
    command: c
    platforms: [android]
  - id: ios-only
    label: iOS
    command: c
    platforms: [ios]
''');
      expect(plugin.commandsFor(androidRunning), hasLength(1));
      expect(plugin.commandsFor(androidRunning).first.id, 'android-only');
      expect(plugin.hasCommandsFor(iosRunning), isTrue);
      expect(plugin.commandsFor(iosRunning).first.id, 'ios-only');
    });
  });
}
