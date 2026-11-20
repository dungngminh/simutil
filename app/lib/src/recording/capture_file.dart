import 'dart:io';

/// `<directory>/simutil-<name>-<timestamp>.<extension>` for a recording or
/// screenshot, joined with the platform's separator (Explorer's `/select,`
/// needs backslashes).
///
/// [name] is a device id or `grid`; characters that are not safe in a file
/// name everywhere become `_`: a Wi-Fi adb serial such as
/// `192.168.1.5:5555` would otherwise write an NTFS alternate data stream
/// or fail on Windows.
String captureFilePath(
  String directory,
  String name,
  String extension, {
  DateTime? now,
  String? separator,
}) {
  final stamp = (now ?? DateTime.now()).toIso8601String().replaceAll(':', '-');
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return '$directory${separator ?? Platform.pathSeparator}'
      'simutil-$safe-$stamp.$extension';
}
