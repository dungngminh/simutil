import 'dart:async';
import 'dart:io';

import 'package:simutil_core/src/isolate_runner.dart';
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

  test('execute closes stdin so commands reading it see EOF', () async {
    final runner = IsolateRunner();
    await runner.init();

    final result = await runner.execute(
      'cat',
      const [],
      timeout: const Duration(seconds: 5),
    );

    expect(result.success, isTrue);
    await runner.dispose();
  }, testOn: '!windows');

  test(
    'execute runs a command in the isolate and returns its result',
    () async {
      final runner = IsolateRunner();
      await runner.init();

      final result = await runner.execute(Platform.resolvedExecutable, [
        '--version',
      ]);

      expect(result.exitCode, 0);
      expect(result.success, isTrue);

      await runner.dispose();
    },
  );

  test('a timeout arrives as a TimeoutException with its duration', () async {
    final runner = IsolateRunner();
    await runner.init();
    addTearDown(runner.dispose);

    await expectLater(
      runner.execute('sleep', const [
        '5',
      ], timeout: const Duration(milliseconds: 200)),
      throwsA(
        isA<TimeoutException>().having(
          (e) => e.duration,
          'duration',
          const Duration(milliseconds: 200),
        ),
      ),
    );
  }, testOn: '!windows');

  test('a missing executable arrives as a ProcessException', () async {
    final runner = IsolateRunner();
    await runner.init();
    addTearDown(runner.dispose);

    await expectLater(
      runner.execute('simutil-no-such-tool', const []),
      throwsA(isA<ProcessException>()),
    );
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
