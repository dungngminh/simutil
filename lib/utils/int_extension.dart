extension IntExtension on int {
  /// Formats this value as a short human-readable byte size (e.g. `3.9G`, `512K`).
  ///
  /// Negative values are treated as `0`.
  String get formatBytes {
    var bytes = this;
    if (bytes < 0) bytes = 0;
    const units = ['B', 'K', 'M', 'G', 'T'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    if (unitIndex == 0) return '${value.round()}B';
    final fixed = value >= 10
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$fixed${units[unitIndex]}';
  }
}
