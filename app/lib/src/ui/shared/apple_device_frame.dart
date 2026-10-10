import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:simutil_app/src/stream/ios/apple_chrome.dart';

/// Draws Apple's Simulator frame ([chrome]) with [child] in the screen
/// opening, clipped to the screen shape; fits the width and [maxHeight].
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
  });

  final AppleChrome chrome;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final body = chrome.body;
        final scale = min(
          constraints.maxWidth / body.width,
          maxHeight / body.height,
        );
        return Center(
          child: SizedBox.fromSize(
            size: body * scale,
            child: FittedBox(
              child: SizedBox.fromSize(
                size: body,
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
            ),
          ),
        );
      },
    );
  }
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
