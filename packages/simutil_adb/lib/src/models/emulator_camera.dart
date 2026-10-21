import 'dart:io';

final _plainModes = RegExp(r'^(emulated|none|virtualscene|webcam\d+)$');

/// Builds `-camera-back` / `-camera-front` emulator args from camera sources.
///
/// A source is `emulated`, `none`, `virtualscene`, `webcam<N>` (host camera,
/// see `emulator -webcam-list`), `image:<path>` or `video:<path>`. Paths are
/// made absolute and must exist. Throws [FormatException] otherwise.
List<String> emulatorCameraArgs({String? back, String? front}) => [
  if (back != null) ...['-camera-back', _cameraMode(back)],
  if (front != null) ...['-camera-front', _cameraMode(front)],
];

String _cameraMode(String source) {
  final value = source.trim();
  if (_plainModes.hasMatch(value)) return value;
  final colon = value.indexOf(':');
  final kind = colon < 0 ? value : value.substring(0, colon);
  final prefix = switch (kind) {
    'image' => 'imagefile',
    'video' => 'videofile',
    _ => throw FormatException(
      'Unknown camera source "$source". Use emulated, none, virtualscene, '
      'webcam<N>, image:<path> or video:<path>.',
    ),
  };
  final path = colon < 0 ? '' : value.substring(colon + 1);
  if (path.isEmpty) throw FormatException('Missing file in "$source".');
  final file = File(path);
  if (!file.existsSync()) {
    throw FormatException('Camera file not found: $path');
  }
  return '$prefix:${file.absolute.path}';
}
