import 'package:simutil_core/src/models/device.dart';

/// An on-screen element from a device's accessibility tree, with its frame
/// normalized to 0..1 of the screen.
class UiElement {
  /// Creates an element; [left]..[bottom] are normalized to 0..1.
  const UiElement({
    required this.label,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.id = '',
    this.value = '',
    this.role = '',
  });

  /// Accessibility label (Android: content-desc, else text).
  final String label;

  /// Accessibility identifier (Android: resource-id).
  final String id;

  /// Current value (Android: text when content-desc is the label).
  final String value;

  /// Role or class name.
  final String role;

  /// Left edge, 0..1 of the screen width.
  final double left;

  /// Top edge, 0..1 of the screen height.
  final double top;

  /// Right edge, 0..1 of the screen width.
  final double right;

  /// Bottom edge, 0..1 of the screen height.
  final double bottom;

  /// Horizontal center, 0..1.
  double get centerX => (left + right) / 2;

  /// Vertical center, 0..1.
  double get centerY => (top + bottom) / 2;

  /// JSON with the center as `x` / `y` and empty fields left out.
  Map<String, Object?> toJson() => {
    'label': label,
    if (id.isNotEmpty) 'id': id,
    if (value.isNotEmpty) 'value': value,
    if (role.isNotEmpty) 'role': role,
    'x': _round(centerX),
    'y': _round(centerY),
    'frame': [
      for (final v in [left, top, right, bottom]) _round(v),
    ],
  };

  static double _round(double v) => (v * 1000).round() / 1000;
}

/// The element [query] names: exact (case-insensitive) matches on label,
/// id or value win over ones that only contain it. [index] picks among
/// several matches in tree order (negative counts from the end); null when
/// there is no such match.
UiElement? findElement(
  List<UiElement> elements,
  String query, {
  int index = 0,
}) {
  final q = query.trim().toLowerCase();
  bool hit(UiElement e, bool Function(String) test) =>
      [e.label, e.id, e.value].any((s) => test(s.toLowerCase()));
  var matches = [...elements.where((e) => hit(e, (s) => s == q))];
  if (matches.isEmpty) {
    matches = [...elements.where((e) => hit(e, (s) => s.contains(q)))];
  }
  final i = index < 0 ? matches.length + index : index;
  return i >= 0 && i < matches.length ? matches[i] : null;
}

/// Drives apps on a device beyond touch and buttons: launching, typing and
/// reading the accessibility tree.
abstract interface class DeviceAutomation {
  /// Launches app [appId] (Android package / iOS bundle id) on [device],
  /// stopping it first when it runs so it starts fresh; [clearState] also
  /// wipes its data first.
  Future<void> launch(Device device, String appId, {bool clearState = false});

  /// Types [text] into the focused field of [device].
  Future<void> typeText(Device device, String text);

  /// Visible elements of [device] that carry a label, id or value.
  Future<List<UiElement>> elements(Device device);
}
