import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tidy_nook/game/art.dart';
import 'package:tidy_nook/game/board_logic.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/l10n/gen/app_localizations.dart';

import 'effects.dart';
import 'sounds.dart';
import 'theme.dart';

const double _bw = 360;
const double _bh = 594;
const double _top = 40; // viewBox origin y

/// Lets the play screen ask the board for a hint.
class BoardController {
  VoidCallback? _hint;
  void hint() => _hint?.call();
}

class _Tw {
  _Tw(this.it, this.start, this.dur, this.done,
      {this.x, this.y, this.r, this.s})
      : fx = it.x,
        fy = it.y,
        fr = it.rotation,
        fs = it.scale;
  final ItemState it;
  final double start;
  final double dur;
  final VoidCallback? done;
  final double? x;
  final double? y;
  final double? r;
  final double? s;
  final double fx;
  final double fy;
  final double fr;
  final double fs;
}

/// The box with its lid, the ghosts, the loose items and the rug.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.level,
    required this.controller,
    required this.sounds,
    required this.onWin,
    required this.onCelebrate,
  });

  final Level level;
  final BoardController controller;
  final Sounds sounds;

  /// The last item was placed (record progress).
  final VoidCallback onWin;

  /// The lid is closed again: show the win card.
  final VoidCallback onCelebrate;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  final math.Random _rng = math.Random();
  final Stopwatch _sw = Stopwatch()..start();
  late final Ticker _ticker;

  late List<ItemState> _items;
  late List<SlotState> _slots;
  final List<int> _zFree = <int>[];
  final List<int> _placed = <int>[];

  final List<_Tw> _tweens = <_Tw>[];
  final List<SparkGroup> _sparks = <SparkGroup>[];
  final List<Timer> _timers = <Timer>[];

  // drag
  int _dragId = -1;
  int _dragPointer = -1;
  double _dx = 0;
  double _dy = 0;

  // lid
  bool _lidOpen = false;
  bool _lidText = true;
  double _lidY = 0;
  double _lidOp = 1;
  double _lidY0 = 0;
  double _lidO0 = 1;
  double _lidY1 = 0;
  double _lidO1 = 1;
  double _lidT0 = -1;

  // hint
  int _hintItem = -1;
  int _hintSlot = -1;
  double _hintStart = 0;

  bool _won = false;
  bool _reduce = false;

  // cached widgets
  final Map<String, Widget> _art = <String, Widget>{};
  final Map<String, Widget> _ghosts = <String, Widget>{};
  Widget? _bgWidget;
  String? _bgKey;
  Widget? _lidWidget;
  String? _lidKey;

  double get _now => _sw.elapsedMicroseconds / 1000.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _items = scatter(widget.level, _rng);
    _slots = makeSlots(widget.level);
    for (final it in _items) {
      _zFree.add(it.id);
    }
    widget.controller._hint = _hint;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    widget.controller._hint = null;
    for (final t in _timers) {
      t.cancel();
    }
    _ticker.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- timing

  void _ensureTicker() {
    if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _later(int ms, VoidCallback fn) {
    late Timer t;
    t = Timer(Duration(milliseconds: ms), () {
      _timers.remove(t);
      if (mounted) {
        fn();
      }
    });
    _timers.add(t);
  }

  void _tween(ItemState it, int ms,
      {double? x, double? y, double? r, double? s, VoidCallback? done}) {
    final dur = _reduce ? math.min(ms, 60).toDouble() : ms.toDouble();
    _tweens.removeWhere((t) => identical(t.it, it));
    _tweens.add(_Tw(it, _now, dur, done, x: x, y: y, r: r, s: s));
    _ensureTicker();
  }

  void _sparkle(double x, double y) {
    if (_reduce) {
      return;
    }
    _sparks.add(SparkGroup.create(_rng, Offset(x, y), _now));
    _ensureTicker();
  }

  void _onTick(Duration elapsed) {
    final now = _now;
    for (final tw in List<_Tw>.of(_tweens)) {
      final k = tw.dur <= 0 ? 1.0 : ((now - tw.start) / tw.dur).clamp(0.0, 1.0);
      final inv = 1 - k;
      final e = 1 - inv * inv * inv;
      final it = tw.it;
      if (tw.x != null) {
        it.x = tw.fx + (tw.x! - tw.fx) * e;
      }
      if (tw.y != null) {
        it.y = tw.fy + (tw.y! - tw.fy) * e;
      }
      if (tw.r != null) {
        it.rotation = tw.fr + (tw.r! - tw.fr) * e;
      }
      if (tw.s != null) {
        it.scale = tw.fs + (tw.s! - tw.fs) * e;
      }
      if (k >= 1) {
        _tweens.remove(tw);
        tw.done?.call();
      }
    }
    _sparks.removeWhere((g) => g.progress(now) >= 1 && now >= g.start);

    var lidBusy = false;
    if (_lidT0 >= 0) {
      final kt = ((now - _lidT0) / 500).clamp(0.0, 1.0);
      final ko = ((now - _lidT0) / 450).clamp(0.0, 1.0);
      final et = const Cubic(.5, 0, .3, 1).transform(kt);
      final eo = Curves.ease.transform(ko);
      _lidY = _lidY0 + (_lidY1 - _lidY0) * et;
      _lidOp = _lidO0 + (_lidO1 - _lidO0) * eo;
      if (kt >= 1 && ko >= 1) {
        _lidT0 = -1;
      } else {
        lidBusy = true;
      }
    }

    var hintBusy = false;
    if (_hintItem >= 0) {
      if (now - _hintStart >= 1600) {
        _hintItem = -1;
        _hintSlot = -1;
      } else {
        hintBusy = true;
      }
    }

    if (mounted) {
      setState(() {});
    }
    if (_tweens.isEmpty && _sparks.isEmpty && !lidBusy && !hintBusy) {
      _ticker.stop();
    }
  }

  // ------------------------------------------------------------------- lid

  void _setLid(bool open) {
    final y1 = open ? -330.0 : 0.0;
    final o1 = open ? 0.0 : 1.0;
    if (_reduce) {
      _lidY = y1;
      _lidOp = o1;
      _lidT0 = -1;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    _lidY0 = _lidY;
    _lidO0 = _lidOp;
    _lidY1 = y1;
    _lidO1 = o1;
    _lidT0 = _now;
    _ensureTicker();
  }

  void _openLid() {
    if (_lidOpen) {
      return;
    }
    _lidOpen = true;
    _setLid(true);
    widget.sounds.play('lid_open');
  }

  // ------------------------------------------------------------------ hint

  void _clearHint() {
    _hintItem = -1;
    _hintSlot = -1;
  }

  void _hint() {
    if (_won) {
      return;
    }
    _clearHint();
    _openLid();
    final h = pickHint(_items, _slots, _rng);
    if (h == null) {
      return;
    }
    setState(() {
      _hintItem = h.item.id;
      _hintSlot = h.slot.id;
      _hintStart = _now;
    });
    _ensureTicker();
    widget.sounds.play('hint');
  }

  double _ease(double k) => Curves.easeInOut.transform(k.clamp(0.0, 1.0));

  /// (angle in degrees, scale) of the hint wiggle at time [now].
  ({double angle, double scale}) _wiggle(double now) {
    final t = now - _hintStart;
    if (t >= 1500 || t < 0) {
      return (angle: 0.0, scale: 1.0);
    }
    final p = (t % 500) / 500;
    if (p < .25) {
      final u = _ease(p / .25);
      return (angle: -9 * u, scale: 1 + .1 * u);
    }
    if (p < .75) {
      final u = _ease((p - .25) / .5);
      return (angle: -9 + 18 * u, scale: 1.1);
    }
    final u = _ease((p - .75) / .25);
    return (angle: 9 * (1 - u), scale: 1.1 - .1 * u);
  }

  double _glow(double now) {
    final t = now - _hintStart;
    if (t >= 1500 || t < 0) {
      return 1;
    }
    final p = (t % 500) / 500;
    final u = p < .5 ? _ease(p / .5) : 1 - _ease((p - .5) / .5);
    return 1 - .75 * u;
  }

  // -------------------------------------------------------------- pointers

  bool _hit(ItemState it, double bx, double by) {
    final dx = bx - it.x;
    final dy = by - it.y;
    final a = -it.rotation * math.pi / 180;
    final cs = math.cos(a);
    final sn = math.sin(a);
    final lx = (dx * cs - dy * sn) / it.scale;
    final ly = (dx * sn + dy * cs) / it.scale;
    final fill = itemGeometryBox(it.kind);
    final px = math.max(6.0, (48 - fill.width) / 2);
    final py = math.max(6.0, (48 - fill.height) / 2);
    return Rect.fromLTRB(
            fill.left - px, fill.top - py, fill.right + px, fill.bottom + py)
        .contains(Offset(lx, ly));
  }

  void _down(PointerDownEvent e) {
    if (_won || _dragId >= 0) {
      return;
    }
    final bx = e.localPosition.dx;
    final by = e.localPosition.dy + _top;
    for (var n = _zFree.length - 1; n >= 0; n--) {
      final it = _items[_zFree[n]];
      if (it.placed || !_hit(it, bx, by)) {
        continue;
      }
      _clearHint();
      _openLid();
      _dragId = it.id;
      _dragPointer = e.pointer;
      _dx = bx - it.x;
      _dy = by - it.y;
      _tweens.removeWhere((t) => identical(t.it, it));
      _zFree.remove(it.id);
      _zFree.add(it.id);
      it.scale = 1.1;
      widget.sounds.play('pick');
      setState(() {});
      return;
    }
    if (!_lidOpen && bx >= 30 && bx <= 330 && by >= 60 && by <= 340) {
      _openLid();
    }
  }

  void _move(PointerMoveEvent e) {
    if (_dragId < 0 || e.pointer != _dragPointer) {
      return;
    }
    final it = _items[_dragId];
    it.x = e.localPosition.dx - _dx;
    it.y = e.localPosition.dy + _top - _dy;
    it.rotation += (0 - it.rotation) * .25;
    setState(() {});
  }

  void _up(PointerEvent e) {
    if (_dragId < 0 || e.pointer != _dragPointer) {
      return;
    }
    final it = _items[_dragId];
    _dragId = -1;
    _dragPointer = -1;
    final best = findSnap(_slots, it.kind, it.x, it.y);
    if (best != null) {
      best.filled = true;
      it.placed = true;
      _zFree.remove(it.id);
      _placed.add(it.id);
      _tween(it, 140,
          x: best.slot.x,
          y: best.slot.y,
          r: 0,
          s: 1.08,
          done: () => _tween(it, 160, s: 1));
      widget.sounds.play('place');
      _sparkle(best.slot.x, best.slot.y);
      if (_items.every((i) => i.placed)) {
        _later(480, _win);
      }
    } else if (isAboveRug(it.y)) {
      widget.sounds.play('miss');
      _tween(it, 260, x: it.home.dx, y: it.home.dy, s: 1);
    } else {
      final c = clampToRug(it.x, it.y);
      it.x = c.dx;
      it.y = c.dy;
      it.home = c;
      _tween(it, 120, s: 1);
    }
    setState(() {});
  }

  // ------------------------------------------------------------------- win

  void _win() {
    if (_won) {
      return;
    }
    _won = true;
    _clearHint();
    widget.onWin();
    setState(() {
      _lidText = false;
      _lidOpen = false;
    });
    _setLid(false);
    widget.sounds.play('lid_close');
    _later(_reduce ? 50 : 560, () {
      widget.sounds.play('win');
      const spots = <Offset>[
        Offset(110, 120),
        Offset(250, 120),
        Offset(180, 200),
        Offset(110, 290),
        Offset(250, 290),
      ];
      for (var i = 0; i < spots.length; i++) {
        final p = spots[i];
        _later(i * 90, () => _sparkle(p.dx, p.dy));
      }
      widget.onCelebrate();
    });
  }

  // ----------------------------------------------------------------- build

  Widget _artFor(String kind) {
    return _art.putIfAbsent(kind, () {
      final box = itemBox(kind);
      return SvgPicture.string(itemSvg(kind),
          width: box.width, height: box.height);
    });
  }

  Widget _ghostFor(String kind) {
    return _ghosts.putIfAbsent(kind, () {
      final box = itemBox(kind);
      return SvgPicture.string(ghostSvg(kind),
          width: box.width, height: box.height);
    });
  }

  Widget _itemLayer(ItemState it, double now) {
    final box = itemBox(it.kind);
    final lifted = it.id == _dragId;
    Widget art = _artFor(it.kind);
    if (it.id == _hintItem && !it.placed) {
      final w = _wiggle(now);
      art = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationZ(w.angle * math.pi / 180)
            .multiplied(Matrix4.diagonal3Values(w.scale, w.scale, 1)),
        child: art,
      );
    }
    final children = <Widget>[];
    if (!it.placed) {
      final sigma = lifted ? 3.5 : 0.75;
      final dy = lifted ? 8.0 : 2.0;
      final alpha = lifted ? .3 : .25;
      children.add(Transform.translate(
        offset: Offset(box.left, box.top + dy),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
                Color.fromRGBO(20, 12, 30, alpha), BlendMode.srcIn),
            child: _artFor(it.kind),
          ),
        ),
      ));
    }
    children.add(Transform.translate(
      offset: Offset(box.left, box.top),
      child: art,
    ));
    final m = Matrix4.translationValues(it.x, it.y - _top, 0)
        .multiplied(Matrix4.rotationZ(it.rotation * math.pi / 180))
        .multiplied(Matrix4.diagonal3Values(it.scale, it.scale, 1));
    return Positioned(
      left: 0,
      top: 0,
      child: Transform(
        transform: m,
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = TidyColors.of(context);
    final t = AppLocalizations.of(context);
    final now = _now;

    final bgKey = '${c.matCss}|${identityHashCode(widget.level)}';
    if (_bgKey != bgKey) {
      _bgKey = bgKey;
      _bgWidget = RepaintBoundary(
        child: SvgPicture.string(
          boardSvg(widget.level, matColor: c.matCss, stitchColor: c.stitchCss),
          width: _bw,
          height: _bh,
        ),
      );
    }
    final lidKey = '${_lidText ? t.tapOpen : ''}|$_lidText|${identityHashCode(widget.level)}';
    if (_lidKey != lidKey) {
      _lidKey = lidKey;
      _lidWidget = SvgPicture.string(
        lidSvg(widget.level, tapText: _lidText ? t.tapOpen : null),
        width: _bw,
        height: _bh,
      );
    }

    final glow = _hintSlot >= 0 ? _glow(now) : 1.0;
    final stack = <Widget>[
      Positioned(left: 0, top: 0, child: _bgWidget!),
      for (final s in _slots)
        Positioned(
          left: s.slot.x + itemBox(s.slot.kind).left,
          top: s.slot.y - _top + itemBox(s.slot.kind).top,
          child: Opacity(
            opacity: s.id == _hintSlot ? glow : 1.0,
            child: _ghostFor(s.slot.kind),
          ),
        ),
      for (final id in _placed) _itemLayer(_items[id], now),
      Positioned(
        left: 0,
        top: 0,
        child: Transform.translate(
          offset: Offset(0, _lidY),
          child: Opacity(
            opacity: _lidOp.clamp(0.0, 1.0),
            child: _lidWidget!,
          ),
        ),
      ),
      for (final id in _zFree) _itemLayer(_items[id], now),
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: SparkPainter(List<SparkGroup>.of(_sparks), now,
                origin: const Offset(0, _top)),
          ),
        ),
      ),
    ];

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _bw,
          height: _bh,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: Stack(children: stack),
          ),
        ),
      ),
    );
  }
}
