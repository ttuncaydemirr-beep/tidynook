import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/daily.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';
import 'package:tidy_nook/l10n/l10n_ext.dart';
import 'package:tidy_nook/monet/ad_rules.dart' show kPlacementSurpriseBox;

import 'controller.dart';
import 'rewarded.dart';
import 'theme.dart';
import 'widgets.dart';

/// The card that appears after a box is tidy (level: style picker, daily:
/// reward + week, bonus: progress toward the next 3rd style).
class WinCard extends StatefulWidget {
  const WinCard({super.key, required this.controller});

  final GameController controller;

  @override
  State<WinCard> createState() => _WinCardState();
}

class _WinCardState extends State<WinCard> {
  bool _leaving = false;
  bool _offerBusy = false;

  GameController get controller => widget.controller;

  /// Next / See house. Double taps are ignored; there is never a spinner.
  Future<void> _leave({required bool next}) async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    controller.sounds.play('pick');
    try {
      await controller.leaveWin(next: next);
    } finally {
      if (mounted) {
        _leaving = false;
      }
    }
  }

  /// The optional "Surprise box": a rewarded ad unlocks the 3rd style.
  Future<void> _surprise(int level) async {
    if (_offerBusy) {
      return;
    }
    final t = AppLocalizations.of(context);
    final c = TidyColors.of(context);
    _offerBusy = true;
    bool ok;
    try {
      ok = await offerRewarded(
        context,
        controller.services,
        placement: kPlacementSurpriseBox,
        title: t.surpriseTitle,
        text: t.surpriseText,
        iconSvg: giftSvg(c.accent, c.mint),
      );
    } finally {
      _offerBusy = false;
    }
    if (!ok) {
      return;
    }
    final p = controller.progress;
    p.unlockExtraStyle(level);
    p.setStyle(level, 2);
    controller.sounds.play('deco');
    if (mounted) {
      showToast(context, t.surpriseGot);
    }
  }

  void _pick(int level, int v) {
    final p = controller.progress;
    if (!p.styleAvailable(level, v)) {
      unawaited(_surprise(level));
      return;
    }
    controller.sounds.play('toggle');
    controller.setStyle(level, v);
  }

  Widget _styleTile(BuildContext context, int level, int v, int cur) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final p = controller.progress;
    final available = p.styleAvailable(level, v);
    final label =
        available ? t.styleN(v + 1) : '${t.styleN(v + 1)}. ${t.surpriseTitle}';
    return Semantics(
      button: true,
      selected: cur == v,
      label: label,
      excludeSemantics: true,
      onTap: () => _pick(level, v),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(level, v),
        child: _PreviewTile(
          svg: decorPreviewSvg(level, v),
          selected: cur == v,
          background: c.surface,
          locked: !available,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final p = controller.progress;
    final daily = controller.isDaily;
    final bonus = controller.isBonus;
    final i = controller.levelIndex;

    String title;
    String sub;
    String rewardName;
    String rewardNote;
    Widget? sidePicker;
    Widget? belowPicker;
    var offerSurprise = false;

    if (daily) {
      final d = p.daily;
      final got = milestones.where((m) => d.total >= m).length;
      final fresh = controller.freshPet;
      final shown = fresh >= 0 ? fresh : math.min(got, milestones.length - 1);
      title = t.dailyWin;
      sub = t.streak(math.max(1, d.streak));
      rewardName = fresh >= 0
          ? t.newFriend(t.petName(fresh))
          : (got >= milestones.length
              ? t.allRewards
              : t.nextReward(t.petName(got), d.total, milestones[got]));
      rewardNote = t.dailyTotal(d.total);
      final locked = fresh < 0 && got < milestones.length;
      sidePicker = Semantics(
        label: t.petName(shown),
        child: _PreviewTile(
          svg: petPreviewSvg(shown, locked: locked),
          selected: false,
          background: c.bg,
        ),
      );
    } else if (bonus) {
      final n = controller.bonusIndex;
      final got = controller.freshBonusStyle;
      title = t.winTitle(n % 3);
      sub = t.bonusBoxN(n + 1);
      if (got >= 0) {
        rewardName = t.newStyleFor(t.decorName(got));
        rewardNote = t.surpriseGot;
        final cur = p.styleOf(got);
        sidePicker = Semantics(
          button: true,
          selected: cur == 2,
          label: '${t.decorName(got)}. ${t.styleN(3)}',
          excludeSemantics: true,
          onTap: () => _pick(got, 2),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _pick(got, 2),
            child: _PreviewTile(
              svg: decorPreviewSvg(got, 2),
              selected: cur == 2,
              background: c.surface,
            ),
          ),
        );
      } else {
        rewardName = t.bonusTitle;
        rewardNote = p.nextExtraStyleCandidate(0) == null
            ? t.allRewards
            : t.bonusProgress(p.bonusDone % bonusStyleEvery, bonusStyleEvery);
        sidePicker = ExcludeSemantics(
          child: Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.line, width: 2),
            ),
            child: SvgPicture.string(bonusBoxSvg, width: 40, height: 40),
          ),
        );
      }
    } else {
      title = t.winTitle(i % 3);
      sub = '${t.sub}${sepOf(context)}${t.roomName(levelRoom[i])}';
      rewardName = t.decorName(i);
      rewardNote = t.style;
      final cur = p.styleOf(i);
      offerSurprise = !p.styleAvailable(i, 2);
      belowPicker = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var v = 0; v < styleCount; v++) ...<Widget>[
            if (v > 0) const SizedBox(width: 8),
            _styleTile(context, i, v, cur),
          ],
        ],
      );
    }

    final nx = p.nextOpen;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          rewardName,
          style: tx(15, w: 700, color: c.fg, height: 1.2),
        ),
        Text(
          rewardNote,
          style: tx(13, color: c.muted),
        ),
      ],
    );

    return PopIn(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: c.line),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color.fromRGBO(40, 25, 15, .25),
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: tx(30, w: 800, color: c.fg, height: 1.1),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: tx(15, color: c.muted),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(0, 12, 0, 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: belowPicker != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        texts,
                        const SizedBox(height: 8),
                        Center(child: belowPicker),
                        if (offerSurprise) ...<Widget>[
                          const SizedBox(height: 8),
                          Center(
                            child: PillButton(
                              label: t.surpriseTitle,
                              kind: PillKind.secondary,
                              small: true,
                              icon: svgIcon(giftSvg(c.accent, c.mint),
                                  size: 18),
                              onTap: () => unawaited(_surprise(i)),
                            ),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(child: texts),
                        if (sidePicker != null) ...<Widget>[
                          const SizedBox(width: 10),
                          sidePicker,
                        ],
                      ],
                    ),
            ),
            if (daily) _WeekRow(progress: controller.progress),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                PillButton(
                  label: t.seeHouse,
                  kind: PillKind.secondary,
                  onTap: () => unawaited(_leave(next: false)),
                ),
                if (bonus)
                  PillButton(
                    label: t.bonusBoxN(p.bonusDone + 1),
                    onTap: () => unawaited(_leave(next: true)),
                  )
                else if (!daily && nx >= 0)
                  PillButton(
                    label: t.next,
                    onTap: () => unawaited(_leave(next: true)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.svg,
    required this.selected,
    required this.background,
    this.locked = false,
  });

  final String svg;
  final bool selected;
  final Color background;

  /// Not unlocked yet: dimmed, with a small lock (never colour alone).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final tile = Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? c.accent : c.line, width: 2),
        boxShadow: selected
            ? <BoxShadow>[BoxShadow(color: c.accent, spreadRadius: 2)]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Opacity(
          opacity: locked ? .45 : 1,
          child: SvgPicture.string(svg, fit: BoxFit.cover),
        ),
      ),
    );
    if (!locked) {
      return tile;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        tile,
        PositionedDirectional(
          end: -4,
          top: -4,
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.fg,
              shape: BoxShape.circle,
              border: Border.all(color: c.surface, width: 2),
            ),
            child: svgIcon(lockSvg(c.surface), size: 12),
          ),
        ),
      ],
    );
  }
}

class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.progress});

  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final days = progress.daily.days;
    final cells = <Widget>[];
    for (var k = 6; k >= 0; k--) {
      final dt = DateTime(now.year, now.month, now.day - k);
      final on = days.contains(dayString(dt));
      String label;
      try {
        label = DateFormat('EEEEE', locale).format(dt);
      } catch (_) {
        label = '';
      }
      cells.add(Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? c.mint : null,
              border: Border.all(color: on ? c.mint : c.line, width: 1.5),
              boxShadow: k == 0
                  ? <BoxShadow>[BoxShadow(color: c.accent, spreadRadius: 2)]
                  : null,
            ),
            child: on
                ? Center(child: svgIcon(weekCheckSvg(c.mintInk), size: 12))
                : null,
          ),
          const SizedBox(height: 2),
          Text(label, style: tx(11, w: 700, color: c.muted)),
        ],
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (var n = 0; n < cells.length; n++) ...<Widget>[
            if (n > 0) const SizedBox(width: 6),
            cells[n],
          ],
        ],
      ),
    );
  }
}
