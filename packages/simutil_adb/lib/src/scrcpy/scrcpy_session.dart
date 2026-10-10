import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:simutil_adb/src/scrcpy/scrcpy_install.dart';
import 'package:simutil_adb/src/scrcpy/scrcpy_protocol.dart';
import 'package:simutil_adb/src/scrcpy/scrcpy_video_worker.dart';
import 'package:simutil_core/simutil_core.dart';

/// Streams and controls an Android device with the user's scrcpy server.
///
/// Video is read on a worker isolate and fed to native decoders
/// ([attachDecoder]) or exposed as H.264 access units on [video]; touches
/// and keys go over the scrcpy control socket.
abstract interface class ScrcpySession implements DeviceSession {
  /// Creates a session for adb [serial]; call [start] to connect.
  factory ScrcpySession({
    required String serial,
    required String adbPath,
    required ScrcpyInstall install,
    required CommandExec exec,
    int maxSize,
    int videoBitRate,
    int maxFps,
  }) = _ScrcpySession;

  /// H.264 Annex-B access units, key frames prefixed with SPS/PPS. Each
  /// listener starts at a fresh key frame.
  Stream<Uint8List> get video;

  /// Feeds the video, from a fresh key frame, straight to a native decoder
  /// on the worker isolate: [decode] is the address of
  /// `int32_t decode(int64_t id, const uint8_t* bytes, int64_t count)`,
  /// called with [id]; a non-zero return requests a key frame.
  void attachDecoder(int decode, int id);

  /// Stops feeding decoder [id].
  void detachDecoder(int id);

  /// Asks the device for a fresh key frame (e.g. after a decoder dropped
  /// frames); at most once a second, since it restarts the encoder.
  void requestKeyFrame();
}

class _ScrcpySession implements ScrcpySession {
  _ScrcpySession({
    required this.serial,
    required this.adbPath,
    required this.install,
    required CommandExec exec,
    this.maxSize = 1280,
    this.videoBitRate = 8000000,
    this.maxFps = 60,
  }) : _exec = exec;

  final String serial;
  final String adbPath;
  final ScrcpyInstall install;
  final int maxSize;
  final int videoBitRate;
  final int maxFps;
  final CommandExec _exec;

  static const _remoteJar = '/data/local/tmp/scrcpy-server.jar';

  final _statusController = StreamController<SessionStatus>.broadcast();
  late final _frames = StreamController<(Uint8List, bool)>.broadcast(
    onListen: () => _video?.forward(true),
    onCancel: () => _video?.forward(false),
  );
  SessionStatus _status = const SessionConnecting();
  Process? _server;
  ScrcpyVideoWorker? _video;
  Socket? _controlSocket;
  int? _forwardPort;
  int? _width;
  int? _height;
  String? _recordingPath;
  bool _stopped = false;

  @override
  String get deviceId => serial;

  @override
  List<DeviceButton> get buttons => const [
    DeviceButton.back,
    DeviceButton.home,
    DeviceButton.recents,
  ];

  @override
  SessionStatus get status => _status;

  @override
  Stream<SessionStatus> get statusChanges => _statusController.stream;

  @override
  Stream<Uint8List> get video => Stream.multi((listener) {
    var synced = false;
    final sub = _frames.stream.listen((frame) {
      final (data, keyFrame) = frame;
      synced |= keyFrame;
      if (synced) listener.addSync(data);
    }, onDone: listener.closeSync);
    listener.onCancel = sub.cancel;
    _controlSocket?.add(ScrcpyProtocol.resetVideo());
  });

  @override
  void attachDecoder(int decode, int id) {
    _video?.attach(decode, id);
    _controlSocket?.add(ScrcpyProtocol.resetVideo());
  }

  @override
  void detachDecoder(int id) => _video?.detach(id);

  static const _keyFrameInterval = Duration(seconds: 1);
  DateTime? _keyFrameRequested;
  Timer? _keyFrameTimer;

  /// Requests inside the rate limit are deferred to its end (one pending at
  /// most), not dropped: a dropped request would leave the decoder waiting
  /// for the next periodic key frame, up to 1 s.
  @override
  void requestKeyFrame() {
    if (_keyFrameTimer != null || _stopped) return;
    final wait = switch (_keyFrameRequested) {
      final last? => _keyFrameInterval - DateTime.now().difference(last),
      null => Duration.zero,
    };
    if (wait <= Duration.zero) return _sendKeyFrameRequest();
    _keyFrameTimer = Timer(wait, () {
      _keyFrameTimer = null;
      _sendKeyFrameRequest();
    });
  }

  void _sendKeyFrameRequest() {
    if (_stopped) return;
    _keyFrameRequested = DateTime.now();
    _controlSocket?.add(ScrcpyProtocol.resetVideo());
  }

  void _emit(SessionStatus status) {
    if (_stopped && status is! SessionFailed) return;
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  @override
  Future<void> start() async {
    _emit(const SessionConnecting());
    try {
      await _startServer();
      await _connect();
    } catch (e) {
      // Emit before stop(): it closes the status stream.
      _emit(SessionFailed('$e'));
      await stop();
    }
  }

  Future<void> _startServer() async {
    final push = await _adb(['push', install.serverPath, _remoteJar]);
    if (!push.success) {
      throw StateError('adb push failed: ${push.stderr.trim()}');
    }

    final scid = Random().nextInt(0x7fffffff);
    final socketName = 'scrcpy_${scid.toRadixString(16).padLeft(8, '0')}';
    final forward = await _adb([
      'forward',
      'tcp:0',
      'localabstract:$socketName',
    ]);
    _forwardPort = int.tryParse(forward.stdout.trim());
    if (!forward.success || _forwardPort == null) {
      throw StateError('adb forward failed: ${forward.stderr.trim()}');
    }

    _server = await Process.start(adbPath, [
      '-s',
      serial,
      'shell',
      'CLASSPATH=$_remoteJar',
      'app_process',
      '/',
      'com.genymobile.scrcpy.Server',
      install.version,
      'scid=${scid.toRadixString(16)}',
      'log_level=warn',
      'tunnel_forward=true',
      'audio=false',
      'control=true',
      'send_device_meta=false',
      'max_size=$maxSize',
      'video_bit_rate=$videoBitRate',
      'max_fps=$maxFps',
      // A key frame every second (scrcpy's default is 10 s), so a decoder
      // that dropped frames or a late view recovers without a reset.
      'video_codec_options=i-frame-interval:int=1',
      'stay_awake=true',
    ]);
    unawaited(_server!.stdout.drain<void>());
    unawaited(_server!.stderr.drain<void>());
  }

  /// Video first (the server accepts it first), then control; the session
  /// is live once both are up and the first session header arrived.
  Future<void> _connect() async {
    final video = await ScrcpyVideoWorker.connect(
      _forwardPort!,
      onSize: (width, height) {
        _width = width;
        _height = height;
        _emitLive();
      },
      onFrame: (frame, keyFrame) {
        if (!_frames.isClosed) _frames.add((frame, keyFrame));
      },
      onKeyFrameNeeded: requestKeyFrame,
      onEnded: () {
        if (!_stopped) _emit(const SessionFailed('Stream ended'));
      },
    );
    if (_stopped) return video.stop();
    _video = video;
    if (_frames.hasListener) video.forward(true);
    _controlSocket =
        await Socket.connect(InternetAddress.loopbackIPv4, _forwardPort!)
          ..setOption(SocketOption.tcpNoDelay, true);
    unawaited(_controlSocket!.drain<void>());
    _emitLive();
  }

  /// Live only with a control socket, so a view's key-frame request on
  /// subscribing is not lost.
  void _emitLive() {
    final (width, height) = (_width, _height);
    if (width == null || height == null || _controlSocket == null) return;
    _emit(SessionLive(width: width, height: height));
  }

  @override
  void touch(TouchPhase phase, double x, double y) {
    final (width, height) = (_width, _height);
    if (width == null || height == null) return;
    _controlSocket?.add(
      ScrcpyProtocol.touch(
        action: switch (phase) {
          TouchPhase.down => 0,
          TouchPhase.up => 1,
          TouchPhase.move => 2,
        },
        x: (x.clamp(0, 1) * width).round(),
        y: (y.clamp(0, 1) * height).round(),
        width: width,
        height: height,
      ),
    );
  }

  @override
  void press(DeviceButton button) {
    final keycode = switch (button) {
      DeviceButton.back => ScrcpyProtocol.keyBack,
      DeviceButton.home => ScrcpyProtocol.keyHome,
      DeviceButton.recents => ScrcpyProtocol.keyAppSwitch,
      DeviceButton.lock => ScrcpyProtocol.keyPower,
      DeviceButton.volumeUp => ScrcpyProtocol.keyVolumeUp,
      DeviceButton.volumeDown => ScrcpyProtocol.keyVolumeDown,
    };
    _controlSocket
      ?..add(ScrcpyProtocol.keycode(0, keycode))
      ..add(ScrcpyProtocol.keycode(1, keycode));
  }

  @override
  Future<void> repairInput() async {}

  @override
  bool get isRecording => _recordingPath != null;

  /// Writes the TS feed (from a fresh key frame) to a temp file; on stop
  /// it is remuxed to [path] with ffmpeg when available, else kept as `.ts`.
  @override
  Future<void> startRecording(String path) async {
    final video = _video;
    if (_recordingPath != null || video == null) return;
    _recordingPath = path;
    await video.record('$path.ts');
    _controlSocket?.add(ScrcpyProtocol.resetVideo());
  }

  @override
  Future<String?> stopRecording() async {
    final path = _recordingPath;
    _recordingPath = null;
    if (path == null) return null;
    await _video?.record(null);
    for (final ffmpeg in _ffmpegCandidates) {
      final CommandResult remux;
      try {
        remux = await _exec.run(
          ffmpeg,
          arguments: [
            '-y',
            '-loglevel',
            'error',
            '-i',
            '$path.ts',
            '-c',
            'copy',
            path,
          ],
        );
      } catch (_) {
        continue;
      }
      if (remux.success) {
        await File('$path.ts').delete();
        return path;
      }
    }
    return '$path.ts';
  }

  @override
  Future<void> stop() async {
    if (_stopped) return;
    await stopRecording();
    _stopped = true;
    _keyFrameTimer?.cancel();
    _video?.stop();
    _controlSocket?.destroy();
    _server?.kill();
    if (_forwardPort case final port?) {
      await _adb(['forward', '--remove', 'tcp:$port']);
    }
    await _frames.close();
    await _statusController.close();
  }

  Future<CommandResult> _adb(List<String> args) => _exec.run(
    adbPath,
    arguments: ['-s', serial, ...args],
    timeout: const Duration(seconds: 30),
    priority: CommandPriority.interactive,
  );

  /// GUI apps on macOS do not inherit the shell PATH.
  static const _ffmpegCandidates = [
    'ffmpeg',
    '/opt/homebrew/bin/ffmpeg',
    '/usr/local/bin/ffmpeg',
    '/usr/bin/ffmpeg',
  ];
}
