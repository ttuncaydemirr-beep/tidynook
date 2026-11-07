import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';
import 'package:tidy_nook/l10n/l10n_ext.dart';

import 'controller.dart';
import 'effects.dart';
import 'theme.dart';
import 'widgets.dart';

const double _hw = 340;
const double _hh = 574;
const Offset _hOrigin = Offset(10, -146);
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
  List<SparkGroup> _groups = <SparkGroup>[];
  bool _inited = false;
  String? _toast;
  Timer? _toastTimer;

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
    if ((ev.decor >= 0 || ev.pet >= 0) && !reduce) {
      final spots = <Offset>[];
      if (ev.decor >= 0) {
        spots.add(decorHitRect(ev.decor).center);
      }
      if (ev.pet >= 0) {
        spots.addAll(_petSpots(ev.pet));
      }
      _startBurst(spots);
      widget.controller.sounds.play('deco');
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
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _burst.dispose();
    super.dispose();
  }

  List<Offset> _petSpots(int pet) {
    switch (pet) {
      case 0:
        return <Offset>[Offset(rooms[0].x + 54, rooms[0].y + 125)];
      case 1:
        return <Offset>[Offset(rooms[1].x + 97, rooms[1].y + 76)];
      default:
        return const <Offset>[Offset(28, 410), Offset(332, 410)];
    }
  }

  void _startBurst(List<Offset> spots) {
    _groups = <SparkGroup>[
      for (final s in spots)
        SparkGroup.create(_rng, s, 250,
            duration: 700, count: 9, minDist: 16, maxDist: 34),
    ];
    _burst.forward(from: 0);
  }

  void _tapDecor(int i) {
    final ctl = widget.controller;
    final p = ctl.progress;
    p.setStyle(i, p.styleOf(i) == 0 ? 1 : 0);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!reduce) {
      ctl.sounds.play('deco');
      setState(() => _startBurst(<Offset>[decorHitRect(i).center]));
    }
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

    final svg = houseSvg(
      done: p.done,
      styles: p.styles,
      dailyTotal: p.daily.total,
      roomNames: t.roomNames,
      houseLine: c.houseLineCss,
    );

    final taps = <Widget>[];
    for (var ri = 0; ri < rooms.length; ri++) {
      for (final i in levelsOfRoom(ri)) {
        if (!p.done.contains(i)) {
          continue;
        }
        final r = decorHitRect(i).shift(-_hOrigin);
        taps.add(Positioned.fromRect(
          rect: r,
          child: Semantics(
            button: true,
            label: t.decorName(i),
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

    final houseStage = Semantics(
      label: t.hEye,
      container: true,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _hw,
          height: _hh,
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ExcludeSemantics(
                  child: SvgPicture.string(svg, width: _hw, height: _hh),
                ),
              ),
              ...taps,
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _burst,
                    builder: (context, _) => CustomPaint(
                      painter: SparkPainter(
                        _groups,
                        _burst.value * _burstMs,
                        origin: _hOrigin,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
        if (d > 0) ...<Widget>[
          _DailyCard(controller: ctl),
          const SizedBox(height: 6),
        ],
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: Center(child: houseStage)),
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
                                color: Color.fromRGBO(20, 12, 30, .18),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Text(
                            _toast!,
                            maxLines: 1,
                            style: tx(15, w: 800, color: c.mintInk),
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
        ? '${t.dailyDone}${st > 1 ? ' · ${t.streak(st)}' : ''}'
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

    return Semantics(
      button: true,
      enabled: !done,
      label: '${t.daily}. $sub',
      excludeSemantics: true,
      onTap: done ? null : _open,
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.line, width: 1.5),
        ),
        child: InkWell(
          onTap: done ? null : _open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: <Widget>[
                  SvgPicture.string(dailyBoxSvg, width: 40, height: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          t.daily,
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
                  pill,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open() {
    controller.sounds.play('pick');
    controller.startDaily();
  }
}
