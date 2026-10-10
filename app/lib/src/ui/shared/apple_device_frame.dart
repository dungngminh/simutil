import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/stream/ios/apple_chrome.dart';
import 'package:simutil_app/src/ui/design/tokens.dart';
import 'package:simutil_core/simutil_core.dart';

/// Draws Apple's Simulator frame ([chrome]) with [child] in the screen
/// opening, clipped to the screen shape; fits the width and [maxHeight].
/// Its side buttons (volume, power) call [onButton] when clicked.
///
/// The frame is laid out at its size in points and scaled as one piece:
/// a nine-slice image keeps its corners and edges at their own size
/// whatever the box, so scaling only the box would leave the bezel at
/// 1x while the screen shrinks (screen over the bezel in small tiles).
class AppleDeviceFrame extends StatelessWidget {
  const AppleDeviceFrame({
    super.key,
    required this.chrome,
    required this.maxHeight,
    required this.child,
    this.onButton,
  });

  final AppleChrome chrome;
  final double maxHeight;
  final Widget child;
  final ValueChanged<DeviceButton>? onButton;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Apple's buttons barely show past the body; stick them out
        // further so they read and are easy to click.
        final padding = _boost(chrome.padding);
        final frame = padding.inflateSize(chrome.body);
        final scale = min(
          constraints.maxWidth / frame.width,
          maxHeight / frame.height,
        );
        final body = padding.topLeft & chrome.body;
        Widget button(AppleChromeInput input) => Positioned.fromRect(
          rect: _grow(input, chrome.body, padding),
          child: _SideButton(input: input, onButton: onButton),
        );
        return Center(
          child: SizedBox.fromSize(
            size: frame * scale,
            child: FittedBox(
              child: SizedBox.fromSize(
                size: frame,
                child: Stack(
                  // Hovered side buttons slide out past the frame.
                  clipBehavior: Clip.none,
                  children: [
                    for (final input in chrome.inputs)
                      if (!input.onTop) button(input),
                    Positioned.fromRect(
                      rect: body,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(child: _Bezel(chrome: chrome)),
                          SizedBox.fromSize(
                            size: chrome.screen,
                            child: _Screen(chrome: chrome, child: child),
                          ),
                        ],
                      ),
                    ),
                    for (final input in chrome.inputs)
                      if (input.onTop) button(input),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// How much further the side buttons stick out than Apple draws them.
const _buttonBoost = 4.0;

EdgeInsets _boost(EdgeInsets p) => EdgeInsets.fromLTRB(
  p.left > 0 ? p.left + _buttonBoost : 0,
  p.top > 0 ? p.top + _buttonBoost : 0,
  p.right > 0 ? p.right + _buttonBoost : 0,
  p.bottom > 0 ? p.bottom + _buttonBoost : 0,
);

/// [input]'s rect in the boosted frame, thickened by [_buttonBoost] away
/// from the body on the edge it sits on.
Rect _grow(AppleChromeInput input, Size body, EdgeInsets padding) {
  final r = input.rectIn(body, padding);
  const b = _buttonBoost;
  return switch (input.anchor) {
    'right' => Rect.fromLTRB(r.left, r.top, r.right + b, r.bottom),
    'top' => Rect.fromLTRB(r.left, r.top - b, r.right, r.bottom),
    'bottom' => Rect.fromLTRB(r.left, r.top, r.right, r.bottom + b),
    _ => Rect.fromLTRB(r.left - b, r.top, r.right, r.bottom),
  };
}

/// A side button image; shows its pressed image while held and sends its
/// [DeviceButton] on release. Buttons without one (action, crown) are
/// drawn only.
class _SideButton extends StatefulWidget {
  const _SideButton({required this.input, required this.onButton});

  final AppleChromeInput input;
  final ValueChanged<DeviceButton>? onButton;

  @override
  State<_SideButton> createState() => _SideButtonState();
}

class _SideButtonState extends State<_SideButton> {
  var _down = false;
  var _hover = false;

  /// How far a hovered button slides out, in points.
  static const _hoverOut = 3.0;

  Offset get _out => switch (widget.input.anchor) {
    'right' => const Offset(_hoverOut, 0),
    'top' => const Offset(0, -_hoverOut),
    'bottom' => const Offset(0, _hoverOut),
    _ => const Offset(-_hoverOut, 0),
  };

  @override
  Widget build(BuildContext context) {
    final input = widget.input;
    final image = Image.memory(
      _down ? input.imageDown ?? input.image : input.image,
      scale: 3,
      fit: BoxFit.fill,
      gaplessPlayback: true,
    );
    final button = input.button;
    final onButton = widget.onButton;
    if (button == null || onButton == null) return image;
    void setDown(bool down) => setState(() => _down = down);
    final out = _hover ? _out : Offset.zero;
    return Semantics(
      button: true,
      label: _labels[button],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setDown(true),
          onTapCancel: () => setDown(false),
          onTapUp: (_) {
            setDown(false);
            onButton(button);
          },
          child: AnimatedContainer(
            duration: SimuTokens.motion,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(out.dx, out.dy, 0),
            child: image,
          ),
        ),
      ),
    );
  }

  static const _labels = {
    DeviceButton.volumeUp: 'Volume up',
    DeviceButton.volumeDown: 'Volume down',
    DeviceButton.lock: 'Lock',
  };
}

/// [child] clipped to the screen opening's corners and, when the device
/// has one, its framebuffer mask (notch / Dynamic Island cut-out).
class _Screen extends StatelessWidget {
  const _Screen({required this.chrome, required this.child});

  final AppleChrome chrome;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var screen = child;
    if (chrome.mask case final mask?) {
      screen = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => ImageShader(
          mask,
          TileMode.clamp,
          TileMode.clamp,
          Matrix4.diagonal3Values(
            rect.width / mask.width,
            rect.height / mask.height,
            1,
          ).storage,
        ),
        child: screen,
      );
    }
    final radius = chrome.screenRadius;
    if (radius <= 0) return screen;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: screen,
    );
  }
}

class _Bezel extends StatelessWidget {
  const _Bezel({required this.chrome});

  final AppleChrome chrome;

  @override
  Widget build(BuildContext context) {
    if (chrome.composite case final bytes?) {
      return Image.memory(
        bytes,
        scale: 3,
        fit: BoxFit.fill,
        gaplessPlayback: true,
      );
    }
    if (chrome.nineSlice case final bytes?) {
      final c = chrome.corner;
      return Image.memory(
        bytes,
        scale: 3,
        fit: BoxFit.fill,
        centerSlice: Rect.fromLTWH(c.width, c.height, 1, 1),
        gaplessPlayback: true,
      );
    }
    return const SizedBox.shrink();
  }
}
