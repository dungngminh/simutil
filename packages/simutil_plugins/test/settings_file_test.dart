import 'dart:io';

import 'package:simutil_plugins/simutil_plugins.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('simutil_settings_file_');
    path = '${dir.path}/nested/settings.yaml';
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('creates the file with only the plugins section', () async {
    await ensurePluginsSection(path);

    final content = File(path).readAsStringSync();
    expect(content, defaultPluginsYaml);
    expect(content, isNot(contains('theme:')));
  });

  test('appends plugins to a file without the key', () async {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('theme: light');

    await ensurePluginsSection(path);

    expect(
      File(path).readAsStringSync(),
      'theme: light\n\n$defaultPluginsYaml',
    );
  });

  test('leaves a file with an existing plugins key untouched', () async {
    const content = 'theme: light\nplugins: []\n';
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);

    await ensurePluginsSection(path);

    expect(File(path).readAsStringSync(), content);
  });
}
