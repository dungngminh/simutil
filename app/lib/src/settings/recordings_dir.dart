import 'dart:io';

/// `~/Movies/SimUtil` on macOS, `~/Videos/SimUtil` elsewhere; created on use.
String recordingsDirectory() {
  final home =
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  final dir = Directory(
    '$home${Platform.pathSeparator}${Platform.isMacOS ? 'Movies' : 'Videos'}'
    '${Platform.pathSeparator}SimUtil',
  )..createSync(recursive: true);
  return dir.path;
}
