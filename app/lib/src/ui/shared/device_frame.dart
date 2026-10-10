import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/devices/device_form_factor.dart';
import 'package:simutil_app/src/ui/design/tokens.dart';
import 'package:simutil_core/simutil_core.dart';

/// A drawn bezel around a screen of [screenSize]; sizes itself to fit the
/// incoming width and [maxHeight] while keeping the screen's aspect ratio.
/// Phones and tablets get power and volume buttons on the right edge that
/// call [onButton].
class DeviceFrame extends StatelessWidget {
  const DeviceFrame({
    super.key,
    required this.formFactor,
    required this.screenSize,
    required this.maxHeight,
    required this.enabled,
    required this.child,
    this.onButton,
  });

  final DeviceFormFactor formFactor;
  final Size screenSize;
  final double maxHeight;
  final bool enabled;
  final Widget child;
  final ValueChanged<DeviceButton>? onButton;

  /// Bezel thickness and screen corner radius as fractions of the screen's
  /// shorter side.
  (double, double) get _shape => switch (formFactor) {
    DeviceFormFactor.phone => (0.035, 0.11),
    DeviceFormFactor.tablet => (0.04, 0.045),
    DeviceFormFactor.tv => (0.012, 0.0),
    DeviceFormFactor.watch => (0.08, 0.22),
  };

  bool get _hasButtons =>
      enabled &&
      (formFactor == DeviceFormFactor.phone ||
          formFactor == DeviceFormFactor.tablet);

  /// Right-edge buttons, top to bottom, as fractions of the frame height:
  /// power above the volume rocker, like a Pixel.
  static const _buttons = [
    (DeviceButton.lock, 0.17, 0.25),
    (DeviceButton.volumeUp, 0.30, 0.38),
    (DeviceButton.volumeDown, 0.385, 0.465),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final (bezelRatio, radiusRatio) = enabled ? _shape : (0.0, 0.0);
        final aspect = screenSize.width / screenSize.height;
        final short = min(screenSize.width, screenSize.height);
        final bezelPerPixel = bezelRatio * short;
        // How far the buttons stick out past the bezel, in screen pixels.
        final buttonPerPixel = _hasButtons ? 0.018 * short : 0.0;
        final outerW = screenSize.width + 2 * bezelPerPixel;
        final outerH = screenSize.height + 2 * bezelPerPixel;
        final scale = min(
          constraints.maxWidth / (outerW + buttonPerPixel),
          maxHeight / outerH,
        );
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
        final body = DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(radius + bezel),
            border: Border.all(color: const Color(0xFF3A3A3C), width: 1),
          ),
          child: Padding(padding: EdgeInsets.all(bezel), child: video),
        );
        if (!_hasButtons) return Center(child: body);
        final w = outerW * scale;
        final h = outerH * scale;
        final depth = buttonPerPixel * scale;
        return Center(
          child: SizedBox(
            width: w + depth,
            height: h,
            child: Stack(
              // Hovered buttons slide out past the frame.
              clipBehavior: Clip.none,
              children: [
                // Tucked under the bezel edge, so drawn first.
                for (final (button, top, bottom) in _buttons)
                  Positioned(
                    left: w - depth,
                    top: h * top,
                    width: depth * 2,
                    height: h * (bottom - top),
                    child: _FrameButton(
                      button: button,
                      radius: depth,
                      onButton: onButton,
                    ),
                  ),
                Positioned(left: 0, top: 0, width: w, height: h, child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A drawn side button; darker while held, sends [button] on release.
class _FrameButton extends StatefulWidget {
  const _FrameButton({
    required this.button,
    required this.radius,
    required this.onButton,
  });

  final DeviceButton button;
  final double radius;
  final ValueChanged<DeviceButton>? onButton;

  @override
  State<_FrameButton> createState() => _FrameButtonState();
}

class _FrameButtonState extends State<_FrameButton> {
  var _down = false;
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final shape = DecoratedBox(
      decoration: BoxDecoration(
        color: _down ? const Color(0xFF1C1C1E) : const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: const Color(0xFF3A3A3C), width: 1),
      ),
    );
    final onButton = widget.onButton;
    if (onButton == null) return shape;
    void setDown(bool down) => setState(() => _down = down);
    return Semantics(
      button: true,
      label: switch (widget.button) {
        DeviceButton.volumeUp => 'Volume up',
        DeviceButton.volumeDown => 'Volume down',
        _ => 'Power',
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setDown(true),
          onTapCancel: () => setDown(false),
          onTapUp: (_) {
            setDown(false);
            onButton(widget.button);
          },
          // Slides out by most of its visible depth while hovered.
          child: AnimatedContainer(
            duration: SimuTokens.motion,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(
              _hover ? widget.radius * 0.6 : 0,
              0,
              0,
            ),
            child: shape,
          ),
        ),
      ),
    );
  }
}
