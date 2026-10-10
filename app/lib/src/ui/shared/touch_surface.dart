import 'package:flutter/widgets.dart';
import 'package:simutil_core/simutil_core.dart';

import 'session_view.dart';

/// The session's video with pointer input normalized to the video bounds.
/// Callers size it to the video's aspect ratio.
class TouchSurface extends StatelessWidget {
  const TouchSurface({super.key, required this.session});

  final DeviceSession session;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void send(TouchPhase phase, Offset p) => session.touch(
          phase,
          p.dx / constraints.maxWidth,
          p.dy / constraints.maxHeight,
        );
        return Listener(
          onPointerDown: (e) => send(TouchPhase.down, e.localPosition),
          onPointerMove: (e) => send(TouchPhase.move, e.localPosition),
          onPointerUp: (e) => send(TouchPhase.up, e.localPosition),
          child: RepaintBoundary(child: SessionView(session: session)),
        );
      },
    );
  }
}
