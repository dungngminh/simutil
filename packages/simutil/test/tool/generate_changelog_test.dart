import 'package:test/test.dart';

import '../../tool/generate_changelog.dart';

void main() {
  test('parseChangelog skips Unreleased and flattens released bullets', () {
    const changelog = '''
## [Unreleased]

### Added

- Not released yet.

## [1.2.0] - 2026-07-10

### Added

- First item.

### Fixed

- Second item.

## [1.1.0] - 2026-06-01

### Changed

- Older item.

## [1.0.0]

### Fixed

- Dateless release item.
''';

    final entries = parseChangelog(changelog);

    expect(entries, hasLength(2));
    expect(entries[0].version, '1.2.0');
    expect(entries[0].date, '2026-07-10');
    expect(entries[0].items, ['First item.', 'Second item.']);
    expect(entries[1].version, '1.1.0');
    expect(entries[1].items, ['Older item.']);
  });
}
