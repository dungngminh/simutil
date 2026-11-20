import 'dart:io';

var _writes = 0;

/// Writes [content] to [file] through a temporary file and a rename, so a
/// reader (the TUI and a CLI command may run at once) never sees it empty
/// or half written, and quitting mid-write keeps the old file.
///
/// The temporary name is unique per process and write: two writers sharing
/// one would rename each other's half-written file into place.
Future<void> writeAtomically(File file, String content) async {
  final tmp = File('${file.path}.$pid.${_writes++}.tmp');
  try {
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(file.path);
  } catch (_) {
    if (await tmp.exists()) await tmp.delete();
    rethrow;
  }
}
