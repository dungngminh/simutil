import 'dart:io';

import 'package:simutil_shared/src/atomic_write.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('simutil_atomic_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('overlapping writes each land whole and leave no temp files', () async {
    final file = File('${dir.path}/state.json');
    final a = 'a' * 200000;
    final b = 'b' * 200000;

    await Future.wait([writeAtomically(file, a), writeAtomically(file, b)]);

    expect(file.readAsStringSync(), anyOf(a, b));
    expect(dir.listSync().map((e) => e.path), [file.path]);
  });
}
