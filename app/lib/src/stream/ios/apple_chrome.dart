import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Apple's Simulator device frame for one simulator, read from Xcode's
/// DeviceKit chrome bundles by the native plugin. Sizes are in points.
class AppleChrome {
  const AppleChrome({
    required this.body,
    required this.screen,
    this.composite,
    this.nineSlice,
    this.corner = 0,
    this.mask,
  });

  /// Whole device body.
  final Size body;

  /// Active screen, centered in [body].
  final Size screen;

  /// Full-body frame image (rendered at 3x).
  final Uint8List? composite;

  /// Corner | 1pt edge | corner image for `centerSlice` when there is no
  /// [composite] (rendered at 3x).
  final Uint8List? nineSlice;

  /// Corner size of [nineSlice].
  final double corner;

  /// Screen shape (rounded corners, sensor cut-out) as an alpha mask.
  final ui.Image? mask;

  static Future<AppleChrome?> load(MethodChannel channel, String udid) async {
    final map = await channel.invokeMapMethod<String, Object?>('chrome', {
      'udid': udid,
    });
    if (map == null) return null;
    final screenWidth = map['screenWidth'] as double?;
    final screenHeight = map['screenHeight'] as double?;
    if (screenWidth == null || screenHeight == null) return null;
    final screen = Size(screenWidth, screenHeight);
    final insets = (map['insets']! as Map).cast<String, double>();
    final body = switch ((map['bodyWidth'], map['bodyHeight'])) {
      (final double w, final double h) => Size(w, h),
      _ => Size(
        screen.width + insets['left']! + insets['right']!,
        screen.height + insets['top']! + insets['bottom']!,
      ),
    };
    ui.Image? mask;
    if (map['mask'] case final Uint8List bytes) {
      final codec = await ui.instantiateImageCodec(bytes);
      mask = (await codec.getNextFrame()).image;
    }
    return AppleChrome(
      body: body,
      screen: screen,
      composite: map['composite'] as Uint8List?,
      nineSlice: map['nineSlice'] as Uint8List?,
      corner: (map['corner'] as double?) ?? 0,
      mask: mask,
    );
  }
}
