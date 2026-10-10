import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:simutil_adb/src/scrcpy/scrcpy_install.dart';
import 'package:simutil_adb/src/scrcpy/scrcpy_protocol.dart';
import 'package:simutil_adb/src/scrcpy/ts_muxer.dart';
import 'package:simutil_core/simutil_core.dart';

/// Streams and controls an Android device with the user's scrcpy server.
///
/// Video is served as MPEG-TS on [videoUri] (loopback TCP) for any player
/// that reads `mpegts`; touches and keys go over the scrcpy control socket.
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

  /// `tcp://127.0.0.1:<port>` MPEG-TS feed once [start] returned. Every new
  /// connection replaces the previous one and gets a fresh key frame.
  Uri? get videoUri;
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
  static const _connectAttempts = 50;

  final _statusController = StreamController<SessionStatus>.broadcast();
  final _muxer = TsMuxer();
  SessionStatus _status = const SessionConnecting();
  Process? _server;
  ServerSocket? _relay;
  Socket? _consumer;
  Socket? _videoSocket;
  Socket? _controlSocket;
  int? _forwardPort;
  int? _width;
  int? _height;
  Uint8List? _config;
  Uint8List? _lastKeyFrame;
  IOSink? _recording;
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
  Uri? get videoUri => switch (_relay) {
    final relay? => Uri.parse('tcp://127.0.0.1:${relay.port}'),
    null => null,
  };

  void _emit(SessionStatus status) {
    if (_stopped && status is! SessionFailed) return;
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  @override
  Future<void> start() async {
    _emit(const SessionConnecting());
    try {
      await _startRelay();
      await _startServer();
      await _connect();
    } catch (e) {
      await stop();
      _emit(SessionFailed('$e'));
    }
  }

  Future<void> _startRelay() async {
    _relay = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _relay!.listen((socket) {
      socket.setOption(SocketOption.tcpNoDelay, true);
      unawaited(socket.done.catchError((_) {}));
      if (_lastKeyFrame case final keyFrame?) socket.add(keyFrame);
      _consumer = socket;
      _controlSocket?.add(ScrcpyProtocol.resetVideo());
    });
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

    // Long-lived streaming process: Process.start, not CommandExec.
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
      'stay_awake=true',
    ]);
    unawaited(_server!.stdout.drain<void>());
    unawaited(_server!.stderr.drain<void>());
  }

  /// The forward tunnel accepts connections before the server listens, so
  /// retry until the dummy byte arrives; then open the control socket.
  Future<void> _connect() async {
    for (var attempt = 0; attempt < _connectAttempts && !_stopped; attempt++) {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _forwardPort!,
      );
      final parser = ScrcpyVideoParser();
      final firstByte = Completer<bool>();
      var sawDummy = false;
      socket.listen(
        (bytes) {
          var data = bytes;
          if (!sawDummy) {
            sawDummy = true;
            firstByte.complete(true);
            data = bytes.sublist(1);
          }
          _onVideo(parser.add(data));
        },
        onDone: () {
          if (!firstByte.isCompleted) firstByte.complete(false);
          if (sawDummy && !_stopped) _emit(const SessionFailed('Stream ended'));
        },
        onError: (Object _) {
          if (!firstByte.isCompleted) firstByte.complete(false);
        },
        cancelOnError: true,
      );
      if (await firstByte.future) {
        _videoSocket = socket;
        _controlSocket =
            await Socket.connect(InternetAddress.loopbackIPv4, _forwardPort!)
              ..setOption(SocketOption.tcpNoDelay, true);
        unawaited(_controlSocket!.drain<void>());
        return;
      }
      socket.destroy();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('scrcpy server did not start on $serial');
  }

  void _onVideo(List<ScrcpyVideoItem> items) {
    for (final item in items) {
      switch (item) {
        case ScrcpyVideoSession(:final width, :final height):
          _width = width;
          _height = height;
          _emit(SessionLive(width: width, height: height));
        case ScrcpyPacket(config: true, :final data):
          _config = data; // SPS/PPS, repeated on every key frame
        case ScrcpyPacket(:final data, :final keyFrame, :final ptsMicros):
          final config = _config;
          final isKey = keyFrame && config != null;
          final ts = _muxer.frame(
            isKey ? Uint8List.fromList([...config, ...data]) : data,
            pts90k: (ptsMicros * 9 ~/ 100) & 0x1ffffffff,
            keyFrame: isKey,
          );
          if (isKey) _lastKeyFrame = ts;
          _consumer?.add(ts);
          _recording?.add(ts);
      }
    }
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
    };
    _controlSocket
      ?..add(ScrcpyProtocol.keycode(0, keycode))
      ..add(ScrcpyProtocol.keycode(1, keycode));
  }

  @override
  Future<void> repairInput() async {}

  @override
  bool get isRecording => _recording != null;

  /// Writes the TS feed (from a fresh key frame) to a temp file; on stop
  /// it is remuxed to [path] with ffmpeg when available, else kept as `.ts`.
  @override
  Future<void> startRecording(String path) async {
    if (_recording != null) return;
    _recordingPath = path;
    final sink = File('$path.ts').openWrite();
    _recording = sink;
    _controlSocket?.add(ScrcpyProtocol.resetVideo());
  }

  @override
  Future<String?> stopRecording() async {
    final sink = _recording;
    final path = _recordingPath;
    _recording = null;
    _recordingPath = null;
    if (sink == null || path == null) return null;
    await sink.close();
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
    _videoSocket?.destroy();
    _controlSocket?.destroy();
    _consumer?.destroy();
    await _relay?.close();
    _server?.kill();
    if (_forwardPort case final port?) {
      await _adb(['forward', '--remove', 'tcp:$port']);
    }
    await _statusController.close();
  }

  Future<CommandResult> _adb(List<String> args) => _exec.run(
    adbPath,
    arguments: ['-s', serial, ...args],
    timeout: const Duration(seconds: 30),
  );

  /// GUI apps on macOS do not inherit the shell PATH.
  static const _ffmpegCandidates = [
    'ffmpeg',
    '/opt/homebrew/bin/ffmpeg',
    '/usr/local/bin/ffmpeg',
    '/usr/bin/ffmpeg',
  ];
}
