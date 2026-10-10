import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_h264/simutil_h264.dart';

import 'package:simutil_app/src/stream/stream_fps.dart';

/// Decodes a [ScrcpySession]'s H.264 feed into a texture.
class ScrcpyVideoView extends StatefulWidget {
  /// Shows [session]'s video.
  const ScrcpyVideoView({super.key, required this.session});

  /// The session whose video is decoded.
  final ScrcpySession session;

  @override
  State<ScrcpyVideoView> createState() => _ScrcpyVideoViewState();
}

class _ScrcpyVideoViewState extends State<ScrcpyVideoView> {
  H264Decoder? _decoder;
  StreamSubscription<Uint8List>? _video;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final decoder = await H264Decoder.create();
    if (!mounted) return unawaited(decoder.dispose());
    setState(() => _decoder = decoder);
    final session = widget.session;
    setFrameCounter(session, decoder.framesShown);
    _video = session.video.listen(
      (frame) =>
          decoder.decode(frame, onKeyFrameNeeded: session.requestKeyFrame),
    );
  }

  @override
  void dispose() {
    if (_decoder case final decoder?) {
      removeFrameCounter(widget.session, decoder.framesShown);
    }
    _video?.cancel();
    _decoder?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_decoder) {
    final decoder? => Texture(
      textureId: decoder.textureId,
      filterQuality: FilterQuality.low,
    ),
    null => const ColoredBox(color: Color(0xFF000000)),
  };
}
