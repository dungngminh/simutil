import 'dart:io';

/// Writes [content] to [file] through a temporary file and a rename, so a
/// reader (the TUI and a CLI command may run at once) never sees it empty
/// or half written, and quitting mid-write keeps the old file.
Future<void> writeAtomically(File file, String content) async {
  final tmp = File('${file.path}.tmp');
  await tmp.writeAsString(content, flush: true);
  await tmp.rename(file.path);
}
