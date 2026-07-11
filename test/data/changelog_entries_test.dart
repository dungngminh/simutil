import 'package:simutil/data/changelog_entries.dart';
import 'package:test/test.dart';

void main() {
  test('returns the changelog entry matching the requested version', () {
    final entry = changelogEntryForVersion('0.6.2');

    expect(entry?.version, '0.6.2');
    expect(
      entry?.items,
      contains('Add Linux x64 support to the generated Homebrew formula.'),
    );
  });

  test('returns null when the requested version has no entry', () {
    expect(changelogEntryForVersion('9.9.9'), isNull);
  });
}
