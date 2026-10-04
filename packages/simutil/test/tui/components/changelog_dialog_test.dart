import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/changelog_dialog.dart';
import 'package:simutil_shared/simutil_shared.dart';
import 'package:test/test.dart' hide isEmpty, isNotEmpty;

void main() {
  final entry = ChangelogEntry(
    version: '9.9.9',
    date: '2026-10-04',
    items: [for (var i = 0; i < 60; i++) 'item $i'],
  );

  test('arrow down scrolls the notes on the first press', () async {
    await testNocterm('changelog scroll', (tester) async {
      await tester.pumpComponent(
        ChangelogDialog(entries: [entry], onDismiss: () {}),
      );
      expect(tester.terminalState, containsText('9.9.9 — 2026-10-04'));

      await tester.sendArrowDown();

      expect(tester.terminalState, isNot(containsText('9.9.9 — 2026-10-04')));
      expect(tester.terminalState, containsText('item 0'));

      await tester.sendArrowUp();

      expect(tester.terminalState, containsText('9.9.9 — 2026-10-04'));
    }, size: const Size(120, 40));
  });

  test('items render inline markdown bold without asterisks', () async {
    await testNocterm('changelog markdown', (tester) async {
      await tester.pumpComponent(
        ChangelogDialog(
          entries: const [
            ChangelogEntry(
              version: '9.9.9',
              date: '2026-10-04',
              items: ['**Breaking:** plain tail'],
            ),
          ],
          onDismiss: () {},
        ),
      );

      expect(tester.terminalState, containsText('• Breaking: plain tail'));
      expect(tester.terminalState, isNot(containsText('**')));
      expect(
        tester.terminalState,
        hasStyledText(
          'Breaking:',
          const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }, size: const Size(120, 40));
  });
}
