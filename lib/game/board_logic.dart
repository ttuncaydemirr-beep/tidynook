// Board rules: the first scatter of the items on the rug, snapping, hints and
// the drop rules. Ported from build(), drop() and the hint button of the
// shipped HTML game (web-preview/index.html).

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'art.dart';
import 'content.dart';

/// A movable item on the board (board space is the 360 x 594 box, viewBox
/// "0 40 360 594"). x/y is the item centre, rotation is in degrees.
class ItemState {
  final int id;
  final String kind;
  double x;
  double y;
  double rotation;
  double scale;
  bool placed;

  /// Where the item rests on the rug; a wrong drop above the rug springs back here.
  Offset home;

  ItemState({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.rotation = 0,
    this.scale = 1,
    this.placed = false,
    required this.home,
  });
}

/// One slot of the running level.
class SlotState {
  final int id;
  final Slot slot;
  bool filled;
  SlotState({required this.id, required this.slot, this.filled = false});
}

/// Fresh slot states for [level] (ids 0..n-1 in slot order).
List<SlotState> makeSlots(Level level) {
  return <SlotState>[
    for (var i = 0; i < level.slots.length; i++)
      SlotState(id: i, slot: level.slots[i]),
  ];
}

double _rnd(math.Random random, double a, double b) {
  return a + random.nextDouble() * (b - a);
}

/// Initial scatter of a level's items on the rug: same grid / jitter / rotation
/// rules as build() in the HTML. Item i belongs to slot i's kind.
List<ItemState> scatter(Level level, math.Random random) {
  final n = level.slots.length;
  const cols = 4;
  final rows = (n / cols).ceil();
  final cw = 332 / cols;
  final ch = 262 / rows;
  final cells = <int>[for (var i = 0; i < cols * rows; i++) i]..shuffle(random);
  final items = <ItemState>[];
  for (var i = 0; i < n; i++) {
    final c = cells[i];
    final col = c % cols;
    final row = c ~/ cols;
    final x = 14 + cw * (col + 0.5) + _rnd(random, -6, 6);
    final y = 364 + ch * (row + 0.5) + _rnd(random, -5, 5);
    final kind = level.slots[i].kind;
    // tall pieces lie down, the others tilt a little
    final tall = itemGeometryBox(kind).height > 80;
    final rotation = tall
        ? (random.nextBool() ? -1 : 1) * _rnd(random, 62, 84)
        : _rnd(random, -28, 28);
    items.add(ItemState(
      id: i,
      kind: kind,
      x: x,
      y: y,
      rotation: rotation,
      scale: 1,
      home: Offset(x, y),
    ));
  }
  return items;
}

/// Nearest free slot of the same kind within 54 board units of (x, y), or null.
/// As drop() in the HTML.
SlotState? findSnap(List<SlotState> slots, String kind, double x, double y) {
  SlotState? best;
  var bestDistance = 54.0;
  for (final s in slots) {
    if (s.filled || s.slot.kind != kind) {
      continue;
    }
    final dx = s.slot.x - x;
    final dy = s.slot.y - y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < bestDistance) {
      bestDistance = d;
      best = s;
    }
  }
  return best;
}

/// True when (y) is above the rug (the y < 352 rule): a wrong drop there
/// springs back home.
bool isAboveRug(double y) => y < 352;

/// Keep a dropped item on the rug (the clamp in drop()).
Offset clampToRug(double x, double y) {
  return Offset(
    math.max(30.0, math.min(330.0, x)),
    math.max(380.0, math.min(610.0, y)),
  );
}

/// Free item + its nearest matching free slot for the hint button, or null.
({ItemState item, SlotState slot})? pickHint(
    List<ItemState> items, List<SlotState> slots, math.Random r) {
  final free = items.where((i) => !i.placed).toList();
  if (free.isEmpty) {
    return null;
  }
  final item = free[r.nextInt(free.length)];
  SlotState? best;
  var bestDistance = double.infinity;
  for (final s in slots) {
    if (s.filled || s.slot.kind != item.kind) {
      continue;
    }
    final dx = s.slot.x - item.x;
    final dy = s.slot.y - item.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < bestDistance) {
      bestDistance = d;
      best = s;
    }
  }
  if (best == null) {
    return null;
  }
  return (item: item, slot: best);
}
