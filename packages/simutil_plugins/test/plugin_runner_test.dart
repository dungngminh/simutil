import 'dart:async';
import 'dart:io';

import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_core/testing.dart';
import 'package:simutil_plugins/simutil_plugins.dart';
import 'package:test/test.dart';

void main() {
  final service = PluginRunner(CommandExec());
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
    test('checks that the command exists when no availability check', () async {
      final command = PluginCommandConfig(id: 'c', label: 'C', command: dart);

      expect(await service.isAvailable(pluginWith(command), command), isTrue);
    });

    test('finds a command on PATH without running it', () async {
      final exec = FakeCommandExec(
        (cmd, args) => cmd == 'which' || cmd == 'where'
            ? FakeCommandExec.ok('/usr/bin/open\n')
            : FakeCommandExec.fail('unknown option --version'),
      );
      const command = PluginCommandConfig(id: 'c', label: 'C', command: 'open');

      expect(
        await PluginRunner(exec).isAvailable(pluginWith(command), command),
        isTrue,
      );
      expect(exec.calls.single.arguments, ['open']);
      expect(exec.calls.single.timeout, isNotNull);
    });

    test('a hanging availability check counts as unavailable', () async {
      final command = PluginCommandConfig(
        id: 'c',
        label: 'C',
        command: 'tool',
        availability: PluginAvailabilityCheck(
          command: 'tool',
          args: const ['--check'],
        ),
      );
      final exec = FakeCommandExec((_, _) => throw TimeoutException('hang'));

      expect(
        await PluginRunner(exec).isAvailable(pluginWith(command), command),
        isFalse,
      );
      expect(exec.calls.single.timeout, isNotNull);
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
      expect(result.exitCode, 0);
    });

    test('inherit mode waits for exit and reports a non-zero code', () async {
      final command = PluginCommandConfig(
        id: 'c',
        label: 'Inherit',
        command: dart,
        args: const ['--definitely-not-a-flag'],
        mode: PluginRunMode.inherit,
      );

      final result = await service.run(command, null);

      expect(result.success, isFalse);
      expect(result.exitCode, isNot(0));
      expect(result.message, contains('exited with code'));
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
