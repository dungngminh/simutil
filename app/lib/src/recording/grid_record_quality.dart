import 'dart:math';

/// Grid recording presets: frame rate, capture resolution and encoder
/// quality move together.
enum GridRecordQuality {
  low(label: 'Low', fps: 15, maxPixelRatio: 1, bitRateMbps: 3, crf: 28),
  standard(
    label: 'Standard',
    fps: 24,
    maxPixelRatio: 1.5,
    bitRateMbps: 8,
    crf: 23,
  ),
  high(label: 'High', fps: 30, maxPixelRatio: 3, bitRateMbps: 16, crf: 18);

  const GridRecordQuality({
    required this.label,
    required this.fps,
    required this.maxPixelRatio,
    required this.bitRateMbps,
    required this.crf,
  });

  final String label;

  /// Captured frames per second.
  final int fps;

  /// Capture scale over logical pixels, capped at the screen's own ratio.
  final double maxPixelRatio;

  /// Hardware encoder (VideoToolbox) bit rate.
  final int bitRateMbps;

  /// libx264 constant rate factor (lower = better).
  final int crf;

  /// Capture pixel ratio on a screen of [devicePixelRatio].
  double pixelRatio(double devicePixelRatio) =>
      min(maxPixelRatio, max(1, devicePixelRatio));

  /// One line for menus and tooltips, e.g. `Standard · 24 fps`.
  String get summary => '$label · $fps fps';
}
