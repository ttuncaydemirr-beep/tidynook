import 'package:flutter/material.dart';

/// Colour tokens. Visual identity "Butter & Sage" (owner-approved, 2026-11-12):
/// cream page, terracotta primary/accent, sage secondary, warm brown text.
/// Every text/background pair is measured for WCAG AA (see the C report).
class TidyColors extends ThemeExtension<TidyColors> {
  const TidyColors({
    required this.dark,
    required this.bg,
    required this.fg,
    required this.muted,
    required this.surface,
    required this.mat,
    required this.stitch,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.mint,
    required this.mintInk,
    required this.houseLine,
    required this.danger,
    required this.scrim,
    required this.toggleOff,
    required this.matCss,
    required this.stitchCss,
    required this.houseLineCss,
  });

  final bool dark;

  /// Page background.
  final Color bg;

  /// Main text.
  final Color fg;

  /// Secondary text (>= 4.5:1 on bg and surface).
  final Color muted;

  /// Cards and sheets.
  final Color surface;

  /// Rug under the loose items.
  final Color mat;
  final Color stitch;

  /// Decorative hairlines (never the only cue).
  final Color line;

  /// Terracotta: buttons, active dots, links, eyebrows.
  final Color accent;
  final Color accentInk;

  /// Sage: success, checks, toggles.
  final Color mint;
  final Color mintInk;
  final Color houseLine;
  final Color danger;
  final Color scrim;

  /// Track of a switch that is off (>= 3:1 on surface).
  final Color toggleOff;

  /// Strings handed to the SVG builders of the game layer.
  final String matCss;
  final String stitchCss;
  final String houseLineCss;

  static const TidyColors light = TidyColors(
    dark: false,
    bg: Color(0xFFFFF6E5),
    fg: Color(0xFF3B2A20),
    muted: Color(0xFF6B5547),
    surface: Color(0xFFFFFCF6),
    mat: Color(0xFFCDBB9F),
    stitch: Color.fromRGBO(255, 255, 255, .55),
    line: Color(0xFFEADBC4),
    accent: Color(0xFFB5452B),
    accentInk: Color(0xFFFFFFFF),
    mint: Color(0xFF2A8363),
    mintInk: Color(0xFFFFFFFF),
    houseLine: Color(0xFF3A2A20),
    danger: Color(0xFFA3302E),
    scrim: Color.fromRGBO(40, 25, 15, .45),
    toggleOff: Color(0xFF9A8676),
    matCss: '#CDBB9F',
    stitchCss: 'rgba(255,255,255,.55)',
    houseLineCss: '#3A2A20',
  );

  static const TidyColors night = TidyColors(
    dark: true,
    bg: Color(0xFF1E1712),
    fg: Color(0xFFF6EBDD),
    muted: Color(0xFFC2B09E),
    surface: Color(0xFF2A211B),
    mat: Color(0xFF4D4036),
    stitch: Color.fromRGBO(255, 255, 255, .22),
    line: Color(0xFF45372C),
    accent: Color(0xFFE8866A),
    accentInk: Color(0xFF2A120B),
    mint: Color(0xFF62C29E),
    mintInk: Color(0xFF0E2A1F),
    houseLine: Color(0xFF120D0A),
    danger: Color(0xFFF2958A),
    scrim: Color.fromRGBO(0, 0, 0, .6),
    toggleOff: Color(0xFF85735F),
    matCss: '#4D4036',
    stitchCss: 'rgba(255,255,255,.22)',
    houseLineCss: '#120D0A',
  );

  static TidyColors of(BuildContext context) =>
      Theme.of(context).extension<TidyColors>() ?? light;

  @override
  TidyColors copyWith() => this;

  @override
  TidyColors lerp(ThemeExtension<TidyColors>? other, double t) {
    if (other is! TidyColors) {
      return this;
    }
    return t < 0.5 ? this : other;
  }
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? TidyColors.night : TidyColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.accentInk,
    secondary: c.mint,
    onSecondary: c.mintInk,
    error: c.danger,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.fg,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: 'Baloo',
    splashFactory: InkRipple.splashFactory,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.fg,
      contentTextStyle: tx(15, w: 700, color: c.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    extensions: <ThemeExtension<dynamic>>[c],
  );
}

FontWeight _fontWeight(int w) {
  final i = ((w ~/ 100) - 1).clamp(0, 8);
  return FontWeight.values[i];
}

/// Text style in the Baloo variable font. `w` is the weight (500 regular, 700, 800).
TextStyle tx(
  double size, {
  int w = 500,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: 'Baloo',
    fontSize: size,
    fontWeight: _fontWeight(w),
    fontVariations: <FontVariation>[FontVariation('wght', w.toDouble())],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// `#rrggbb` for use inside SVG strings.
String hexOf(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

/// Upper-case for the small eyebrow labels. Turkish text is never
/// upper-cased (owner rule: no toUpperCase() on Turkish, the dotted and
/// dotless i break), and Arabic has no case: both are returned unchanged.
String upperFor(String s, String lang) {
  if (lang == 'tr' || lang == 'ar') {
    return s;
  }
  return s.toUpperCase();
}
