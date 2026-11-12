import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';
import 'package:tidy_nook/l10n/l10n_ext.dart';
import 'package:tidy_nook/monet/ad_rules.dart' show kPlacementStreakSave;

import 'controller.dart';
import 'effects.dart';
import 'rewarded.dart';
import 'theme.dart';
import 'widgets.dart';

const double _burstMs = 950;

class HouseScreen extends StatefulWidget {
  const HouseScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;
  late final HouseEvents _events;
  final math.Random _rng = math.Random();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _focusKey = GlobalKey();
  List<SparkGroup> _groups = <SparkGroup>[];
  bool _inited = false;
  String? _toast;
  Timer? _toastTimer;
  Timer? _askTimer;

  /// House-space area to scroll to when the screen opens (the newest piece).
  Rect? _focus;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _events = widget.controller.takeHouseEvents();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) {
      return;
    }
    _inited = true;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final t = AppLocalizations.of(context);
    final ev = _events;
    final spots = <Offset>[];
    if (ev.decor >= 0) {
      spots.add(decorHitRect(ev.decor).center);
      _focus = decorHitRect(ev.decor);
    }
    if (ev.pet >= 0) {
      final ps = petSpots(ev.pet);
      spots.addAll(ps);
      if (_focus == null && ps.isNotEmpty) {
        _focus = Rect.fromCenter(center: ps.first, width: 60, height: 60);
      }
    }
    if (spots.isNotEmpty && !reduce) {
      _startBurst(spots);
      widget.controller.sounds.play('deco');
    }
    if (_focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToFocus());
    }
    if (ev.toastRoom >= 0) {
      _toast = t.roomDone(t.roomName(ev.toastRoom));
      widget.controller.sounds.play('room');
      _toastTimer = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) {
          setState(() => _toast = null);
        }
      });
    }
    if (ev.askReminder) {
      _askTimer = Timer(const Duration(milliseconds: 900), () {
        unawaited(_askReminder());
      });
    }
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _askTimer?.cancel();
    _scroll.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _scrollToFocus() {
    if (!mounted) {
      return;
    }
    final ctx = _focusKey.currentContext;
    if (ctx == null) {
      return;
    }
    final reduce = MediaQuery.disableAnimationsOf(context);
    unawaited(Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: reduce ? Duration.zero : const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    ));
  }

  /// Asked once, after the first daily box win.
  Future<void> _askReminder() async {
    if (!mounted) {
      return;
    }
    final ctl = widget.controller;
    final p = ctl.progress;
    if (p.reminderAsked) {
      return;
    }
    final t = AppLocalizations.of(context);
    p.setReminderAsked(true);
    final yes = await askChoice(
      context,
      text: t.reminderAsk,
      yes: t.reminderYes,
      no: t.noThanks,
      iconSvg: dailyBoxSvg,
    );
    if (!yes) {
      return;
    }
    var ok = false;
    try {
      ok = await ctl.services.reminder.requestAndEnable(
        title: t.notifTitle,
        body: t.notifBody,
        dailyDoneToday: true,
        channelName: t.reminder,
      );
    } catch (_) {
      ok = false;
    }
    p.setReminderOn(ok);
  }

  void _startBurst(List<Offset> spots) {
    _groups = <SparkGroup>[
      for (final s in spots)
        SparkGroup.create(_rng, s, 250,
            duration: 700, count: 9, minDist: 16, maxDist: 34),
    ];
    _burst.forward(from: 0);
  }

  /// Tapping furniture cycles through its available styles.
  void _tapDecor(int i) {
    final ctl = widget.controller;
    ctl.progress.setStyle(i, ctl.nextStyle(i));
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!reduce) {
      ctl.sounds.play('deco');
      setState(() => _startBurst(<Offset>[decorHitRect(i).center]));
    } else {
      ctl.sounds.play('toggle');
    }
  }

  Widget _roomLabel(int ri, AppLocalizations t, Set<int> done) {
    final lv = levelsOfRoom(ri);
    final n = lv.where(done.contains).length;
    final center = roomLabelCenter(ri) - houseOrigin;
    return Positioned(
      left: center.dx - 70,
      top: center.dy - 10,
      width: 140,
      height: 20,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                  // >= 4.5:1 for the white text even over a white wall
                  color: const Color.fromRGBO(0, 0, 0, .62),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${t.roomName(ri)}${sepOf(context)}$n/${lv.length}',
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: tx(roomLabelFontSize, w: 700, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final ctl = widget.controller;
    final p = ctl.progress;
    final n = levels.length;
    final d = p.done.length;
    final nx = p.nextOpen;
    final hw = houseSize.width;
    final hh = houseSize.height;

    final svg = houseSvg(
      done: p.done,
      styles: <int, int>{for (final i in p.done) i: p.styleOf(i)},
      dailyTotal: p.daily.total,
      roomNames: t.roomNames,
      houseLine: c.houseLineCss,
      puppy: p.supporter,
      extended: true,
    );

    final taps = <Widget>[];
    for (var ri = 0; ri < rooms.length; ri++) {
      for (final i in levelsOfRoom(ri)) {
        if (!p.done.contains(i)) {
          continue;
        }
        final r = decorHitRect(i).shift(-houseOrigin);
        taps.add(Positioned.fromRect(
          rect: r,
          child: Semantics(
            button: true,
            label: '${t.decorName(i)}. ${t.styleN(p.styleOf(i) + 1)}',
            excludeSemantics: true,
            onTap: () => _tapDecor(i),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _tapDecor(i),
              child: const SizedBox.expand(),
            ),
          ),
        ));
      }
    }

    final focus = _focus;
    final houseStage = Semantics(
      label: t.hEye,
      container: true,
      child: AspectRatio(
        aspectRatio: hw / hh,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: hw,
            height: hh,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: SvgPicture.string(svg, width: hw, height: hh),
                  ),
                ),
                if (focus != null)
                  Positioned.fromRect(
                    rect: focus.shift(-houseOrigin),
                    child: IgnorePointer(child: SizedBox(key: _focusKey)),
                  ),
                ...taps,
                for (var ri = 0; ri < rooms.length; ri++)
                  _roomLabel(ri, t, p.done),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _burst,
                      builder: (context, _) => CustomPaint(
                        painter: SparkPainter(
                          _groups,
                          _burst.value * _burstMs,
                          origin: houseOrigin,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final scroll = SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (d > 0) ...<Widget>[
            _DailyCard(controller: ctl),
            _StreakSave(controller: ctl),
            const SizedBox(height: 6),
            _BonusCard(controller: ctl),
            const SizedBox(height: 8),
          ],
          houseStage,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TitleBlock(
          eyebrow: t.hEye,
          title: d >= n ? t.hAll : t.hTitle(d, n),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: scroll),
              if (_toast != null)
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: PopIn(
                        milliseconds: 400,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.mint,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color.fromRGBO(40, 25, 15, .18),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              svgIcon(checkSvg(c.mintInk), size: 16),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _toast!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tx(15, w: 800, color: c.mintInk),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: PillButton(
            label: nx < 0 ? t.again : t.cont(nx + 1),
            minWidth: 220,
            onTap: () {
              ctl.sounds.play('pick');
              ctl.playNext();
            },
          ),
        ),
        if (d > 0) ...<Widget>[
          const SizedBox(height: 6),
          NoteText(t.houseTip),
        ],
      ],
    );
  }
}

/// Card frame shared by the daily box and the bonus boxes.
class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.semanticsLabel,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.sub,
    required this.trailing,
  });

  final String semanticsLabel;
  final VoidCallback? onTap;
  final Widget icon;
  final String title;
  final String sub;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.line, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: <Widget>[
                  icon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: tx(16, w: 700, color: c.fg, height: 1.2),
                        ),
                        Text(
                          sub,
                          style: tx(13, color: c.muted, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final p = controller.progress;
    final now = DateTime.now();
    final done = p.dailyDoneToday(now);
    final st = p.liveStreak(now);
    final sub = done
        ? '${t.dailyDone}${st > 1 ? '${sepOf(context)}${t.streak(st)}' : ''}'
        : (st > 0 ? t.streak(st) : t.dailyReady);

    final pill = Container(
      padding: EdgeInsets.symmetric(horizontal: done ? 10 : 16, vertical: 6),
      decoration: BoxDecoration(
        color: done ? c.mint : c.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: done
          ? svgIcon(checkSvg(c.mintInk), size: 16)
          : Text(t.open, style: tx(14, w: 700, color: c.accentInk)),
    );

    return _CardFrame(
      semanticsLabel: '${t.daily}. $sub',
      onTap: done ? null : _open,
      icon: SvgPicture.string(dailyBoxSvg, width: 40, height: 40),
      title: t.daily,
      sub: sub,
      trailing: pill,
    );
  }

  void _open() {
    controller.sounds.play('pick');
    controller.startDaily();
  }
}

/// "Keep your streak": only when exactly one day was missed (rewarded, optional).
class _StreakSave extends StatefulWidget {
  const _StreakSave({required this.controller});

  final GameController controller;

  @override
  State<_StreakSave> createState() => _StreakSaveState();
}

class _StreakSaveState extends State<_StreakSave> {
  bool _busy = false;

  Future<void> _offer() async {
    final ctl = widget.controller;
    final p = ctl.progress;
    final n = p.streakAtRisk(DateTime.now());
    if (_busy || n <= 0) {
      return;
    }
    final t = AppLocalizations.of(context);
    final c = TidyColors.of(context);
    ctl.sounds.play('pick');
    _busy = true;
    bool ok;
    try {
      ok = await offerRewarded(
        context,
        ctl.services,
        placement: kPlacementStreakSave,
        title: t.streakSaveTitle,
        text: t.streakSaveText(n),
        iconSvg: flameSvg(c.accent),
      );
    } finally {
      _busy = false;
    }
    if (!ok) {
      return;
    }
    if (p.saveStreak(DateTime.now()) && mounted) {
      showToast(context, t.streakSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final p = widget.controller.progress;
    final now = DateTime.now();
    final n = p.dailyDoneToday(now) ? 0 : p.streakAtRisk(now);
    if (n <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: PillButton(
          label: '${t.streakSaveTitle}${sepOf(context)}${t.streak(n)}',
          kind: PillKind.secondary,
          small: true,
          icon: svgIcon(flameSvg(c.accent), size: 16),
          onTap: () => unawaited(_offer()),
        ),
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  const _BonusCard({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final p = controller.progress;
    final unlocked = p.bonusUnlocked;
    final icon = Opacity(
      opacity: unlocked ? 1 : .5,
      child: SvgPicture.string(bonusBoxSvg, width: 40, height: 40),
    );
    if (!unlocked) {
      return _CardFrame(
        semanticsLabel: '${t.bonusTitle}. ${t.bonusLocked}',
        onTap: null,
        icon: icon,
        title: t.bonusTitle,
        sub: t.bonusLocked,
        trailing: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.bg,
            shape: BoxShape.circle,
            border: Border.all(color: c.toggleOff, width: 1.5),
          ),
          child: svgIcon(lockSvg(c.muted), size: 16),
        ),
      );
    }
    final hasCandidate = p.nextExtraStyleCandidate(0) != null;
    final sub = hasCandidate
        ? t.bonusProgress(p.bonusDone % bonusStyleEvery, bonusStyleEvery)
        : t.bonusTitle;
    final title = t.bonusBoxN(p.bonusDone + 1);
    return _CardFrame(
      semanticsLabel: '$title. $sub. ${t.bonusPlay}',
      onTap: _play,
      icon: icon,
      title: title,
      sub: sub,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(t.bonusPlay, style: tx(14, w: 700, color: c.accentInk)),
      ),
    );
  }

  void _play() {
    controller.sounds.play('pick');
    controller.startBonus();
  }
}
