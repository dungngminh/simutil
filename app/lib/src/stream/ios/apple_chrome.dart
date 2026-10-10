import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:simutil_core/simutil_core.dart';

/// Apple's Simulator device frame for one simulator, read from Xcode's
/// DeviceKit chrome bundles by the native plugin. Sizes are in points.
class AppleChrome {
  /// Creates a chrome from decoded images and insets.
  const AppleChrome({
    required this.body,
    required this.screen,
    this.composite,
    this.nineSlice,
    this.corner = Size.zero,
    this.outerRadius = 0,
    this.mask,
    this.padding = EdgeInsets.zero,
    this.inputs = const [],
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

  /// Corner size of [nineSlice]; not always square.
  final Size corner;

  /// Corner radius of the body's outline (`simpleOutsideBorder`).
  final double outerRadius;

  /// Screen shape (rounded corners, sensor cut-out) as an alpha mask.
  final ui.Image? mask;

  /// Room around [body] for the side buttons (`devicePadding`).
  final EdgeInsets padding;

  /// Side buttons (volume, power, action…) drawn around [body].
  final List<AppleChromeInput> inputs;

  /// [body] plus [padding]: the whole drawn frame.
  Size get frame => padding.inflateSize(body);

  /// Corner radius of the screen opening: the outline's radius minus the
  /// thicker bezel side, as serve-sim does. Zero for square screens (e.g.
  /// home-button phones, whose top / bottom bezels are deep).
  double get screenRadius {
    final inset = max(body.width - screen.width, body.height - screen.height);
    return max(0, outerRadius - inset / 2);
  }

  /// Loads [udid]'s chrome over [channel]; null when Xcode has none.
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
      corner: Size(
        (map['cornerWidth'] as double?) ?? 0,
        (map['cornerHeight'] as double?) ?? 0,
      ),
      outerRadius: (map['outerRadius'] as double?) ?? 0,
      mask: mask,
      padding: switch (map['devicePadding']) {
        final Map<Object?, Object?> p => EdgeInsets.fromLTRB(
          p['left']! as double,
          p['top']! as double,
          p['right']! as double,
          p['bottom']! as double,
        ),
        _ => EdgeInsets.zero,
      },
      inputs: [
        for (final input in (map['inputs'] as List?) ?? const [])
          AppleChromeInput._fromMap((input as Map).cast<String, Object?>()),
      ],
    );
  }
}

/// A side button of an [AppleChrome] (`inputs` in chrome.json).
class AppleChromeInput {
  /// Creates a side button; offsets and [size] are in points.
  const AppleChromeInput({
    required this.name,
    required this.size,
    required this.image,
    this.imageDown,
    this.anchor = 'left',
    this.align = 'leading',
    this.normal = Offset.zero,
    this.rollover = Offset.zero,
    this.onTop = false,
  });

  factory AppleChromeInput._fromMap(Map<String, Object?> m) {
    Offset point(Object? p) => switch (p) {
      final Map<Object?, Object?> p => Offset(
        p['x']! as double,
        p['y']! as double,
      ),
      _ => Offset.zero,
    };
    return AppleChromeInput(
      name: m['name']! as String,
      size: Size(m['width']! as double, m['height']! as double),
      image: m['image']! as Uint8List,
      imageDown: m['imageDown'] as Uint8List?,
      anchor: m['anchor']! as String,
      align: m['align']! as String,
      normal: point(m['normal']),
      rollover: point(m['rollover']),
      onTop: m['onTop']! as bool,
    );
  }

  /// `volume-up`, `power`, `action`…
  final String name;
  final Size size;

  /// The button, and pressed, rendered at 3x.
  final Uint8List image;
  final Uint8List? imageDown;

  /// Body edge it sits on: `left`, `right`, `top` or `bottom`.
  final String anchor;

  /// `leading` or `trailing` along a top / bottom edge.
  final String align;
  final Offset normal;
  final Offset rollover;

  /// Drawn over the body instead of under it.
  final bool onTop;

  /// What pressing it sends; null for buttons without one (action, crown).
  DeviceButton? get button => switch (name) {
    'volume-up' => DeviceButton.volumeUp,
    'volume-down' => DeviceButton.volumeDown,
    'power' || 'sleep' => DeviceButton.lock,
    _ => null,
  };

  /// Where it sits in the frame (body at [padding]'s top-left), placed
  /// like serve-sim does from the anchor and the normal / rollover offsets.
  Rect rectIn(Size body, EdgeInsets padding) {
    final g = Offset(2 * normal.dx - rollover.dx, 2 * normal.dy - rollover.dy);
    final x = align == 'trailing'
        ? padding.left + body.width + g.dx - size.width
        : padding.left + g.dx;
    final origin = switch (anchor) {
      'right' => Offset(padding.left + body.width + g.dx, padding.top + g.dy),
      'top' => Offset(x, padding.top + g.dy - size.height),
      'bottom' => Offset(x, padding.top + body.height + g.dy),
      _ => Offset(
        padding.left + rollover.dx - size.width / 2,
        padding.top + rollover.dy,
      ),
    };
    return origin & size;
  }
}
