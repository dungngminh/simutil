import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/stream/ios/ios_sim_session.dart';
import 'package:simutil_core/simutil_core.dart';

/// Answers every command once [gate] opens, like a slow `xcrun simctl`.
class _GatedExec implements CommandExec {
  final gate = Completer<void>();

  @override
  Future<CommandResult> run(
    String command, {
    List<String> arguments = const [],
    String? workingDirectory,
    Duration? timeout,
    CommandPriority priority = CommandPriority.background,
  }) async {
    await gate.future;
    return const CommandResult(stdout: '', stderr: '', exitCode: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('simutil/ios_stream');

  test('a stop during start leaves no native capture running', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'start' => {'textureId': 1, 'width': 0, 'height': 0},
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final exec = _GatedExec();
    final session = IosSimSession('UDID', exec: exec);
    final starting = session.start();
    await Future<void>.delayed(Duration.zero);
    await session.stop(); // the tile closes while xcrun is asked
    exec.gate.complete();
    await starting;

    expect(calls, isNot(contains('start')));
  });
}
