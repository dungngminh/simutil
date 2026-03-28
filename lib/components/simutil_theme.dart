import 'package:nocterm/nocterm.dart';

class SimutilTheme {
  const SimutilTheme._(this._theme);
  final TuiThemeData _theme;

  static SimutilTheme of(BuildContext context) =>
      SimutilTheme._(TuiTheme.of(context));

  TuiThemeData get data => _theme;

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

  TextStyle get body => const TextStyle();

  TextStyle get dimmed => const TextStyle(fontWeight: FontWeight.dim);

  TextStyle get bold => const TextStyle(fontWeight: FontWeight.bold);

  TextStyle get selected => const TextStyle(reverse: true);

  TextStyle get label => TextStyle(color: primary);

  TextStyle get sectionHeader =>
      TextStyle(color: primary, fontWeight: FontWeight.bold);

  TextStyle get successStyle => TextStyle(color: success);

  TextStyle get warningStyle => TextStyle(color: warning);

  TextStyle get errorStyle => TextStyle(color: error);

  TextStyle get muted => TextStyle(color: outline);

  TextStyle get statusRunning => TextStyle(color: success);

  TextStyle get statusStopped =>
      TextStyle(color: outline, fontWeight: FontWeight.dim);

  BoxDecoration focusedPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: primary),
    title: BorderTitle(text: title),
    color: Color.defaultColor
  );

  BoxDecoration unfocusedPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: outline),
    title: BorderTitle(text: title),
    color: Color.defaultColor
  );

  BoxDecoration dialogPanel(String title) => BoxDecoration(
    border: BoxBorder.all(style: BoxBorderStyle.rounded, color: primary),
    title: BorderTitle(text: title),
    color: Color.defaultColor
  );

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

extension SimutilThemeExtension on BuildContext {
  SimutilTheme get simutilTheme => SimutilTheme.of(this);
}
