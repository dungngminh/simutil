import 'package:nocterm/nocterm.dart';

/// SimUtil Design System
///
/// Provides [SimutilTheme] — a theme-aware wrapper around [TuiThemeData]
/// that adds app-specific semantic styles, border decorations, and icons.
///
/// Usage:
/// ```dart
/// final simTheme = SimutilTheme.of(context);
/// Text('Hello', style: simTheme.label);
/// Container(decoration: simTheme.focusedPanel('Title'));
/// ```

/// Theme-aware design tokens for the SimUtil TUI app.
class SimutilTheme {
  final TuiThemeData _theme;

  const SimutilTheme._(this._theme);

  /// Resolve from a [BuildContext], reading the nearest [TuiTheme].
  static SimutilTheme of(BuildContext context) =>
      SimutilTheme._(TuiTheme.of(context));

  /// The underlying nocterm theme data.
  TuiThemeData get data => _theme;

  // ─── Semantic Colors ─────────────────────────────────────────────

  Color get primary => _theme.primary;
  Color get secondary => _theme.secondary;
  Color get surface => _theme.surface;
  Color get background => _theme.background;
  Color get error => _theme.error;
  Color get success => _theme.success;
  Color get warning => _theme.warning;
  Color get outline => _theme.outline;
  Color get outlineVariant => _theme.outlineVariant;
  Color get onSurface => _theme.onSurface;
  Color get onBackground => _theme.onBackground;

  // ─── Text Styles ─────────────────────────────────────────────────

  /// Normal body text.
  TextStyle get body => const TextStyle();

  /// Dimmed / secondary text.
  TextStyle get dimmed => const TextStyle(fontWeight: FontWeight.dim);

  /// Bold text.
  TextStyle get bold => const TextStyle(fontWeight: FontWeight.bold);

  /// Reverse-video (for selections).
  TextStyle get selected => const TextStyle(reverse: true);

  /// Primary-colored label.
  TextStyle get label => TextStyle(color: primary);

  /// Bold primary-colored section header.
  TextStyle get sectionHeader =>
      TextStyle(color: primary, fontWeight: FontWeight.bold);

  /// Success feedback text.
  TextStyle get successStyle => TextStyle(color: success);

  /// Warning text.
  TextStyle get warningStyle => TextStyle(color: warning);

  /// Error text.
  TextStyle get errorStyle => TextStyle(color: error);

  /// Muted / hint text.
  TextStyle get muted => TextStyle(color: outlineVariant);

  /// Status: device running.
  TextStyle get statusRunning => TextStyle(color: success);

  /// Status: device stopped.
  TextStyle get statusStopped =>
      TextStyle(color: outlineVariant, fontWeight: FontWeight.dim);

  // ─── Border Decorations ──────────────────────────────────────────

  /// Focused panel border.
  BoxDecoration focusedPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: primary),
    title: BorderTitle(text: ' $title '),
  );

  /// Unfocused panel border.
  BoxDecoration unfocusedPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: outline),
    title: BorderTitle(text: ' $title '),
  );

  /// Dialog panel border.
  BoxDecoration dialogPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: success),
    title: BorderTitle(text: ' $title '),
  );

  // ─── Theme name ↔ TuiThemeData mapping ──────────────────────────

  /// Map a settings theme name to a [TuiThemeData] preset.
  static TuiThemeData resolveTheme(String name) {
    return switch (name) {
      'light' => TuiThemeData.light,
      'nord' => TuiThemeData.nord,
      'dracula' => TuiThemeData.dracula,
      'catppuccin' => TuiThemeData.catppuccinMocha,
      'gruvbox' => TuiThemeData.gruvboxDark,
      _ => TuiThemeData.dark,
    };
  }
}
