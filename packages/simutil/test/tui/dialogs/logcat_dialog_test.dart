@TestOn('linux || mac-os')
library;

import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/dialogs/logcat/logcat_dialog.dart';
import 'package:simutil_core/testing.dart';
import 'package:test/test.dart' hide isEmpty, isNotEmpty;

void main() {
  // `/bin/echo` stands in for adb: it prints its args as one log line.
  Future<void> pumpUntil(NoctermTester tester, String text) async {
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (tester.renderToString().contains(text)) return;
    }
  }

  test('Ctrl+C is left to the app; c clears the log', () async {
    await testNocterm('logcat ctrl+c', (tester) async {
      await tester.pumpComponent(
        LogcatDialog(
          device: testAndroidEmulator(),
          adbPath: '/bin/echo',
          onClose: () {},
        ),
      );
      await pumpUntil(tester, 'emulator-5554 logcat');
      expect(tester.renderToString(), contains('emulator-5554 logcat'));

      await tester.sendKeyEvent(
        const KeyboardEvent(
          logicalKey: LogicalKey.keyC,
          modifiers: ModifierKeys(ctrl: true),
        ),
      );
      expect(tester.renderToString(), contains('emulator-5554 logcat'));

      await tester.sendKey(LogicalKey.keyC);
      expect(tester.renderToString(), isNot(contains('emulator-5554 logcat')));
    });
  });
}
