// Board rules: the first scatter of the items on the rug, snapping, hints and
// the drop rules. Ported from build(), drop() and the hint button of the
// shipped HTML game (web-preview/index.html).
//
// 1.2 adds the inner drawer mechanic: a slot inside a closed drawer waits for
// other slots ([SlotState.waitFor]); [findSnap] and [pickHint] skip it until
// they are all filled, so the drawer "opens" by itself without any extra call.

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

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

  /// Ids of the slots that must be filled before this one can take an item
  /// (the keys of its inner drawer, see drawerKeys); empty = open from the start.
  final List<int> waitFor;
  SlotState({
    required this.id,
    required this.slot,
    this.filled = false,
    this.waitFor = const <int>[],
  });
}

/// Fresh slot states for [level] (ids 0..n-1 in slot order). Slots inside an
/// inner drawer wait for that drawer's keys.
List<SlotState> makeSlots(Level level) {
  final wait = List<List<int>>.filled(level.slots.length, const <int>[]);
  for (var d = 0; d < level.drawers.length; d++) {
    final keys = drawerKeys(level, d);
    for (final s in level.drawers[d].slots) {
      if (s >= 0 && s < wait.length) {
        wait[s] = keys;
      }
    }
  }
  return <SlotState>[
    for (var i = 0; i < level.slots.length; i++)
      SlotState(id: i, slot: level.slots[i], waitFor: wait[i]),
  ];
}

SlotState? _byId(List<SlotState> slots, int id) {
  if (id >= 0 && id < slots.length && slots[id].id == id) {
    return slots[id];
  }
  for (final s in slots) {
    if (s.id == id) {
      return s;
    }
  }
  return null;
}

/// True when slot [s] can take an item: every slot it waits for is filled.
bool slotOpen(List<SlotState> slots, SlotState s) {
  for (final id in s.waitFor) {
    final k = _byId(slots, id);
    if (k != null && !k.filled) {
      return false;
    }
  }
  return true;
}

/// True when drawer [d] of [level] is open (all its keys are filled).
bool drawerOpen(Level level, int d, List<SlotState> slots) {
  return drawerRemaining(level, d, slots) == 0;
}

/// Number of key slots of drawer [d] that are still empty (0 = open). The UI
/// may show it on the closed drawer front.
int drawerRemaining(Level level, int d, List<SlotState> slots) {
  var n = 0;
  for (final id in drawerKeys(level, d)) {
    final k = _byId(slots, id);
    if (k != null && !k.filled) {
      n++;
    }
  }
  return n;
}

/// The drawers of [level] that the filling of slot [slotId] just opened
/// (call right after setting that slot's filled = true): play the opening
/// animation and the sound for them.
List<int> drawersOpenedBy(Level level, List<SlotState> slots, int slotId) {
  return <int>[
    for (var d = 0; d < level.drawers.length; d++)
      if (drawerKeys(level, d).contains(slotId) && drawerOpen(level, d, slots)) d,
  ];
}

double _rnd(math.Random random, double a, double b) {
  return a + random.nextDouble() * (b - a);
}

const double _rugMargin = 6;

/// [v] limited to lo..hi; when the range is empty (item bigger than the rug)
/// the middle of it.
double _fit(double v, double lo, double hi) {
  if (lo > hi) {
    return (lo + hi) / 2;
  }
  return math.max(lo, math.min(hi, v));
}

/// Bounding box of [box] (item-local, origin = item centre) after rotating it
/// by [degrees] around that origin, still relative to the centre.
Rect rotatedExtent(Rect box, double degrees) {
  final a = degrees * math.pi / 180;
  final c = math.cos(a);
  final s = math.sin(a);
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in <Offset>[
    box.topLeft,
    box.topRight,
    box.bottomLeft,
    box.bottomRight,
  ]) {
    final rx = p.dx * c - p.dy * s;
    final ry = p.dx * s + p.dy * c;
    minX = math.min(minX, rx);
    maxX = math.max(maxX, rx);
    minY = math.min(minY, ry);
    maxY = math.max(maxY, ry);
  }
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Initial scatter of a level's items on the rug: same grid / jitter / rotation
/// rules as build() in the HTML. Item i belongs to slot i's kind.
///
/// 1.2: in crowded boxes (more than 8 items) tall-for-their-cell items lie down
/// and the others tilt only half as much, and for every box a final pass
/// pushes overlapping items apart (inside the rug, never past the outer grid
/// columns), so the loose items barely touch at the start.
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
    var x = 14 + cw * (col + 0.5) + _rnd(random, -6, 6);
    var y = 364 + ch * (row + 0.5) + _rnd(random, -5, 5);
    final kind = level.slots[i].kind;
    // tall pieces lie down, the others tilt a little
    final geo = itemGeometryBox(kind);
    final crowded = n > 8;
    final tall = geo.height > 80 ||
        (crowded && geo.height > ch * 0.8 && geo.height > geo.width * 1.3);
    final rotation = tall
        ? (random.nextBool() ? -1 : 1) * _rnd(random, 62, 84)
        : _rnd(random, -28, 28) * (crowded ? 0.5 : 1);
    // keep the whole rotated item box inside the rug
    final ext = rotatedExtent(itemBox(kind), rotation);
    x = _fit(x, 14 + _rugMargin - ext.left, 346 - _rugMargin - ext.right);
    y = _fit(y, 364 + _rugMargin - ext.top, 626 - _rugMargin - ext.bottom);
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
  _spreadOut(items, 14 + cw / 2 - 6, 346 - cw / 2 + 6);
  return items;
}

/// Pushes overlapping items apart (along the axis of the smaller overlap),
/// keeping every rotated item box on the rug and every centre between [minX]
/// and [maxX]. Deterministic; sets each item's home to its final place.
void _spreadOut(List<ItemState> items, double minX, double maxX) {
  final ext = <Rect>[
    for (final it in items) rotatedExtent(itemBox(it.kind), it.rotation),
  ];
  void clamp(int i) {
    final it = items[i];
    final e = ext[i];
    it.x = _fit(it.x, math.max(14 + _rugMargin - e.left, minX),
        math.min(346 - _rugMargin - e.right, maxX));
    it.y = _fit(it.y, 364 + _rugMargin - e.top, 626 - _rugMargin - e.bottom);
  }

  for (var pass = 0; pass < 150; pass++) {
    var moved = false;
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        final a = items[i];
        final b = items[j];
        final ea = ext[i];
        final eb = ext[j];
        final ox = math.min(a.x + ea.right, b.x + eb.right) -
            math.max(a.x + ea.left, b.x + eb.left);
        final oy = math.min(a.y + ea.bottom, b.y + eb.bottom) -
            math.max(a.y + ea.top, b.y + eb.top);
        if (ox <= 0 || oy <= 0) {
          continue;
        }
        moved = true;
        if (ox < oy) {
          final d = (ox / 2 + .5) * (a.x < b.x ? 1 : -1);
          a.x -= d;
          b.x += d;
        } else {
          final d = (oy / 2 + .5) * (a.y < b.y ? 1 : -1);
          a.y -= d;
          b.y += d;
        }
        clamp(i);
        clamp(j);
      }
    }
    if (!moved) {
      break;
    }
  }
  for (final it in items) {
    it.home = Offset(it.x, it.y);
  }
}

/// Nearest free slot of the same kind within 54 board units of (x, y), or null.
/// As drop() in the HTML.
SlotState? findSnap(List<SlotState> slots, String kind, double x, double y) {
  SlotState? best;
  var bestDistance = 54.0;
  for (final s in slots) {
    if (s.filled || s.slot.kind != kind || !slotOpen(slots, s)) {
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
/// 1.2: only items that have an open matching slot are picked (a slot in a
/// closed drawer is never hinted).
({ItemState item, SlotState slot})? pickHint(
    List<ItemState> items, List<SlotState> slots, math.Random r) {
  final open = <SlotState>[
    for (final s in slots)
      if (!s.filled && slotOpen(slots, s)) s,
  ];
  final free = items
      .where((i) => !i.placed && open.any((s) => s.slot.kind == i.kind))
      .toList();
  if (free.isEmpty) {
    return null;
  }
  final item = free[r.nextInt(free.length)];
  SlotState? best;
  var bestDistance = double.infinity;
  for (final s in open) {
    if (s.slot.kind != item.kind) {
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
