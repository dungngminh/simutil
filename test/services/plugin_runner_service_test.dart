import 'dart:io';

import 'package:simutil/models/plugin_config.dart';
import 'package:simutil/services/command_exec.dart';
import 'package:simutil/services/plugin_runner_service.dart';
import 'package:test/test.dart';

void main() {
  final service = PluginRunnerServiceImpl(CommandExecImpl());
  final dart = Platform.resolvedExecutable;

  PluginConfig pluginWith(
    PluginCommandConfig command, {
    PluginAvailabilityCheck? availability,
  }) => PluginConfig(
    id: 'p',
    label: 'P',
    commands: [command],
    availability: availability,
  );

  group('isAvailable', () {
    test('probes "<command> --version" when no availability check', () async {
      final command = PluginCommandConfig(id: 'c', label: 'C', command: dart);

      expect(await service.isAvailable(pluginWith(command), command), isTrue);
    });

    test('uses an explicit availability check when provided', () async {
      final command = PluginCommandConfig(
        id: 'c',
        label: 'C',
        command: 'whatever',
        availability: PluginAvailabilityCheck(
          command: dart,
          args: const ['--version'],
        ),
      );

      // command-level availability check is probed instead of the command.
      expect(await service.isAvailable(pluginWith(command), command), isTrue);
    });

    test('returns false when the executable does not exist', () async {
      const command = PluginCommandConfig(
        id: 'c',
        label: 'C',
        command: '/no/such/executable-xyz',
      );

      expect(await service.isAvailable(pluginWith(command), command), isFalse);
    });
  });

  group('run', () {
    test('detached mode reports success', () async {
      final command = PluginCommandConfig(
        id: 'c',
        label: 'Detached',
        command: dart,
        args: const ['--version'],
      );

      final result = await service.run(command, null);

      expect(result.success, isTrue);
      expect(result.message, contains('Detached'));
    });

    test('inherit mode reports success', () async {
      final command = PluginCommandConfig(
        id: 'c',
        label: 'Inherit',
        command: dart,
        args: const ['--version'],
        mode: PluginRunMode.inherit,
      );

      final result = await service.run(command, null);

      expect(result.success, isTrue);
    });

    test('unknown executable reports failure', () async {
      const command = PluginCommandConfig(
        id: 'c',
        label: 'Broken',
        command: '/no/such/executable-xyz',
      );

      final result = await service.run(command, null);

      expect(result.success, isFalse);
      expect(result.message, contains('Failed to run Broken'));
    });
  });
}
