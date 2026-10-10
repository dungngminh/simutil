import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simutil_core/simutil_core.dart';

import '../device_stream.dart';
import 'scrcpy_install.dart';
import 'scrcpy_protocol.dart';
import 'ts_muxer.dart';

/// Streams an Android device with the user's scrcpy server and plays the
/// H.264 feed through media_kit (libmpv), muxed as MPEG-TS.
///
/// Data flow: scrcpy server on device → `adb forward` → video socket here →
/// headers stripped, MPEG-TS muxed → loopback TCP → mpv. Touches/keys go back over the
/// control socket.
class ScrcpyStream implements DeviceStream {
  ScrcpyStream({
    required this.serial,
    required this.adbPath,
    required this.install,
    required CommandExec exec,
  }) : _exec = exec;

  final String serial;
  final String adbPath;
  final ScrcpyInstall install;
  final CommandExec _exec;

  static const _remoteJar = '/data/local/tmp/scrcpy-server.jar';
  static const _connectAttempts = 50;

  final _player = Player();
  late final _video = VideoController(_player);

  Process? _server;
  ServerSocket? _relay;
  Socket? _mpvSocket;
  Socket? _videoSocket;
  Socket? _controlSocket;
  int? _forwardPort;
  Size? _size;
  final _muxer = TsMuxer();
  Uint8List? _config;
  Uint8List? _lastKeyFrame;
  bool _stopped = false;

  @override
  List<DeviceButton> get buttons => const [
    DeviceButton.back,
    DeviceButton.home,
    DeviceButton.recents,
  ];

  @override
  Future<void> start(void Function(StreamStatus status) onStatus) async {
    onStatus(const StreamConnecting());
    try {
      await _startServer();
      await _startPlayer();
      await _connect(onStatus);
    } catch (e) {
      await stop();
      onStatus(StreamFailed('$e'));
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

    // ponytail: long-lived streaming process, so Process.start instead of
    // CommandExec (see AGENTS.md "Do not use CommandExec").
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
      'max_size=1280',
      'video_bit_rate=6000000',
      'stay_awake=true',
    ]);
    unawaited(_server!.stdout.drain<void>());
    unawaited(_server!.stderr.drain<void>());
  }

  /// mpv reads MPEG-TS from a loopback socket we feed. It may reconnect
  /// (probe, then demux), so every new connection replaces the old one and
  /// first gets the last key frame.
  Future<void> _startPlayer() async {
    _relay = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final firstConnection = Completer<void>();
    _relay!.listen((socket) {
      socket.setOption(SocketOption.tcpNoDelay, true);
      // Writes after mpv drops a connection fail silently instead of
      // crashing the app.
      unawaited(socket.done.catchError((_) {}));
      if (_lastKeyFrame case final keyFrame?) socket.add(keyFrame);
      _mpvSocket = socket;
      if (!firstConnection.isCompleted) firstConnection.complete();
    });
    final native = _player.platform as NativePlayer;
    // Low-latency live playback of our MPEG-TS relay. The connection can be
    // idle while the screen is static, so no network timeout.
    for (final (key, value) in const [
      ('load-unsafe-playlists', 'yes'),
      ('demuxer', 'lavf'),
      ('demuxer-lavf-format', 'mpegts'),
      ('demuxer-lavf-analyzeduration', '0.1'),
      ('demuxer-lavf-probesize', '32768'),
      ('untimed', 'yes'),
      ('cache', 'no'),
      ('network-timeout', '0'),
      ('interpolation', 'no'),
    ]) {
      await native.setProperty(key, value);
    }
    await _player.setVolume(0);
    await _player.open(Media('tcp://127.0.0.1:${_relay!.port}'));
    await firstConnection.future.timeout(const Duration(seconds: 10));
  }

  /// The forward tunnel accepts connections before the server listens, so
  /// retry until the dummy byte arrives; then open the control socket.
  Future<void> _connect(void Function(StreamStatus status) onStatus) async {
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
          _onVideo(parser.add(data), onStatus);
        },
        onDone: () {
          if (!firstByte.isCompleted) firstByte.complete(false);
          if (sawDummy && !_stopped) {
            onStatus(const StreamFailed('Stream ended'));
          }
        },
        onError: (_) {
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

  void _onVideo(
    List<ScrcpyVideoItem> items,
    void Function(StreamStatus) onStatus,
  ) {
    for (final item in items) {
      switch (item) {
        case ScrcpySession(:final width, :final height):
          _size = Size(width.toDouble(), height.toDouble());
          onStatus(StreamLive(_size!));
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
          _mpvSocket?.add(ts);
      }
    }
  }

  @override
  Widget buildView() => Video(
    controller: _video,
    controls: NoVideoControls,
    fill: const Color(0xFF000000),
  );

  @override
  void touch(TouchPhase phase, Offset position) {
    final size = _size;
    if (size == null) return;
    _controlSocket?.add(
      ScrcpyProtocol.touch(
        action: switch (phase) {
          TouchPhase.down => 0,
          TouchPhase.up => 1,
          TouchPhase.move => 2,
        },
        x: (position.dx.clamp(0, 1) * size.width).round(),
        y: (position.dy.clamp(0, 1) * size.height).round(),
        width: size.width.toInt(),
        height: size.height.toInt(),
      ),
    );
  }

  @override
  void press(DeviceButton button) {
    final keycode = switch (button) {
      DeviceButton.back => ScrcpyProtocol.keyBack,
      DeviceButton.home => ScrcpyProtocol.keyHome,
      DeviceButton.recents => ScrcpyProtocol.keyAppSwitch,
      DeviceButton.lock => null,
    };
    if (keycode == null) return;
    _controlSocket
      ?..add(ScrcpyProtocol.keycode(0, keycode))
      ..add(ScrcpyProtocol.keycode(1, keycode));
  }

  @override
  Future<void> repairInput() async {}

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    _videoSocket?.destroy();
    _controlSocket?.destroy();
    _mpvSocket?.destroy();
    await _relay?.close();
    _server?.kill();
    if (_forwardPort case final port?) {
      await _adb(['forward', '--remove', 'tcp:$port']);
    }
    await _player.dispose();
  }

  Future<CommandResult> _adb(List<String> args) =>
      _exec.run(adbPath, arguments: ['-s', serial, ...args]);
}
