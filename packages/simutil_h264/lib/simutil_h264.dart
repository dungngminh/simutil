import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A native H.264 decoder (VideoToolbox, Media Foundation or libavcodec)
/// that renders into the Flutter texture [textureId].
class H264Decoder {
  H264Decoder._(this.textureId);

  static const _channel = MethodChannel('simutil/h264');
  static const _decodeChannel = 'simutil/h264/decode';

  /// Id for a `Texture` widget.
  final int textureId;

  /// Creates a decoder with its own texture.
  static Future<H264Decoder> create() async =>
      H264Decoder._((await _channel.invokeMethod<int>('create'))!);

  /// Queues one Annex-B access unit; frames before the first SPS/PPS are
  /// dropped. When the decoder falls behind it drops delta frames until the
  /// next key frame and calls [onKeyFrameNeeded] once.
  void decode(Uint8List accessUnit, {VoidCallback? onKeyFrameNeeded}) {
    final reply = ServicesBinding.instance.defaultBinaryMessenger.send(
      _decodeChannel,
      message(textureId, accessUnit),
    );
    if (onKeyFrameNeeded != null) {
      reply?.then((r) {
        if (r != null && r.lengthInBytes > 0) onKeyFrameNeeded();
      });
    }
  }

  /// Frames shown on the texture so far.
  Future<int> framesShown() async =>
      await _channel.invokeMethod<int>('frames', {'id': textureId}) ?? 0;

  /// Stops decoding and releases the texture.
  Future<void> dispose() =>
      _channel.invokeMethod<void>('dispose', {'id': textureId});

  /// The decode message: `int64 LE` texture id, then the access unit.
  static ByteData message(int textureId, Uint8List accessUnit) {
    final bytes = Uint8List(8 + accessUnit.length)..setAll(8, accessUnit);
    return bytes.buffer.asByteData()..setInt64(0, textureId, Endian.little);
  }
}
