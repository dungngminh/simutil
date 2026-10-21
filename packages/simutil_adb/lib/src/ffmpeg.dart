import 'dart:io';

import 'package:simutil_core/simutil_core.dart';

/// GUI apps on macOS do not inherit the shell PATH.
const _ffmpegCandidates = [
  'ffmpeg',
  '/opt/homebrew/bin/ffmpeg',
  '/usr/local/bin/ffmpeg',
  '/usr/bin/ffmpeg',
];

/// Encoder arguments for H.264: hardware on macOS, libx264 elsewhere.
final h264EncoderArgs = Platform.isMacOS
    ? const ['-c:v', 'h264_videotoolbox', '-b:v', '8M']
    : const ['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23'];

/// Runs ffmpeg with [arguments]; false when it is missing or failed.
Future<bool> runFfmpeg(
  CommandExec exec,
  List<String> arguments, {
  Duration? timeout,
}) async {
  for (final ffmpeg in _ffmpegCandidates) {
    try {
      final result = await exec.run(
        ffmpeg,
        arguments: arguments,
        timeout: timeout,
      );
      if (result.success) return true;
    } catch (_) {
      continue;
    }
  }
  return false;
}
