import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/daily.dart';
import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';
import 'package:tidy_nook/l10n/l10n_ext.dart';

import 'controller.dart';
import 'theme.dart';
import 'widgets.dart';

/// The card that appears after a box is tidy (level: style picker, daily: reward + week).
class WinCard extends StatelessWidget {
  const WinCard({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final p = controller.progress;
    final daily = controller.isDaily;
    final i = controller.levelIndex;

    String title;
    String sub;
    String rewardName;
    String rewardNote;
    Widget picker;

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
      picker = Semantics(
        label: t.petName(shown),
        child: _PreviewTile(
          svg: petPreviewSvg(shown, locked: locked),
          selected: false,
          background: c.bg,
        ),
      );
    } else {
      title = t.winTitle(i % 3);
      sub = '${t.sub} · ${t.roomName(levelRoom[i])}';
      rewardName = t.decorName(i);
      rewardNote = t.style;
      final cur = p.styleOf(i);
      picker = Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var v = 0; v < 2; v++) ...<Widget>[
            if (v > 0) const SizedBox(width: 8),
            Semantics(
              button: true,
              selected: cur == v,
              label: t.styleN(v + 1),
              excludeSemantics: true,
              onTap: () => _pick(v),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pick(v),
                child: _PreviewTile(
                  svg: decorPreviewSvg(i, v),
                  selected: cur == v,
                  background: c.surface,
                ),
              ),
            ),
          ],
        ],
      );
    }

    final nx = p.nextOpen;
    return PopIn(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: c.line),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color.fromRGBO(20, 12, 30, .25),
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
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
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
                    ),
                  ),
                  const SizedBox(width: 10),
                  picker,
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
                  onTap: () {
                    controller.sounds.play('pick');
                    controller.goHouse();
                  },
                ),
                if (!daily && nx >= 0)
                  PillButton(
                    label: t.next,
                    onTap: () {
                      controller.sounds.play('pick');
                      controller.playNext();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _pick(int v) {
    controller.sounds.play('toggle');
    controller.setStyle(controller.levelIndex, v);
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.svg,
    required this.selected,
    required this.background,
  });

  final String svg;
  final bool selected;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    return Container(
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
        child: SvgPicture.string(svg, fit: BoxFit.cover),
      ),
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
