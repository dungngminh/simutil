import 'package:flutter/widgets.dart';

import '../../stream/device_stream.dart';

/// The stream's video with pointer input normalized to the video bounds.
/// Callers size it to the video's aspect ratio.
class TouchSurface extends StatelessWidget {
  const TouchSurface({super.key, required this.stream});

  final DeviceStream stream;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        Offset norm(Offset p) =>
            Offset(p.dx / constraints.maxWidth, p.dy / constraints.maxHeight);
        return Listener(
          onPointerDown: (e) =>
              stream.touch(TouchPhase.down, norm(e.localPosition)),
          onPointerMove: (e) =>
              stream.touch(TouchPhase.move, norm(e.localPosition)),
          onPointerUp: (e) =>
              stream.touch(TouchPhase.up, norm(e.localPosition)),
          child: stream.buildView(),
        );
      },
    );
  }
}
