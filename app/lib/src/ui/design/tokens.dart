import 'package:flutter/material.dart';

/// SimUtil's design tokens: one look on macOS, Windows and Linux.
@immutable
class SimuTokens extends ThemeExtension<SimuTokens> {
  const SimuTokens._({
    required this.page,
    required this.sidebar,
    required this.panel,
    required this.raised,
    required this.border,
    required this.hover,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.danger,
    required this.warning,
    required this.android,
    required this.apple,
  });

  static const dark = SimuTokens._(
    page: Color(0xFF0B0C0E),
    sidebar: Color(0xFF111215),
    panel: Color(0xFF17181B),
    raised: Color(0xFF202125),
    border: Color(0x17FFFFFF),
    hover: Color(0x0FFFFFFF),
    text: Color(0xFFF2F3F5),
    textMuted: Color(0x9EFFFFFF),
    textFaint: Color(0x66FFFFFF),
    accent: Color(0xFF2DD4BF),
    onAccent: Color(0xFF04201C),
    success: Color(0xFF34D399),
    danger: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    android: Color(0xFF3DDC84),
    apple: Color(0xFF9CC3FF),
  );

  static const light = SimuTokens._(
    page: Color(0xFFF4F5F7),
    sidebar: Color(0xFFECEDF0),
    panel: Color(0xFFFFFFFF),
    raised: Color(0xFFF0F1F3),
    border: Color(0x17000000),
    hover: Color(0x0D000000),
    text: Color(0xFF121316),
    textMuted: Color(0x99000000),
    textFaint: Color(0x66000000),
    accent: Color(0xFF0D9488),
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF059669),
    danger: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    android: Color(0xFF16A34A),
    apple: Color(0xFF2563EB),
  );

  final Color page;
  final Color sidebar;
  final Color panel;
  final Color raised;
  final Color border;
  final Color hover;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color danger;
  final Color warning;
  final Color android;
  final Color apple;

  static const radiusSmall = 6.0;
  static const radius = 8.0;
  static const radiusLarge = 12.0;
  static const motion = Duration(milliseconds: 140);

  static const _mono = 'Menlo';
  static const _monoFallback = ['Consolas', 'DejaVu Sans Mono', 'monospace'];

  static SimuTokens of(BuildContext context) =>
      Theme.of(context).extension<SimuTokens>()!;

  TextStyle get title => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: text,
    letterSpacing: -0.2,
  );

  TextStyle get label =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text);

  TextStyle get body => TextStyle(fontSize: 13, color: text, height: 1.35);

  TextStyle get caption => TextStyle(fontSize: 12, color: textMuted);

  TextStyle get overline => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: textFaint,
  );

  /// Status, counts and sizes.
  TextStyle get mono => TextStyle(
    fontFamily: _mono,
    fontFamilyFallback: _monoFallback,
    fontSize: 11.5,
    color: textMuted,
    height: 1,
  );

  @override
  SimuTokens copyWith() => this;

  @override
  SimuTokens lerp(SimuTokens? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Material is only the widget substrate; every visible surface comes from
/// [SimuTokens].
ThemeData simuTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark
      ? SimuTokens.dark
      : SimuTokens.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: tokens.accent,
        brightness: brightness,
      ).copyWith(
        primary: tokens.accent,
        onPrimary: tokens.onAccent,
        surface: tokens.panel,
        onSurface: tokens.text,
        error: tokens.danger,
      );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.page,
    canvasColor: tokens.page,
    dividerColor: tokens.border,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [tokens],
    textTheme: Typography.material2021(
      platform: TargetPlatform.macOS,
    ).englishLike.apply(bodyColor: tokens.text, displayColor: tokens.text),
    iconTheme: IconThemeData(color: tokens.textMuted, size: 16),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: tokens.accent),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      textStyle: TextStyle(fontSize: 12, color: tokens.text),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.raised,
        borderRadius: BorderRadius.circular(SimuTokens.radiusSmall),
        border: Border.all(color: tokens.border),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(tokens.textFaint),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.raised,
      contentTextStyle: tokens.body,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SimuTokens.radius),
        side: BorderSide(color: tokens.border),
      ),
    ),
  );
}
