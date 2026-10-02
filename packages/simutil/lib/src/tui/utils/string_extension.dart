/// Small string helpers for TUI labels.
extension StringExtension on String {
  /// Uppercases the first character.
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
