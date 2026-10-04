import 'package:nocterm/nocterm.dart';
import 'package:simutil/src/tui/components/app_header.dart';
import 'package:simutil_shared/simutil_shared.dart';
import 'package:test/test.dart' hide isEmpty, isNotEmpty;

void main() {
  test('update notice shows version and command at the right edge', () async {
    await testNocterm('app header update', (tester) async {
      await tester.pumpComponent(
        const AppHeader(
          themeName: 'dark',
          update: UpdateInfo(
            latestVersion: '9.9.9',
            source: InstallSource.homebrew,
          ),
        ),
      );
      final line = tester.terminalState
          .getText()
          .split('\n')
          .firstWhere((l) => l.contains('SimUtil'));
      expect(
        line.trimRight(),
        endsWith(
          'Version 9.9.9 available! Run: '
          'brew upgrade dungngminh/simutil/simutil',
        ),
      );
      expect(line, contains('Theme: Dark'));
    }, size: const Size(120, 5));
  });
}
