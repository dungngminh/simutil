import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Records the stream grid: the grid's [RepaintBoundary] is captured
/// [fps] times a second and piped as raw RGBA into ffmpeg.
class GridRecorderCubit extends CubitSignal<bool> {
  GridRecorderCubit({this.fps = 20}) : super(initialState: false);

  /// Wrap the grid in a `RepaintBoundary` with this key.
  final boundaryKey = GlobalKey();
  final int fps;

  static const _ffmpegCandidates = [
    'ffmpeg',
    '/opt/homebrew/bin/ffmpeg',
    '/usr/local/bin/ffmpeg',
    '/usr/bin/ffmpeg',
  ];

  Process? _ffmpeg;
  Timer? _timer;
  String? _path;
  Size? _size;
  bool _capturing = false;
  final _clock = Stopwatch();
  int _written = 0;
  Uint8List? _last;

  bool get isRecording => stateValue;

  /// Starts recording to [path] (`.mp4`); throws when ffmpeg is missing.
  Future<void> start(String path) async {
    if (stateValue) return;
    final first = await _capture();
    if (first == null) throw StateError('Nothing to record yet');
    final (image, width, height) = first;
    _size = Size(width.toDouble(), height.toDouble());
    _ffmpeg = await _startFfmpeg(path, width, height);
    _path = path;
    _clock
      ..reset()
      ..start();
    _written = 0;
    _write(image);
    emit(true);
    _timer = Timer.periodic(
      Duration(milliseconds: 1000 ~/ fps),
      (_) => _tick(),
    );
  }

  Future<Process> _startFfmpeg(String path, int width, int height) async {
    final args = [
      '-y',
      '-loglevel',
      'error',
      '-f',
      'rawvideo',
      '-pix_fmt',
      'rgba',
      '-s',
      '${width}x$height',
      '-r',
      '$fps',
      '-i',
      '-',
      // Even dimensions for H.264.
      '-vf',
      'pad=ceil(iw/2)*2:ceil(ih/2)*2',
      if (Platform.isMacOS) ...[
        '-c:v',
        'h264_videotoolbox',
        '-b:v',
        '8M',
      ] else ...[
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
      ],
      '-pix_fmt',
      'yuv420p',
      path,
    ];
    for (final ffmpeg in _ffmpegCandidates) {
      try {
        // Long-lived encoder fed through stdin: Process.start.
        final process = await Process.start(ffmpeg, args);
        unawaited(process.stdout.drain<void>());
        unawaited(process.stderr.drain<void>());
        return process;
      } on ProcessException {
        continue;
      }
    }
    throw StateError('ffmpeg not found; install it to record the grid');
  }

  Future<void> _tick() async {
    if (_capturing) return;
    _capturing = true;
    try {
      final frame = await _capture();
      final size = _size;
      // Frames of another size (window resized) are dropped.
      if (frame != null &&
          size != null &&
          frame.$2 == size.width &&
          frame.$3 == size.height) {
        _write(frame.$1);
      } else if (_last case final last?) {
        _write(last);
      }
    } finally {
      _capturing = false;
    }
  }

  /// Captures can be slower than [fps]; repeat the frame so the file keeps
  /// real-time duration.
  void _write(Uint8List frame) {
    _last = frame;
    final due = (_clock.elapsedMicroseconds * fps / 1e6).floor() + 1;
    final ffmpeg = _ffmpeg;
    if (ffmpeg == null) return;
    for (; _written < due; _written++) {
      ffmpeg.stdin.add(frame);
    }
  }

  Future<(Uint8List, int, int)?> _capture() async {
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return null;
    final image = await boundary.toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      return (data.buffer.asUint8List(), image.width, image.height);
    } finally {
      image.dispose();
    }
  }

  /// Finishes the file; returns its path.
  Future<String?> stop() async {
    if (!stateValue) return null;
    _timer?.cancel();
    _timer = null;
    final ffmpeg = _ffmpeg;
    _ffmpeg = null;
    final path = _path;
    _clock.stop();
    _last = null;
    emit(false);
    if (ffmpeg == null) return null;
    await ffmpeg.stdin.close();
    await ffmpeg.exitCode;
    return path;
  }

  @override
  Future<void> close() async {
    await stop();
    await super.close();
  }
}
