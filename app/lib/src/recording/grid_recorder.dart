import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/recording/grid_record_quality.dart';
import 'package:simutil_app/src/recording/recording_lock.dart';

/// Records the stream grid: the grid's [RepaintBoundary] is captured at the
/// [GridRecordQuality]'s frame rate and scale and piped as raw RGBA into
/// ffmpeg.
class GridRecorderCubit extends CubitSignal<bool> {
  /// [onSaved] gets each finished file.
  GridRecorderCubit({this.onSaved, RecordingLock? recordingLock})
    : _recordingLock = recordingLock ?? RecordingLock(),
      super(initialState: false);

  static const _lockHolder = 'grid';

  /// One recording at a time, shared with per-device recording.
  final RecordingLock _recordingLock;

  /// Called with each finished recording.
  final void Function(String path)? onSaved;

  /// Wrap the grid in a `RepaintBoundary` with this key.
  final boundaryKey = GlobalKey();

  GridRecordQuality _quality = GridRecordQuality.standard;
  double _pixelRatio = 1;

  /// Captured frames per second of the current recording.
  int get fps => _quality.fps;

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

  /// Whether a recording is running.
  bool get isRecording => stateValue;

  /// Length of the current recording; zero when not recording.
  Duration get elapsed => stateValue ? _clock.elapsed : Duration.zero;

  /// Starts recording to [path] (`.mp4`) at [quality]; throws when ffmpeg
  /// is missing or [RecordingInProgress] while a device is recording.
  Future<void> start(
    String path, {
    GridRecordQuality quality = GridRecordQuality.standard,
  }) async {
    if (stateValue) return;
    _quality = quality;
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    _pixelRatio = quality.pixelRatio(view?.devicePixelRatio ?? 1);
    _recordingLock.acquire(_lockHolder, label: 'the grid');
    try {
      await _start(path);
    } catch (_) {
      _recordingLock.release(_lockHolder);
      rethrow;
    }
  }

  Future<void> _start(String path) async {
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
      '-vf',
      'pad=ceil(iw/2)*2:ceil(ih/2)*2',
      if (Platform.isMacOS) ...[
        '-c:v',
        'h264_videotoolbox',
        '-b:v',
        '${_quality.bitRateMbps}M',
      ] else ...[
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
        '-crf',
        '${_quality.crf}',
      ],
      '-pix_fmt',
      'yuv420p',
      path,
    ];
    for (final ffmpeg in _ffmpegCandidates) {
      try {
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

  /// The running tick; [stop] waits for it before closing ffmpeg's stdin.
  Future<void>? _ticking;

  Future<void> _tick() async {
    if (_capturing) return;
    _capturing = true;
    final done = Completer<void>();
    _ticking = done.future;
    try {
      final frame = await _capture();
      final size = _size;
      if (frame != null &&
          size != null &&
          frame.$2 == size.width &&
          frame.$3 == size.height) {
        _write(frame.$1);
      } else if (_last case final last?) {
        _write(last);
      }
      // Backpressure: no new capture until ffmpeg took this one, so a slow
      // encoder skips frames instead of buffering raw ones in memory.
      await _ffmpeg?.stdin.flush();
    } catch (_) {
      // ffmpeg exited; stop() reports the result.
    } finally {
      _capturing = false;
      done.complete();
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
    final image = await boundary.toImage(pixelRatio: _pixelRatio);
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
    await _ticking;
    final ffmpeg = _ffmpeg;
    _ffmpeg = null;
    final path = _path;
    _clock.stop();
    _last = null;
    emit(false);
    _recordingLock.release(_lockHolder);
    if (ffmpeg == null) return null;
    await ffmpeg.stdin.close();
    await ffmpeg.exitCode;
    if (path != null) onSaved?.call(path);
    return path;
  }

  @override
  Future<void> close() async {
    await stop();
    await super.close();
  }
}
