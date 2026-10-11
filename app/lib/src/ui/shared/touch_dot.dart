import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/di.dart';
import 'package:simutil_app/src/stream/touch_marks.dart';
import 'package:simutil_app/src/ui/design/tokens.dart';
import 'package:simutil_core/simutil_core.dart';

/// A dot where an agent is touching [deviceId]'s screen: it follows the
/// finger while down and fades out shortly after it lifts.
class TouchDot extends StatefulWidget {
  const TouchDot({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<TouchDot> createState() => _TouchDotState();
}

class _TouchDotState extends State<TouchDot> {
  StreamSubscription<TouchMark>? _sub;
  Timer? _hide;
  Offset? _at;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(TouchDot old) {
    super.didUpdateWidget(old);
    if (old.deviceId != widget.deviceId) _listen();
  }

  void _listen() {
    _sub?.cancel();
    // Absent in widget tests that skip dependency setup.
    if (!getIt.isRegistered<TouchMarks>()) return;
    _sub = getIt<TouchMarks>().of(widget.deviceId).listen(_onMark);
  }

  void _onMark(TouchMark m) {
    _hide?.cancel();
    setState(() {
      _at = Offset(m.x, m.y);
      _visible = true;
    });
    // A tap's down and up are ~60 ms apart: hold the dot long enough to see.
    if (m.phase == TouchPhase.up) {
      _hide = Timer(const Duration(milliseconds: 350), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final at = _at;
    if (at == null) return const SizedBox.shrink();
    final accent = SimuTokens.of(context).accent;
    const size = 26.0;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: at.dx * box.maxWidth - size / 2,
              top: at.dy * box.maxHeight - size / 2,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: Duration(milliseconds: _visible ? 60 : 300),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.45),
                    border: Border.all(
                      color: const Color(0xFFFFFFFF),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
