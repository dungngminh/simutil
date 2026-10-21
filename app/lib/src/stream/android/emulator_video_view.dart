import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:simutil_adb/simutil_adb.dart';
import 'package:simutil_core/simutil_core.dart';
import 'package:simutil_h264/simutil_h264.dart';

import 'package:simutil_app/src/stream/stream_fps.dart';

/// Shows an [EmulatorGrpcSession]'s raw frames on a shared-file texture,
/// requested at the size the view takes on screen (like Android Studio).
class EmulatorVideoView extends StatefulWidget {
  /// Shows [session]'s screen.
  const EmulatorVideoView({super.key, required this.session});

  /// The session whose screen is shown.
  final EmulatorGrpcSession session;

  @override
  State<EmulatorVideoView> createState() => _EmulatorVideoViewState();
}

class _EmulatorVideoViewState extends State<EmulatorVideoView> {
  SharedFrameTexture? _texture;
  StreamSubscription<EmulatorFrame>? _frames;
  Timer? _resize;
  bool _disposed = false;

  /// Requested frame size in physical pixels; [_wanted] is the latest
  /// layout's, applied after it settles for a moment.
  (int, int)? _requested;
  (int, int)? _wanted;

  /// Layout changes (window resize, rotation) settle before a new request.
  static const _settle = Duration(milliseconds: 150);

  void _want(Size size, double pixelRatio) {
    final live = widget.session.status;
    if (live is! SessionLive || size.isEmpty) return;
    final wanted = (
      min((size.width * pixelRatio).round(), live.width),
      min((size.height * pixelRatio).round(), live.height),
    );
    if (wanted == _wanted) return;
    _wanted = wanted;
    _resize?.cancel();
    _resize = Timer(_requested == null ? Duration.zero : _settle, _request);
  }

  Future<void> _request() async {
    final wanted = _wanted;
    if (wanted == null || wanted == _requested || _disposed) return;
    _requested = wanted;
    final (width, height) = wanted;
    await _frames?.cancel();
    _frames = null;
    final capacity = width * height * 3;
    var texture = _texture;
    try {
      if (texture == null) {
        texture = await SharedFrameTexture.create(capacity);
        if (_disposed) return unawaited(texture.dispose());
        setFrameCounter(widget.session, texture.framesShown);
        setState(() => _texture = texture);
      } else {
        await texture.resize(capacity);
      }
    } catch (_) {
      _requested = null;
      return;
    }
    if (_disposed || _requested != wanted) return;
    _frames = widget.session
        .frames(path: texture.path, width: width, height: height)
        .listen(
          (frame) => texture!.present(frame.width, frame.height),
          // The session reports a lost emulator through its status.
          onError: (Object _) {},
        );
  }

  @override
  void dispose() {
    _disposed = true;
    _resize?.cancel();
    unawaited(_frames?.cancel());
    if (_texture case final texture?) {
      removeFrameCounter(widget.session, texture.framesShown);
      unawaited(texture.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _want(constraints.biggest, pixelRatio);
        return switch (_texture) {
          final texture? => Texture(
            textureId: texture.textureId,
            filterQuality: FilterQuality.low,
          ),
          null => const ColoredBox(color: Color(0xFF000000)),
        };
      },
    );
  }
}
