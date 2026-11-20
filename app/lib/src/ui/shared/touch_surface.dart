import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/ui/shared/session_view.dart';
import 'package:simutil_app/src/ui/shared/touch_dot.dart';
import 'package:simutil_core/simutil_core.dart';

/// The session's video with pointer input normalized to the video bounds.
/// Callers size it to the video's aspect ratio.
class TouchSurface extends StatefulWidget {
  const TouchSurface({super.key, required this.session});

  final DeviceSession session;

  @override
  State<TouchSurface> createState() => _TouchSurfaceState();
}

class _TouchSurfaceState extends State<TouchSurface> {
  /// The one pointer touching the device: a primary-button press (a right
  /// or middle click is not a tap) and nothing else until it lifts.
  int? _pointer;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return LayoutBuilder(
      builder: (context, constraints) {
        void send(TouchPhase phase, Offset p) => session.touch(
          phase,
          p.dx / constraints.maxWidth,
          p.dy / constraints.maxHeight,
        );
        bool ours(PointerEvent e) => e.pointer == _pointer;
        void lift(PointerEvent e) {
          if (!ours(e)) return;
          _pointer = null;
          send(TouchPhase.up, e.localPosition);
        }

        return Listener(
          // The whole video area, also before its first frame is drawn.
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            if (_pointer != null || e.buttons & kPrimaryButton == 0) return;
            _pointer = e.pointer;
            send(TouchPhase.down, e.localPosition);
          },
          onPointerMove: (e) {
            if (ours(e)) send(TouchPhase.move, e.localPosition);
          },
          onPointerUp: lift,
          // Otherwise the finger stays down on the device.
          onPointerCancel: lift,
          child: Stack(
            children: [
              RepaintBoundary(child: SessionView(session: session)),
              Positioned.fill(child: TouchDot(deviceId: session.deviceId)),
            ],
          ),
        );
      },
    );
  }
}
