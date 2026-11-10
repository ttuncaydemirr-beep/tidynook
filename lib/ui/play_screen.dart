import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';
import 'package:tidy_nook/l10n/l10n_ext.dart';

import 'board.dart';
import 'controller.dart';
import 'theme.dart';
import 'widgets.dart';
import 'win_card.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final BoardController _board = BoardController();
  bool _won = false;
  bool _card = false;

  GameController get _ctl => widget.controller;

  String _eyebrow(BuildContext context, AppLocalizations t) {
    if (_ctl.isDaily) {
      final locale = Localizations.localeOf(context).toString();
      final now = DateTime.now();
      String date;
      try {
        date = westernDigits(DateFormat.MMMMd(locale).format(now));
      } catch (_) {
        date = '${now.day}/${now.month}';
      }
      return '${t.daily}${sepOf(context)}$date';
    }
    final i = _ctl.levelIndex;
    return '${t.level} ${i + 1}/${levels.length}${sepOf(context)}${t.roomName(levelRoom[i])}';
  }

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final ctl = _ctl;
    final p = ctl.progress;
    final daily = ctl.isDaily;
    final i = ctl.levelIndex;
    final level = ctl.current!;
    final unlocked = p.unlocked;

    final title = daily ? t.dailyTheme(ctl.dailyTheme) : t.levelName(i);
    final note = !daily && i == 0 && !p.done.contains(0) ? t.tut : t.note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            CircleIconButton(
              label: t.home,
              onTap: () {
                ctl.sounds.play('pick');
                ctl.goHome();
              },
              child: svgIcon(homeSvg(c.fg), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TitleBlock(eyebrow: _eyebrow(context, t), title: title),
            ),
            const SizedBox(width: 10),
            PillButton(
              label: t.hint,
              kind: PillKind.accent,
              icon: svgIcon(bulbSvg(c.accentInk), size: 16),
              onTap: _won
                  ? null
                  : () {
                      _board.hint();
                    },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final cardWidth = math.min(330.0, box.maxWidth);
              return Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: BoardView(
                      level: level,
                      controller: _board,
                      sounds: ctl.sounds,
                      onWin: () {
                        ctl.recordWin();
                        setState(() => _won = true);
                      },
                      onCelebrate: () => setState(() => _card = true),
                    ),
                  ),
                  if (_card)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding:
                              EdgeInsets.only(bottom: box.maxHeight * 0.05),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              width: cardWidth,
                              child: WinCard(controller: ctl),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 0,
          runSpacing: 0,
          children: <Widget>[
            for (var n = 0; n < levels.length; n++)
              _Dot(
                number: n + 1,
                label: '${t.level} ${n + 1}',
                done: p.done.contains(n),
                current: n == i && !daily,
                enabled: n <= unlocked,
                onTap: () => ctl.buildLevel(n),
              ),
          ],
        ),
        const SizedBox(height: 4),
        NoteText(note),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.number,
    required this.label,
    required this.done,
    required this.current,
    required this.enabled,
    required this.onTap,
  });

  final int number;
  final String label;
  final bool done;
  final bool current;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final Color border = current ? c.accent : (done ? c.mint : c.line);
    final Color textColor =
        done ? c.mintInk : (current ? c.fg : c.muted);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: current,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : .35,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 48,
            height: 44,
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? c.mint : null,
                  border:
                      Border.all(color: border, width: current ? 3.5 : 1.5),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$number',
                    style: tx(12, w: 700, color: textColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
