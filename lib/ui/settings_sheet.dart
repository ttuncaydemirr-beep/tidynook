import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';

import 'controller.dart';
import 'theme.dart';
import 'widgets.dart';

const String supportEmail = 'nilkaren.tuncay.demir@gmail.com';

Future<void> showSettingsSheet(BuildContext context, GameController controller) {
  final c = TidyColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: c.surface,
    barrierColor: c.scrim,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: 520),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => ListenableBuilder(
      listenable: controller,
      builder: (ctx, _) => _SettingsBody(controller: controller),
    ),
  );
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody({required this.controller});

  final GameController controller;

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  bool _confirm = false;
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
    } catch (_) {
      // selecting the text by hand still works
    }
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final ctl = widget.controller;
    final p = ctl.progress;
    final current = Localizations.localeOf(context).languageCode;

    Widget row(Widget child) => Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: child,
        );

    Widget label(String s) => Text(s, style: tx(15, w: 700, color: c.fg));

    final langs = <MapEntry<String, String>>[
      const MapEntry<String, String>('tr', 'Türkçe'),
      const MapEntry<String, String>('en', 'English'),
      const MapEntry<String, String>('de', 'Deutsch'),
      const MapEntry<String, String>('ar', 'العربية'),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        t.settings,
                        style: tx(26, w: 800, color: c.fg),
                      ),
                    ),
                  ),
                  CircleIconButton(
                    label: t.close,
                    onTap: () => Navigator.of(context).maybePop(),
                    child: svgIcon(closeSvg(c.fg), size: 18),
                  ),
                ],
              ),
            ),
            row(Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: <Widget>[
                label(t.language),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.line),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Wrap(
                    children: <Widget>[
                      for (final l in langs)
                        _LangChip(
                          text: l.value,
                          selected: current == l.key,
                          onTap: () => ctl.setLang(l.key),
                        ),
                    ],
                  ),
                ),
              ],
            )),
            row(Row(
              children: <Widget>[
                Expanded(child: label(t.soundLbl)),
                _SoundSwitch(
                  value: p.sound,
                  label: t.soundLbl,
                  onChanged: ctl.toggleSound,
                ),
              ],
            )),
            row(Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                label(t.support),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: _MailText(),
                      ),
                      const SizedBox(width: 8),
                      PillButton(
                        label: _copied ? t.copied : t.copy,
                        kind: PillKind.secondary,
                        small: true,
                        onTap: _copy,
                      ),
                    ],
                  ),
                ),
              ],
            )),
            row(Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: <Widget>[
                label(t.reset),
                if (!_confirm)
                  PillButton(
                    label: t.resetBtn,
                    kind: PillKind.danger,
                    small: true,
                    onTap: () => setState(() => _confirm = true),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(t.resetQ, style: tx(14, color: c.muted)),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            PillButton(
                              label: t.cancel,
                              kind: PillKind.secondary,
                              small: true,
                              onTap: () => setState(() => _confirm = false),
                            ),
                            PillButton(
                              label: t.resetBtn,
                              small: true,
                              onTap: () {
                                Navigator.of(context).maybePop();
                                ctl.resetAll();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            )),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                t.ver,
                textAlign: TextAlign.center,
                style: tx(12, color: c.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailText extends StatelessWidget {
  const _MailText();

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SelectableText(
        supportEmail,
        textAlign: TextAlign.start,
        style: tx(14.5, color: c.fg),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: text,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? c.fg : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  text,
                  style: tx(13, w: 700, color: selected ? c.bg : c.muted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundSwitch extends StatelessWidget {
  const _SoundSwitch({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: onChanged,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 200),
          width: 54,
          height: 32,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? c.mint : c.line,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: AlignmentDirectional(value ? 1 : -1, 0),
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, .25),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
