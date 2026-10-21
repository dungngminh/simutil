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

  /// Address of the native `int32_t decode(int64_t id, const uint8_t* bytes,
  /// int64_t count)`, which [decode]s for texture `id` from any thread (e.g.
  /// through `dart:ffi` on a worker isolate); null where the platform only
  /// takes [decode]'s platform messages.
  static final Future<int?> decodeFunction = _channel
      .invokeMethod<int>('decodeFunction')
      .then<int?>((address) => address, onError: (Object _) => null);

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

/// A texture showing packed RGB888 frames that another process writes into
/// the shared file at [path] (e.g. the Android emulator's gRPC MMAP
/// transport). macOS only for now.
class SharedFrameTexture {
  SharedFrameTexture._(this.textureId, this._path);

  static const _channel = MethodChannel('simutil/h264');
  static const _presentChannel = 'simutil/h264/present';

  /// Id for a `Texture` widget.
  final int textureId;

  String _path;

  /// The owner-only file the writer fills; changes on [resize].
  String get path => _path;

  /// Creates a texture with a shared file of [capacity] bytes.
  static Future<SharedFrameTexture> create(int capacity) async {
    final reply = (await _channel.invokeMapMethod<String, Object?>(
      'sharedCreate',
      {'capacity': capacity},
    ))!;
    return SharedFrameTexture._(reply['id']! as int, reply['path']! as String);
  }

  /// Replaces the shared file with one of [capacity] bytes at a new [path];
  /// the old file is deleted, so the writer must move first or stop.
  Future<void> resize(int capacity) async =>
      _path = (await _channel.invokeMethod<String>('sharedResize', {
        'id': textureId,
        'capacity': capacity,
      }))!;

  /// Shows the [width]x[height] frame now in the file.
  void present(int width, int height) {
    final message = ByteData(16)
      ..setInt64(0, textureId, Endian.little)
      ..setInt32(8, width, Endian.little)
      ..setInt32(12, height, Endian.little);
    ServicesBinding.instance.defaultBinaryMessenger.send(
      _presentChannel,
      message,
    );
  }

  /// Frames shown on the texture so far.
  Future<int> framesShown() async =>
      await _channel.invokeMethod<int>('frames', {'id': textureId}) ?? 0;

  /// Unmaps and deletes the file and releases the texture.
  Future<void> dispose() =>
      _channel.invokeMethod<void>('dispose', {'id': textureId});
}
