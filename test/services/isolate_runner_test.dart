import 'dart:io';

import 'package:simutil/services/isolate_runner.dart';
import 'package:test/test.dart';

void main() {
  test('init makes the runner ready and dispose tears it down', () async {
    final runner = IsolateRunner();

    expect(runner.isReady, isFalse);
    await runner.init();
    expect(runner.isReady, isTrue);

    await runner.dispose();
    expect(runner.isReady, isFalse);
  });

  test('execute runs a command in the isolate and returns its result', () async {
    final runner = IsolateRunner();
    await runner.init();

    final result = await runner.execute(Platform.resolvedExecutable, [
      '--version',
    ]);

    expect(result.exitCode, 0);
    expect(result.success, isTrue);

    await runner.dispose();
  });

  test('pending requests error out when disposed', () async {
    final runner = IsolateRunner();
    await runner.init();

    final future = runner.execute(Platform.resolvedExecutable, ['--version']);
    final expectation = expectLater(future, throwsA(isA<StateError>()));
    await runner.dispose();
    await expectation;
  });
}
