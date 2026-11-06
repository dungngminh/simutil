@TestOn('linux || mac-os')
library;

import 'dart:io';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/dialogs/logcat/logcat_dialog.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart' hide isEmpty, isNotEmpty;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('simutil_adb_'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// A stand-in for adb running [script].
  Future<String> fakeAdb(String script) async {
    final adb = File('${dir.path}/adb')
      ..writeAsStringSync('#!/bin/sh\n$script\n');
    await Process.run('chmod', ['+x', adb.path]);
    return adb.path;
  }

  Future<void> pumpUntil(NoctermTester tester, String text) async {
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (tester.renderToString().contains(text)) return;
    }
  }

  test('Ctrl+C is left to the app; c clears the log', () async {
    // Like logcat: prints a line and keeps running.
    final adb = await fakeAdb('echo "I/Test: hello"\nexec sleep 30');
    await testNocterm('logcat ctrl+c', (tester) async {
      await tester.pumpComponent(
        LogcatDialog(
          device: testAndroidEmulator(),
          adbPath: adb,
          onClose: () {},
        ),
      );
      await pumpUntil(tester, 'I/Test: hello');
      expect(tester.renderToString(), contains('I/Test: hello'));

      await tester.sendKeyEvent(
        const KeyboardEvent(
          logicalKey: LogicalKey.keyC,
          modifiers: ModifierKeys(ctrl: true),
        ),
      );
      expect(tester.renderToString(), contains('I/Test: hello'));

      await tester.sendKey(LogicalKey.keyC);
      expect(tester.renderToString(), isNot(contains('I/Test: hello')));
    });
  });

  test('shows adb errors and when adb exits', () async {
    final adb = await fakeAdb('echo "error: device not found" >&2\nexit 1');

    await testNocterm(
      'logcat adb error',
      (tester) async {
        await tester.pumpComponent(
          LogcatDialog(
            device: testAndroidEmulator(),
            adbPath: adb,
            onClose: () {},
          ),
        );
        await pumpUntil(tester, 'exited (1)');
        await pumpUntil(tester, 'device not found');

        final screen = tester.renderToString();
        expect(screen, contains('[adb] error: device not found'));
        expect(screen, contains('adb logcat exited (1)'));
      },
      // Room for both lines; their order depends on the pipes.
      size: const Size(100, 60),
    );
  });
}
