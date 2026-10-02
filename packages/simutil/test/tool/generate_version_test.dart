import 'package:test/test.dart';

import '../../tool/generate_version.dart';

void main() {
  test('parseVersion reads only the top-level version', () {
    const pubspec = '''
name: simutil
version: 1.2.3
dependencies:
  foo:
    version: 9.9.9
''';
    expect(parseVersion(pubspec), '1.2.3');
  });

  test('parseVersion throws without a version', () {
    expect(() => parseVersion('name: simutil\n'), throwsFormatException);
  });

  test('generateVersionSource emits packageVersion', () {
    expect(
      generateVersionSource('1.2.3'),
      contains("const packageVersion = '1.2.3';"),
    );
  });
}
