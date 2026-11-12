import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';
import 'package:tidy_nook/monet/billing.dart';

import 'controller.dart';
import 'privacy_page.dart';
import 'theme.dart';
import 'widgets.dart';

const String supportEmail = 'nilkaren.tuncay.demir@gmail.com';

/// The text shown for a purchase event, or null for none (cancelled).
String? purchaseMessage(AppLocalizations t, PurchaseEventKind kind) {
  switch (kind) {
    case PurchaseEventKind.success:
      return t.purchaseThanks;
    case PurchaseEventKind.pending:
      return t.purchasePending;
    case PurchaseEventKind.failed:
      return t.purchaseFailed;
    case PurchaseEventKind.restored:
      return t.purchasesRestored;
    case PurchaseEventKind.cancelled:
      return null;
  }
}

/// Settings bottom sheet. No ad is ever shown here.
Future<void> showSettingsSheet(
    BuildContext context, GameController controller) async {
  controller.settingsOpen = true;
  try {
    await _showSheet(context, controller);
  } finally {
    controller.settingsOpen = false;
  }
}

Future<void> _showSheet(BuildContext context, GameController controller) {
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
  final GlobalKey _confirmKey = GlobalKey();
  bool _copied = false;
  bool _reminderBusy = false;
  Timer? _copyTimer;
  Timer? _msgTimer;
  String? _shopMsg;
  StreamSubscription<PurchaseEvent>? _sub;

  @override
  void initState() {
    super.initState();
    try {
      _sub = widget.controller.services.billing.events.listen(_onPurchase);
    } catch (_) {}
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _msgTimer?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onPurchase(PurchaseEvent e) {
    if (!mounted) {
      return;
    }
    final msg = purchaseMessage(AppLocalizations.of(context), e.kind);
    if (msg == null) {
      return;
    }
    setState(() => _shopMsg = msg);
    _msgTimer?.cancel();
    _msgTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _shopMsg = null);
      }
    });
  }

  Future<void> _setReminder(bool on) async {
    if (_reminderBusy) {
      return;
    }
    final ctl = widget.controller;
    final p = ctl.progress;
    final t = AppLocalizations.of(context);
    _reminderBusy = true;
    p.setReminderAsked(true);
    try {
      if (on) {
        final ok = await ctl.services.reminder.requestAndEnable(
          title: t.notifTitle,
          body: t.notifBody,
          dailyDoneToday: p.dailyDoneToday(DateTime.now()),
          channelName: t.reminder,
        );
        p.setReminderOn(ok);
      } else {
        await ctl.services.reminder.disable();
        p.setReminderOn(false);
      }
    } catch (_) {
      // a notification problem never reaches the player
    } finally {
      _reminderBusy = false;
    }
  }

  void _buy(String id) {
    widget.controller.sounds.play('pick');
    unawaited(widget.controller.services.billing.buy(id));
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
    final billing = ctl.services.billing;
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
            row(Row(
              children: <Widget>[
                Expanded(child: label(t.vibration)),
                _SoundSwitch(
                  value: p.vibration,
                  label: t.vibration,
                  onChanged: () {
                    p.setVibration(!p.vibration);
                    ctl.services.haptics.tick();
                  },
                ),
              ],
            )),
            row(Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      label(t.reminder),
                      Text(t.reminderText, style: tx(13, color: c.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _SoundSwitch(
                  value: p.reminderOn,
                  label: t.reminder,
                  onChanged: () => unawaited(_setReminder(!p.reminderOn)),
                ),
              ],
            )),
            row(Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(t.shop, style: tx(18, w: 800, color: c.fg)),
                ),
                const SizedBox(height: 8),
                _ShopItem(
                  title: t.removeAds,
                  text: t.removeAdsText,
                  owned: p.noAds || billing.owns(Billing.removeAdsId),
                  price: billing.priceOf(Billing.removeAdsId),
                  onBuy: () => _buy(Billing.removeAdsId),
                ),
                const SizedBox(height: 10),
                _ShopItem(
                  title: t.supporterPack,
                  text: t.supporterText,
                  owned: p.supporter || billing.owns(Billing.supporterId),
                  price: billing.priceOf(Billing.supporterId),
                  onBuy: () => _buy(Billing.supporterId),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PillButton(
                    label: t.restorePurchases,
                    kind: PillKind.secondary,
                    small: true,
                    onTap: () {
                      ctl.sounds.play('pick');
                      unawaited(billing.restore());
                    },
                  ),
                ),
                if (_shopMsg != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _shopMsg!,
                      style: tx(14, w: 700, color: c.fg),
                    ),
                  ),
                ],
              ],
            )),
            AnimatedBuilder(
              animation: ctl.services.ads,
              builder: (context, _) {
                if (!ctl.services.ads.privacyOptionsRequired) {
                  return const SizedBox.shrink();
                }
                return row(_LinkRow(
                  text: t.privacyChoices,
                  onTap: () =>
                      unawaited(ctl.services.ads.showPrivacyOptions()),
                ));
              },
            ),
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
            row(_LinkRow(
              text: t.privacy,
              onTap: () => PrivacyPage.open(context, supportEmail),
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
                    onTap: () {
                      setState(() => _confirm = true);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final ctx = _confirmKey.currentContext;
                        if (ctx == null || !ctx.mounted) {
                          return;
                        }
                        Scrollable.ensureVisible(
                          ctx,
                          alignment: 1.0,
                          duration: MediaQuery.disableAnimationsOf(ctx)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                        );
                      });
                    },
                  )
                else
                  SizedBox(
                    key: _confirmKey,
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

/// A 48 dp row that opens something (privacy policy, privacy choices).
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(text, style: tx(15, w: 700, color: c.fg)),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: c.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One product of the shop: name, what it gives, and Buy / Owned.
class _ShopItem extends StatelessWidget {
  const _ShopItem({
    required this.title,
    required this.text,
    required this.owned,
    required this.price,
    required this.onBuy,
  });

  final String title;
  final String text;
  final bool owned;
  final String? price;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final pr = price;
    final Widget action = owned
        ? Semantics(
            label: '$title. ${t.owned}',
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(color: c.mint, shape: BoxShape.circle),
                    child: svgIcon(checkSvg(c.mintInk), size: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(t.owned, style: tx(14, w: 700, color: c.fg)),
                ],
              ),
            ),
          )
        : PillButton(
            label: pr != null && pr.isNotEmpty ? t.buyFor(pr) : t.buy,
            semanticLabel:
                '$title. ${pr != null && pr.isNotEmpty ? t.buyFor(pr) : t.buy}',
            small: true,
            onTap: onBuy,
          );
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: tx(15, w: 700, color: c.fg, height: 1.2)),
                const SizedBox(height: 2),
                Text(text, style: tx(13, color: c.muted, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }
}

class _MailText extends StatelessWidget {
  const _MailText();

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    // One line that shrinks instead of breaking in the middle of the address.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SelectionArea(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            supportEmail,
            maxLines: 1,
            softWrap: false,
            style: tx(14.5, color: c.fg),
          ),
        ),
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
        color: selected ? c.accent : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  text,
                  style: tx(13, w: 700, color: selected ? c.accentInk : c.muted),
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
        child: SizedBox(
          width: 62,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration:
                  reduce ? Duration.zero : const Duration(milliseconds: 200),
              width: 54,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: value ? c.mint : c.toggleOff,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: AlignmentDirectional(value ? 1 : -1, 0),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c.dark ? c.bg : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const <BoxShadow>[
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
        ),
      ),
    );
  }
}
