import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

const String _ns = 'xmlns="http://www.w3.org/2000/svg"';

String brandSvg(TidyColors c) =>
    '<svg $_ns width="22" height="22" viewBox="0 0 22 22">'
    '<rect x="2" y="5" width="18" height="14" rx="4" fill="${hexOf(c.accent)}"/>'
    '<rect x="5" y="2" width="4" height="9" rx="2" fill="${hexOf(c.mint)}"/>'
    '<rect x="11" y="3" width="4" height="8" rx="2" fill="${hexOf(c.fg)}"/></svg>';

String soundOnSvg(Color c) =>
    '<svg $_ns width="20" height="20" viewBox="0 0 20 20">'
    '<path d="M3 8h3l4-3.5v11L6 12H3z" fill="${hexOf(c)}"/>'
    '<path d="M13 7.2a4 4 0 0 1 0 5.6M15.2 5a7 7 0 0 1 0 10" stroke="${hexOf(c)}" stroke-width="1.6" fill="none" stroke-linecap="round"/></svg>';

String soundOffSvg(Color c) =>
    '<svg $_ns width="20" height="20" viewBox="0 0 20 20">'
    '<path d="M3 8h3l4-3.5v11L6 12H3z" fill="${hexOf(c)}"/>'
    '<path d="M13 7.5l5 5M18 7.5l-5 5" stroke="${hexOf(c)}" stroke-width="1.6" stroke-linecap="round"/></svg>';

String gearSvg(Color c, Color hole) =>
    '<svg $_ns width="20" height="20" viewBox="0 0 20 20">'
    '<path d="M8.6 1.8h2.8l.5 2.3 1.4.8 2.2-.8 1.4 2.4-1.7 1.6v1.8l1.7 1.6-1.4 2.4-2.2-.8-1.4.8-.5 2.3H8.6l-.5-2.3-1.4-.8-2.2.8-1.4-2.4L4.8 10V8.2L3.1 6.6l1.4-2.4 2.2.8 1.4-.8z" fill="${hexOf(c)}"/>'
    '<circle cx="10" cy="9.1" r="2.6" fill="${hexOf(hole)}"/></svg>';

String homeSvg(Color c) =>
    '<svg $_ns width="20" height="20" viewBox="0 0 20 20">'
    '<path d="M3 9.5 10 3.5l7 6V17h-4.5v-4.5h-5V17H3z" fill="${hexOf(c)}"/></svg>';

String bulbSvg(Color c) =>
    '<svg $_ns width="16" height="16" viewBox="0 0 16 16">'
    '<path d="M8 1.5a4.5 4.5 0 0 0-2.6 8.2c.4.3.6.7.6 1.1V12h4v-1.2c0-.4.2-.8.6-1.1A4.5 4.5 0 0 0 8 1.5Z" fill="${hexOf(c)}"/>'
    '<rect x="6" y="13" width="4" height="1.6" rx=".8" fill="${hexOf(c)}"/></svg>';

String closeSvg(Color c) =>
    '<svg $_ns width="18" height="18" viewBox="0 0 18 18">'
    '<path d="M4 4l10 10M14 4 4 14" stroke="${hexOf(c)}" stroke-width="2" stroke-linecap="round"/></svg>';

String checkSvg(Color c, {double size = 16}) =>
    '<svg $_ns width="$size" height="$size" viewBox="0 0 16 16">'
    '<path d="M3.5 8.3l3 3 6-6.2" stroke="${hexOf(c)}" stroke-width="2.2" fill="none" stroke-linecap="round"/></svg>';

String weekCheckSvg(Color c) =>
    '<svg $_ns width="12" height="12" viewBox="0 0 12 12">'
    '<path d="M2.5 6.2l2.3 2.3 4.7-4.8" stroke="${hexOf(c)}" stroke-width="1.8" fill="none" stroke-linecap="round"/></svg>';

const String dailyBoxSvg =
    '<svg $_ns width="40" height="40" viewBox="0 0 40 40">'
    '<rect x="4" y="14" width="32" height="22" rx="4" fill="#E8A86E"/>'
    '<rect x="2" y="9" width="36" height="9" rx="3" fill="#F2B48C"/>'
    '<rect x="17" y="9" width="6" height="27" fill="#C9587C"/>'
    '<path d="M20 9c-3-6-11-6-9-1 1 2 6 2 9 1zm0 0c3-6 11-6 9-1-1 2-6 2-9 1z" fill="#E58FA6"/></svg>';

/// Separator between label parts; spaced so it never merges with a number.
String sepOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ' \u2013 ' : ' \u00B7 ';

/// Replaces Arabic-Indic and Persian digits with 0-9.
String westernDigits(String s) {
  final b = StringBuffer();
  for (final u in s.runes) {
    if (u >= 0x0660 && u <= 0x0669) {
      b.writeCharCode(0x30 + u - 0x0660);
    } else if (u >= 0x06F0 && u <= 0x06F9) {
      b.writeCharCode(0x30 + u - 0x06F0);
    } else {
      b.writeCharCode(u);
    }
  }
  return b.toString();
}

/// 48 px round icon button (top bar, home, close).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
    this.toggled,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    return Semantics(
      button: true,
      label: label,
      toggled: toggled,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: CircleBorder(side: BorderSide(color: c.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

enum PillKind { primary, secondary, accent, danger }

/// Pill-shaped text button (.primary / .secondary / .hintbtn / .small).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = PillKind.primary,
    this.small = false,
    this.icon,
    this.minWidth,
  });

  final String label;
  final VoidCallback? onTap;
  final PillKind kind;
  final bool small;
  final Widget? icon;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    Color bg;
    Color fg;
    Color? border;
    switch (kind) {
      case PillKind.primary:
        bg = c.fg;
        fg = c.bg;
        border = null;
      case PillKind.secondary:
        bg = Colors.transparent;
        fg = c.fg;
        border = c.line;
      case PillKind.accent:
        bg = c.accent;
        fg = c.accentInk;
        border = null;
      case PillKind.danger:
        bg = Colors.transparent;
        fg = c.danger;
        border = c.danger;
    }
    final double minH = 48;
    final double hPad = small
        ? 14
        : (kind == PillKind.accent ? 16 : (kind == PillKind.primary ? 24 : 20));
    final double fs = small ? 14 : (kind == PillKind.accent ? 15 : 16);
    final shape = StadiumBorder(
        side: border == null
            ? BorderSide.none
            : BorderSide(color: border, width: 1.5));
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: bg,
        clipBehavior: Clip.antiAlias,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: minH, minWidth: minWidth ?? 0),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    icon!,
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: tx(fs, w: 700, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fade + scale in with the overshoot curve of the HTML `pop` animation.
class PopIn extends StatelessWidget {
  const PopIn({
    super.key,
    required this.child,
    this.milliseconds = 350,
    this.from = 0.85,
  });

  final Widget child;
  final int milliseconds;
  final double from;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: milliseconds),
      curve: const Cubic(.2, 1.4, .4, 1),
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: from + (1 - from) * v, child: child),
      ),
    );
  }
}

/// Small muted centred line (.note).
class NoteText extends StatelessWidget {
  const NoteText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: tx(12.5, color: c.muted),
    );
  }
}

/// eyebrow + h1 pair used by both screens.
class TitleBlock extends StatelessWidget {
  const TitleBlock({super.key, required this.eyebrow, required this.title});
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final fs = (MediaQuery.sizeOf(context).width * 0.07).clamp(23.0, 32.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          upperFor(eyebrow, lang),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tx(12,
              w: 700,
              color: c.accent,
              letterSpacing: lang == 'ar' ? 0 : 12 * 0.08),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            style: tx(fs, w: 800, color: c.fg, height: 1.1),
          ),
        ),
      ],
    );
  }
}

Widget svgIcon(String svg, {double? size}) =>
    SvgPicture.string(svg, width: size, height: size);
