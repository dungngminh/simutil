import 'dart:io';

final _plainModes = RegExp(r'^(emulated|none|virtualscene|webcam\d+)$');

/// Builds `-camera-back` / `-camera-front` emulator args from camera sources.
///
/// A source is `emulated`, `none`, `virtualscene`, `webcam<N>` (host camera,
/// see `emulator -webcam-list`), `image:<path>` or `video:<path>`. Paths are
/// made absolute and must exist. One webcam cannot feed both cameras (the
/// emulator then crashes the camera app). Throws [FormatException] otherwise.
List<String> emulatorCameraArgs({String? back, String? front}) {
  final backMode = back == null ? null : _cameraMode(back);
  final frontMode = front == null ? null : _cameraMode(front);
  if (backMode != null &&
      backMode == frontMode &&
      backMode.startsWith('webcam')) {
    throw FormatException(
      '$backMode cannot be both the back and front camera.',
    );
  }
  return [
    if (backMode != null) ...['-camera-back', backMode],
    if (frontMode != null) ...['-camera-front', frontMode],
  ];
}

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
