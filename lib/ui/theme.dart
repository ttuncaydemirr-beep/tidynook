import 'package:flutter/material.dart';

/// Colour tokens copied from the CSS custom properties of the HTML game.
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
    required this.matCss,
    required this.stitchCss,
    required this.houseLineCss,
  });

  final bool dark;
  final Color bg;
  final Color fg;
  final Color muted;
  final Color surface;
  final Color mat;
  final Color stitch;
  final Color line;
  final Color accent;
  final Color accentInk;
  final Color mint;
  final Color mintInk;
  final Color houseLine;
  final Color danger;
  final Color scrim;

  /// Strings handed to the SVG builders of the game layer.
  final String matCss;
  final String stitchCss;
  final String houseLineCss;

  static const TidyColors light = TidyColors(
    dark: false,
    bg: Color(0xFFF4EFF7),
    fg: Color(0xFF352D40),
    muted: Color(0xFF6B6178),
    surface: Color(0xFFFFFFFF),
    mat: Color(0xFFB3A5C6),
    stitch: Color.fromRGBO(255, 255, 255, .55),
    line: Color(0xFFDCD2E5),
    accent: Color(0xFFA8456A),
    accentInk: Color(0xFFFFFFFF),
    mint: Color(0xFF7FC4AA),
    mintInk: Color(0xFF173A2E),
    houseLine: Color(0xFF3A3046),
    danger: Color(0xFFB23A55),
    scrim: Color.fromRGBO(30, 20, 40, .45),
    matCss: '#B3A5C6',
    stitchCss: 'rgba(255,255,255,.55)',
    houseLineCss: '#3A3046',
  );

  static const TidyColors night = TidyColors(
    dark: true,
    bg: Color(0xFF1F1A26),
    fg: Color(0xFFF1EAF6),
    muted: Color(0xFFA89DB4),
    surface: Color(0xFF2B2433),
    mat: Color(0xFF4A3F58),
    stitch: Color.fromRGBO(255, 255, 255, .22),
    line: Color(0xFF3C3447),
    accent: Color(0xFFEC8FAD),
    accentInk: Color(0xFF2A1720),
    mint: Color(0xFF86CDB3),
    mintInk: Color(0xFF123026),
    houseLine: Color(0xFF0F0C14),
    danger: Color(0xFFF08AA0),
    scrim: Color.fromRGBO(0, 0, 0, .6),
    matCss: '#4A3F58',
    stitchCss: 'rgba(255,255,255,.22)',
    houseLineCss: '#0F0C14',
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

/// Upper-case like CSS text-transform does for the given language.
String upperFor(String s, String lang) {
  if (lang == 'tr') {
    return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }
  return s.toUpperCase();
}
