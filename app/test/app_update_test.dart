import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simutil_app/src/update/app_update_cubit.dart';

String _releases(List<Map<String, Object>> releases) => jsonEncode([
  for (final r in releases)
    {
      'draft': false,
      'prerelease': false,
      'html_url': 'https://example.com/${r['tag_name']}',
      ...r,
    },
]);

void main() {
  test('picks the newest app release, skipping CLI tags', () {
    final json = _releases([
      {'tag_name': 'v1.2.0'},
      {'tag_name': 'app-v0.4.0'},
      {'tag_name': 'app-v0.3.0'},
    ]);
    expect(
      newerAppRelease(json, '0.3.1'),
      const AppUpdate(version: '0.4.0', url: 'https://example.com/app-v0.4.0'),
    );
  });

  test('skips drafts and prereleases', () {
    final json = _releases([
      {'tag_name': 'app-v0.5.0', 'prerelease': true},
      {'tag_name': 'app-v0.4.1', 'draft': true},
      {'tag_name': 'app-v0.4.0'},
    ]);
    expect(newerAppRelease(json, '0.3.1')?.version, '0.4.0');
  });

  test('null when up to date', () {
    final json = _releases([
      {'tag_name': 'app-v0.3.1'},
    ]);
    expect(newerAppRelease(json, '0.3.1'), isNull);
    expect(newerAppRelease('[]', '0.3.1'), isNull);
  });

  test(
    'versionBeforeUpdate reports the old version once after an update',
    () async {
      final dir = Directory.systemTemp.createTempSync('simutil-version');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/desktop-version';
      // First run: nothing to announce.
      expect(await versionBeforeUpdate(current: '0.2.0', path: path), isNull);
      expect(await versionBeforeUpdate(current: '0.2.0', path: path), isNull);
      expect(await versionBeforeUpdate(current: '0.3.0', path: path), '0.2.0');
      expect(await versionBeforeUpdate(current: '0.3.0', path: path), isNull);
    },
  );
}
