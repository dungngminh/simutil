import 'package:flutter/widgets.dart';
import 'package:simutil_core/simutil_core.dart';

import '../../devices/device_form_factor.dart';
import '../../stream/streams_state.dart';
import 'device_frame.dart';
import 'touch_surface.dart';

/// The live screen of a tile, framed or bare; [placeholder] covers the
/// connecting and failed states and [banner] warns about blocked input.
class StreamTileBody extends StatelessWidget {
  const StreamTileBody({
    super.key,
    required this.entry,
    required this.session,
    required this.maxVideoHeight,
    required this.showFrame,
    required this.placeholder,
    required this.banner,
  });

  final StreamEntry entry;
  final DeviceSession? session;
  final double maxVideoHeight;
  final bool showFrame;
  final Widget Function(SessionStatus status) placeholder;
  final Widget Function(DeviceSession session) banner;

  @override
  Widget build(BuildContext context) {
    final session = this.session;
    return switch (entry.status) {
      SessionLive(:final width, :final height, :final inputBlocked)
          when session != null =>
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (inputBlocked) banner(session),
            Padding(
              padding: const EdgeInsets.all(8),
              child: DeviceFrame(
                formFactor: DeviceFormFactor.of(entry.device),
                screenSize: Size(width.toDouble(), height.toDouble()),
                maxHeight: maxVideoHeight,
                enabled: showFrame,
                child: TouchSurface(session: session),
              ),
            ),
          ],
        ),
      final status => placeholder(status),
    };
  }
}
