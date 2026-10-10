import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:simutil_adb/src/scrcpy/scrcpy_protocol.dart';
import 'package:simutil_adb/src/scrcpy/ts_muxer.dart';

/// `int32_t decode(int64_t id, const uint8_t* bytes, int64_t count)`.
typedef ScrcpyNativeDecode = Int32 Function(Int64, Pointer<Uint8>, Int64);
typedef _Decode = int Function(int, Pointer<Uint8>, int);

/// Reads the scrcpy video socket on its own isolate, so demuxing, recording
/// and (with [attach]) handing frames to a native decoder never wait on the
/// UI thread.
class ScrcpyVideoWorker {
  ScrcpyVideoWorker._(this._commands, this._exit);

  static const _connectAttempts = 50;

  final SendPort _commands;
  final Future<void> _exit;

  /// Connects to the video socket on [port], retrying until the server's
  /// dummy byte arrives; throws when it never does.
  ///
  /// [onSize] gets each session header, [onFrame] every access unit (key
  /// frames prefixed with SPS/PPS) while [forward] is on, [onKeyFrameNeeded]
  /// an attached decoder dropping frames, and [onEnded] the socket closing.
  static Future<ScrcpyVideoWorker> connect(
    int port, {
    required void Function(int width, int height) onSize,
    required void Function(Uint8List frame, bool keyFrame) onFrame,
    required void Function() onKeyFrameNeeded,
    required void Function() onEnded,
  }) async {
    final events = ReceivePort();
    final exit = ReceivePort();
    final commands = Completer<SendPort>();
    final exited = Completer<void>();
    void fail(Object error) {
      if (!commands.isCompleted) commands.completeError(error);
    }

    exit.listen((_) {
      exit.close();
      events.close();
      fail(StateError('scrcpy video isolate exited'));
      exited.complete();
    });
    events.listen((message) {
      switch (message) {
        case final SendPort port:
          commands.complete(port);
        case (final int width, final int height):
          onSize(width, height);
        case (final Uint8List frame, final bool keyFrame):
          onFrame(frame, keyFrame);
        case _keyFrameNeeded:
          onKeyFrameNeeded();
        case _ended:
          onEnded();
        case final StateError error:
          fail(error);
        // An uncaught error: [error, stack trace] as strings.
        case [final Object? error, _]:
          fail(StateError('$error'));
          onEnded();
      }
    });
    await Isolate.spawn(
      _main,
      (events.sendPort, port),
      onExit: exit.sendPort,
      onError: events.sendPort,
      debugName: 'scrcpy video',
    );
    return ScrcpyVideoWorker._(await commands.future, exited.future);
  }

  /// Feeds every access unit from the next key frame on to the native
  /// [decode] function (its address) for decoder [id], called on the worker
  /// isolate; a non-zero return means frames were dropped.
  void attach(int decode, int id) => _commands.send(('attach', decode, id));

  /// Stops feeding decoder [id].
  void detach(int id) => _commands.send(('detach', id));

  /// Whether access units are sent to `onFrame`.
  void forward(bool on) => _commands.send(('forward', on));

  /// Writes MPEG-TS to [path] from now on, or stops writing when null;
  /// completes once the file is closed (or the worker has exited).
  Future<void> record(String? path) {
    final reply = ReceivePort();
    _commands.send(('record', path, reply.sendPort));
    return Future.any([reply.first, _exit]).whenComplete(reply.close);
  }

  /// Closes the socket and ends the isolate.
  void stop() => _commands.send(('stop',));

  static const _keyFrameNeeded = 'keyFrameNeeded';
  static const _ended = 'ended';

  static Future<void> _main((SendPort, int) args) async {
    final (events, port) = args;
    final video = _Video(events);
    final socket = await _connect(port, video.add);
    if (socket == null) {
      events.send(StateError('scrcpy server did not start'));
      return;
    }

    final commands = ReceivePort();
    Future<void> close() async {
      commands.close();
      socket.destroy();
      video.freeNative();
      await video.record(null);
    }

    unawaited(
      socket.done.then<void>((_) {}, onError: (Object _) {}).whenComplete(
        () async {
          events.send(_ended);
          await close();
        },
      ),
    );
    events.send(commands.sendPort);
    await for (final command in commands) {
      switch (command) {
        case ('attach', final int decode, final int id):
          video.decoders[id] = _Decoder(
            Pointer<NativeFunction<ScrcpyNativeDecode>>.fromAddress(
              decode,
            ).asFunction<_Decode>(isLeaf: true),
          );
        case ('detach', final int id):
          video.decoders.remove(id);
        case ('forward', final bool on):
          video.forward = on;
        case ('record', final String? path, final SendPort reply):
          await video.record(path);
          reply.send(null);
        case ('stop',):
          await close();
      }
    }
  }

  /// The forward tunnel accepts connections before the server listens, so
  /// retry until the dummy byte arrives; later bytes go to [onData].
  static Future<Socket?> _connect(
    int port,
    void Function(List<int>) onData,
  ) async {
    for (var attempt = 0; attempt < _connectAttempts; attempt++) {
      final Socket socket;
      try {
        socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
      } on SocketException {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        continue;
      }
      final firstByte = Completer<bool>();
      socket.listen(
        (bytes) {
          if (firstByte.isCompleted) return onData(bytes);
          firstByte.complete(true);
          if (bytes.length > 1) onData(bytes.sublist(1));
        },
        onDone: () {
          if (!firstByte.isCompleted) firstByte.complete(false);
        },
        onError: (Object _) {
          if (!firstByte.isCompleted) firstByte.complete(false);
        },
        cancelOnError: true,
      );
      if (await firstByte.future) return socket;
      socket.destroy();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }
}

class _Decoder {
  _Decoder(this.decode);

  final _Decode decode;

  /// Set at the first key frame; delta frames before it are skipped.
  bool synced = false;
}

/// Worker-isolate state: demuxer, attached decoders and the recording.
class _Video {
  _Video(this._events);

  final SendPort _events;
  final _parser = ScrcpyVideoParser();
  final _muxer = TsMuxer();
  final decoders = <int, _Decoder>{};
  bool forward = false;
  Uint8List? _config;
  IOSink? _recording;

  /// Native copy of the frame being decoded, reused and grown as needed.
  Pointer<Uint8> _native = nullptr;
  int _nativeSize = 0;

  Pointer<Uint8> _toNative(Uint8List frame) {
    if (frame.length > _nativeSize) {
      if (_native != nullptr) malloc.free(_native);
      _nativeSize = frame.length * 2;
      _native = malloc<Uint8>(_nativeSize);
    }
    _native.asTypedList(frame.length).setAll(0, frame);
    return _native;
  }

  void freeNative() {
    if (_native != nullptr) malloc.free(_native);
    _native = nullptr;
    _nativeSize = 0;
  }

  void add(List<int> bytes) {
    for (final item in _parser.add(bytes)) {
      switch (item) {
        case ScrcpyVideoSession(:final width, :final height):
          _events.send((width, height));
        case ScrcpyPacket(config: true, :final data):
          _config = data;
        case ScrcpyPacket(:final data, :final keyFrame, :final ptsMicros):
          final config = _config;
          final isKey = keyFrame && config != null;
          _frame(
            isKey ? ScrcpyProtocol.withConfig(config, data) : data,
            isKey,
            ptsMicros,
          );
      }
    }
  }

  void _frame(Uint8List frame, bool keyFrame, int ptsMicros) {
    var dropped = false;
    final native = decoders.isEmpty ? nullptr : _toNative(frame);
    for (final MapEntry(key: id, value: decoder) in decoders.entries) {
      decoder.synced |= keyFrame;
      if (!decoder.synced) continue;
      dropped |= decoder.decode(id, native, frame.length) != 0;
    }
    if (dropped) _events.send(ScrcpyVideoWorker._keyFrameNeeded);
    // A copy, so a view does not send the whole socket chunk.
    if (forward) _events.send((Uint8List.fromList(frame), keyFrame));
    _recording?.add(
      _muxer.frame(
        frame,
        pts90k: (ptsMicros * 9 ~/ 100) & 0x1ffffffff,
        keyFrame: keyFrame,
      ),
    );
  }

  Future<void> record(String? path) async {
    final previous = _recording;
    _recording = path == null ? null : File(path).openWrite();
    await previous?.close();
  }
}
