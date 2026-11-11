@TestOn('linux || mac-os')
library;

import 'dart:convert';
import 'dart:io';

import 'package:simutil/src/tui/terminal/tui_supervisor.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('simutil_tty_'));
  tearDown(() => dir.deleteSync(recursive: true));

  // A FIFO cannot seek, like a tty: append mode fails on both.
  test('writeToTerminal writes to a non-seekable device', () async {
    final fifo = '${dir.path}/tty';
    expect((await Process.run('mkfifo', [fifo])).exitCode, 0);
    final reader = await Process.start('cat', [fifo]);
    final read = reader.stdout.transform(utf8.decoder).join();

    writeToTerminal(xtermRestoreSequence, path: fifo);

    expect(await read, xtermRestoreSequence);
    expect(await reader.exitCode, 0);
  });

  test('xtermRestoreSequence shows the cursor after leaving the '
      'alternate screen', () {
    expect(
      xtermRestoreSequence.indexOf('\x1b[?25h'),
      greaterThan(xtermRestoreSequence.indexOf('\x1b[?1049l')),
    );
  });
}
