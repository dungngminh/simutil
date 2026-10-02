import 'package:nocterm/nocterm.dart';

/// Semantic colors and text styles for SimUtil TUI widgets.
class SimutilTheme {
  const SimutilTheme._(this._theme);
  final TuiThemeData _theme;

  /// Resolves [SimutilTheme] from a [BuildContext].
  static SimutilTheme of(BuildContext context) =>
      SimutilTheme._(TuiTheme.of(context));

  /// Underlying Nocterm theme data.
  TuiThemeData get data => _theme;

  /// Primary accent color.
  Color get primary => _theme.primary;

  /// Secondary accent color.
  Color get secondary => _theme.secondary;

  /// Panel and card background color.
  Color get surface => _theme.surface;

  /// App background color.
  Color get background => _theme.background;

  /// Error and destructive accent color.
  Color get error => _theme.error;

  /// Success accent color.
  Color get success => _theme.success;

  /// Warning accent color.
  Color get warning => _theme.warning;

  /// Border and divider color.
  Color get outline => _theme.outline;

  /// Subtle border variant color.
  Color get outlineVariant => _theme.outlineVariant;

  /// Text color on [surface].
  Color get onSurface => _theme.onSurface;

  /// Text color on [background].
  Color get onBackground => _theme.onBackground;

  /// Default body text style.
  TextStyle get body => const TextStyle(color: Color.defaultColor);

  /// Dimmed secondary text style.
  TextStyle get dimmed =>
      const TextStyle(fontWeight: FontWeight.dim, color: Color.defaultColor);

  /// Bold body text style.
  TextStyle get bold =>
      const TextStyle(fontWeight: FontWeight.bold, color: Color.defaultColor);

  /// Reverse-video style for selected rows.
  TextStyle get selected =>
      const TextStyle(reverse: true, color: Color.defaultColor);

  /// Label text style using [primary].
  TextStyle get label => TextStyle(color: primary);

  /// Section heading style.
  TextStyle get sectionHeader =>
      TextStyle(color: primary, fontWeight: FontWeight.bold);

  /// Success message text style.
  TextStyle get successStyle => TextStyle(color: success);

  /// Warning message text style.
  TextStyle get warningStyle => TextStyle(color: warning);

  /// Error message text style.
  TextStyle get errorStyle => TextStyle(color: error);

  /// De-emphasized placeholder text style.
  TextStyle get muted => TextStyle(color: outline);

  /// Style for running device status.
  TextStyle get statusRunning => TextStyle(color: success);

  /// Style for stopped device status.
  TextStyle get statusStopped =>
      TextStyle(color: outline, fontWeight: FontWeight.dim);

  /// Rounded panel decoration for the focused panel.
  BoxDecoration focusedPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: primary),
    title: BorderTitle(text: title),
    color: Color.defaultColor,
  );

  /// Rounded panel decoration for an unfocused panel.
  BoxDecoration unfocusedPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: outline),
    title: BorderTitle(text: title),
    color: Color.defaultColor,
  );

  /// Rounded dialog panel decoration.
  BoxDecoration dialogPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: primary),
    title: BorderTitle(text: title),
    color: Color.defaultColor,
  );

  /// Success-styled dialog panel decoration.
  BoxDecoration successDialogPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: success),
    title: BorderTitle(text: title),
    color: Color.defaultColor,
  );

  /// Error-styled dialog panel decoration.
  BoxDecoration errorDialogPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: error),
    title: BorderTitle(text: title),
    color: Color.defaultColor,
  );

  /// Maps a theme name to a [TuiThemeData] preset.
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

/// Convenience accessor for [SimutilTheme] on [BuildContext].
extension SimutilThemeExtension on BuildContext {
  /// Active SimUtil theme for this build context.
  SimutilTheme get simutilTheme => SimutilTheme.of(this);
}
