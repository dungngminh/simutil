import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../stream/ios/apple_chrome.dart';

/// Draws Apple's Simulator frame ([chrome]) with [child] in the screen
/// opening, clipped to the screen shape; fits the width and [maxHeight].
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
        final screen = chrome.screen * scale;
        final mask = chrome.mask;
        Widget screenChild = child;
        if (mask != null) {
          screenChild = ShaderMask(
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
            child: child,
          );
        }
        return Center(
          child: SizedBox.fromSize(
            size: body * scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: _Bezel(chrome: chrome)),
                SizedBox.fromSize(size: screen, child: screenChild),
              ],
            ),
          ),
        );
      },
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
        centerSlice: Rect.fromLTWH(c, c, 1, 1),
        gaplessPlayback: true,
      );
    }
    return const SizedBox.shrink();
  }
}
