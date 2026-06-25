import 'dart:io';

import 'package:simutil/services/command_exec.dart';
import 'package:test/test.dart';

void main() {
  group('CommandResult', () {
    test('success is true only for exit code 0', () {
      expect(
        const CommandResult(stdout: '', stderr: '', exitCode: 0).success,
        isTrue,
      );
      expect(
        const CommandResult(stdout: '', stderr: '', exitCode: 1).success,
        isFalse,
      );
    });
  });

  group('CommandExecImpl', () {
    test('runs a real process and captures exit code 0', () async {
      final exec = CommandExecImpl();

      final result = await exec.run(
        Platform.resolvedExecutable,
        arguments: ['--version'],
      );

      expect(result.exitCode, 0);
      expect(result.success, isTrue);
    });

    test('reports non-zero exit for invalid arguments', () async {
      final exec = CommandExecImpl();

      final result = await exec.run(
        Platform.resolvedExecutable,
        arguments: ['--definitely-not-a-flag'],
      );

      expect(result.success, isFalse);
    });
  });
}
