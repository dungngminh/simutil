import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/devices/device_form_factor.dart';

/// A drawn bezel around a screen of [screenSize]; sizes itself to fit the
/// incoming width and [maxHeight] while keeping the screen's aspect ratio.
class DeviceFrame extends StatelessWidget {
  const DeviceFrame({
    super.key,
    required this.formFactor,
    required this.screenSize,
    required this.maxHeight,
    required this.enabled,
    required this.child,
  });

  final DeviceFormFactor formFactor;
  final Size screenSize;
  final double maxHeight;
  final bool enabled;
  final Widget child;

  /// Bezel thickness and screen corner radius as fractions of the screen's
  /// shorter side.
  (double, double) get _shape => switch (formFactor) {
    DeviceFormFactor.phone => (0.035, 0.11),
    DeviceFormFactor.tablet => (0.04, 0.045),
    DeviceFormFactor.tv => (0.012, 0.0),
    DeviceFormFactor.watch => (0.08, 0.22),
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final (bezelRatio, radiusRatio) = enabled ? _shape : (0.0, 0.0);
        final aspect = screenSize.width / screenSize.height;
        final short = min(screenSize.width, screenSize.height);
        final bezelPerPixel = bezelRatio * short;
        final outerW = screenSize.width + 2 * bezelPerPixel;
        final outerH = screenSize.height + 2 * bezelPerPixel;
        final scale = min(constraints.maxWidth / outerW, maxHeight / outerH);
        final screen = Size(
          screenSize.width * scale,
          screenSize.height * scale,
        );
        final bezel = bezelPerPixel * scale;
        final radius = radiusRatio * short * scale;

        final video = SizedBox.fromSize(
          size: screen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: AspectRatio(aspectRatio: aspect, child: child),
          ),
        );
        if (!enabled) return Center(child: video);
        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(radius + bezel),
              border: Border.all(color: const Color(0xFF3A3A3C), width: 1),
            ),
            child: Padding(padding: EdgeInsets.all(bezel), child: video),
          ),
        );
      },
    );
  }
}
