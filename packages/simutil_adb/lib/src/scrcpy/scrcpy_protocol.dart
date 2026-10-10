import 'dart:typed_data';

/// Byte layouts of the scrcpy 4.x server protocol (see scrcpy
/// `doc/develop.md`, `Streamer.java`, `test_control_msg_serialize.c`).
abstract final class ScrcpyProtocol {
  /// Codec id of H.264 on the video socket.
  static const codecH264 = 0x68323634;

  static const _flagSession = 0x80000000;
  static const _flagConfig = 1 << 62;
  static const _flagKeyFrame = 1 << 61;
  static const _ptsMask = (1 << 61) - 1;

  static const _msgInjectKeycode = 0;
  static const _msgInjectTouch = 2;
  static const _msgResetVideo = 17;

  /// `AKEYCODE_HOME`.
  static const keyHome = 3;

  /// `AKEYCODE_BACK`.
  static const keyBack = 4;

  /// `AKEYCODE_APP_SWITCH`.
  static const keyAppSwitch = 187;

  /// `AKEYCODE_POWER`.
  static const keyPower = 26;

  /// Fingers use a regular pointer id; the mouse id (-1) would inject
  /// mouse events instead of touches.
  static const _fingerPointerId = 0;

  /// [frame] prefixed with the codec [config] (SPS/PPS).
  static Uint8List withConfig(Uint8List config, Uint8List frame) =>
      Uint8List(config.length + frame.length)
        ..setAll(0, config)
        ..setAll(config.length, frame);

  /// Encodes `RESET_VIDEO`: restarts the encoder, so a new session, config
  /// and key frame follow right away.
  static Uint8List resetVideo() => Uint8List.fromList([_msgResetVideo]);

  /// Encodes `INJECT_KEYCODE` (14 bytes); [action] 0 = down, 1 = up.
  static Uint8List keycode(int action, int keycode) {
    final b = ByteData(14)
      ..setUint8(0, _msgInjectKeycode)
      ..setUint8(1, action)
      ..setInt32(2, keycode)
      ..setInt32(6, 0) // repeat
      ..setInt32(10, 0); // metastate
    return b.buffer.asUint8List();
  }

  /// Encodes `INJECT_TOUCH_EVENT` (32 bytes). [action]: 0 down, 1 up,
  /// 2 move. [x]/[y] are pixels within a [width]x[height] screen.
  static Uint8List touch({
    required int action,
    required int x,
    required int y,
    required int width,
    required int height,
  }) {
    final b = ByteData(32)
      ..setUint8(0, _msgInjectTouch)
      ..setUint8(1, action)
      ..setUint64(2, _fingerPointerId)
      ..setInt32(10, x)
      ..setInt32(14, y)
      ..setUint16(18, width)
      ..setUint16(20, height)
      ..setUint16(22, action == 1 ? 0 : 0xffff) // pressure
      ..setInt32(24, 0) // action button
      ..setInt32(28, 0); // buttons
    return b.buffer.asUint8List();
  }
}

/// One parsed item from the video socket.
sealed class ScrcpyVideoItem {
  const ScrcpyVideoItem();
}

/// A new capture session (start, rotation): the frame size changed.
final class ScrcpyVideoSession extends ScrcpyVideoItem {
  /// Creates a session of [width]x[height] pixels.
  const ScrcpyVideoSession(this.width, this.height);

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;
}

/// An encoded packet; [config] packets carry SPS/PPS.
final class ScrcpyPacket extends ScrcpyVideoItem {
  /// Creates a packet holding Annex-B [data].
  const ScrcpyPacket(
    this.data, {
    required this.config,
    this.keyFrame = false,
    this.ptsMicros = 0,
  });

  /// Annex-B NAL units.
  final Uint8List data;

  /// Codec config (SPS/PPS), not a frame.
  final bool config;

  /// IDR frame.
  final bool keyFrame;

  /// Presentation time in microseconds.
  final int ptsMicros;
}

/// Incremental parser for the video socket after the dummy byte:
/// codec id (u32), then 12-byte session packets and 12-byte framed
/// media packets.
class ScrcpyVideoParser {
  final _buffer = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);
  int? _codec;

  /// Codec id once received.
  int? get codec => _codec;

  /// Feeds raw socket bytes; returns every complete item.
  List<ScrcpyVideoItem> add(List<int> bytes) {
    _buffer
      ..add(_pending)
      ..add(bytes);
    final data = _buffer.takeBytes();
    var offset = 0;
    final items = <ScrcpyVideoItem>[];

    if (_codec == null) {
      if (data.length < 4) {
        _pending = data;
        return items;
      }
      _codec = ByteData.sublistView(data, 0, 4).getUint32(0);
      offset = 4;
    }

    while (data.length - offset >= 12) {
      final header = ByteData.sublistView(data, offset, offset + 12);
      final first = header.getUint32(0);
      if (first & ScrcpyProtocol._flagSession != 0) {
        items.add(ScrcpyVideoSession(header.getUint32(4), header.getUint32(8)));
        offset += 12;
        continue;
      }
      final size = header.getUint32(8);
      if (data.length - offset - 12 < size) break;
      final ptsAndFlags = header.getUint64(0);
      items.add(
        ScrcpyPacket(
          Uint8List.sublistView(data, offset + 12, offset + 12 + size),
          config: ptsAndFlags & ScrcpyProtocol._flagConfig != 0,
          keyFrame: ptsAndFlags & ScrcpyProtocol._flagKeyFrame != 0,
          ptsMicros: ptsAndFlags & ScrcpyProtocol._ptsMask,
        ),
      );
      offset += 12 + size;
    }
    _pending = Uint8List.sublistView(data, offset);
    return items;
  }
}
