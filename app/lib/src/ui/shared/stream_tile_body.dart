import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/devices/device_form_factor.dart';
import 'package:simutil_app/src/stream/ios/ios_sim_session.dart';
import 'package:simutil_app/src/stream/streams_state.dart';
import 'package:simutil_app/src/ui/shared/apple_device_frame.dart';
import 'package:simutil_app/src/ui/shared/device_frame.dart';
import 'package:simutil_app/src/ui/shared/touch_surface.dart';
import 'package:simutil_core/simutil_core.dart';

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
        _live(session, width, height, inputBlocked),
      final status => placeholder(status),
    };
  }

  Widget _live(
    DeviceSession session,
    int width,
    int height,
    bool inputBlocked,
  ) {
    // Leave room for the banner so the video still fits.
    final maxVideoHeight = max(
      0.0,
      inputBlocked ? this.maxVideoHeight - 56 : this.maxVideoHeight,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inputBlocked) banner(session),
        Padding(
          padding: const EdgeInsets.all(8),
          child: switch (session) {
            IosSimSession(:final chrome?) when showFrame => AppleDeviceFrame(
              chrome: chrome,
              maxHeight: maxVideoHeight,
              onButton: session.press,
              child: TouchSurface(session: session),
            ),
            _ => DeviceFrame(
              formFactor: DeviceFormFactor.of(entry.device),
              screenSize: Size(width.toDouble(), height.toDouble()),
              maxHeight: maxVideoHeight,
              enabled: showFrame,
              onButton: session.press,
              child: TouchSurface(session: session),
            ),
          },
        ),
      ],
    );
  }
}
