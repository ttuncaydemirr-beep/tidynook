// Bonus boxes: an endless row of generated boxes, unlocked after 12 levels.
// Seeded like the daily box ("tidynook:bonus:<n>", exact 32-bit maths in
// seeded()), so box n is the same puzzle on every device. Exported by
// content.dart.

import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'art.dart';
import 'content.dart';
import 'daily.dart';

/// Levels that must be done before bonus boxes unlock.
const int bonusUnlockLevels = 12;

/// Every this many finished bonus boxes unlock the 3rd style of one piece.
const int bonusStyleEvery = 5;

/// Item kinds a bonus box can use: the daily pool plus compact 1.1 kinds.
/// Each box only takes the kinds that fit its grid cells.
const List<String> bonusPool = <String>[
  ...dailyPool,
  'spool-rose', 'spool-sky', 'spool-sun', 'thimble', 'yarn-rose', 'yarn-sky', 'yarn-sun', 'mitten',
  'btn-round', 'btn-square', 'btn-flower', 'btn-heart', 'safety-pin', 'record', 'mic',
  'tea-mint', 'tea-rose', 'tea-sun', 'sugar', 'hl-sun', 'hl-mint', 'hl-rose', 'glue', 'binder',
  'paperclip', 'apple', 'juicebox', 'cupcake', 'skewer', 'corn', 'pepper', 'flipflop', 'shell',
  'starfish', 'sunscreen', 'bucket', 'packet', 'pot', 'label', 'bulb', 'cactus', 'succulent',
  'pear', 'strawberry', 'cherries',
];

/// True for the mystery bonus boxes: every 3rd box from n = 6 on (6, 9, 12, ...).
bool bonusIsMystery(int n) => n >= 6 && n % 3 == 0;

/// Number of different kinds in bonus box [n]: 4 at first, up to 7.
int bonusKindCount(int n) => math.min(7, 4 + math.max(0, n) ~/ 3);

/// Number of items in bonus box [n]: 8 at first, up to 12.
int bonusItemCount(int n) => math.min(12, 8 + math.max(0, n) ~/ 2);

/// Two kinds whose silhouettes could be confused in a mystery box (bounding
/// boxes within 4 units in both directions). Look-alike families (pencils,
/// jars, ...) share one shape, so they always count as look-alikes.
bool kindsLookAlike(String a, String b) {
  final ga = itemGeometryBox(a);
  final gb = itemGeometryBox(b);
  return (ga.width - gb.width).abs() < 4 && (ga.height - gb.height).abs() < 4;
}

const double _maxItemHeight = 112;

/// Bonus box [n] (n = 0, 1, 2, ...; negative values give box 0). Deterministic.
/// Items sit in two rows (like the daily box) of up to six cells, each item
/// centred in its cell, so no two items overlap and all stay inside the box.
Level bonusLevel(int n) {
  final nn = math.max(0, n);
  final r = seeded('tidynook:bonus:$nn');
  final kindN = bonusKindCount(nn);
  final itemN = bonusItemCount(nn);
  final mystery = bonusIsMystery(nn);
  final cols = (itemN + 1) ~/ 2;
  final colW = 276 / cols;
  final maxW = colW - 8;

  final pool = <String>[
    for (final k in bonusPool)
      if (_fits(itemGeometryBox(k), maxW)) k,
  ];
  for (var i = pool.length - 1; i > 0; i--) {
    final j = (r() * (i + 1)).floor();
    final t = pool[i];
    pool[i] = pool[j];
    pool[j] = t;
  }
  final picked = <String>[];
  for (final k in pool) {
    if (picked.length == kindN) {
      break;
    }
    if (picked.contains(k)) {
      continue;
    }
    if (mystery && picked.any((p) => kindsLookAlike(p, k))) {
      continue;
    }
    picked.add(k);
  }

  // every kind at least once, the rest spread at random (at most 4 of a kind)
  final counts = List<int>.filled(picked.length, 1);
  var extra = itemN - picked.length;
  var guard = 0;
  while (extra > 0) {
    var i = (r() * picked.length).floor();
    if (counts[i] >= 4 || guard > 200) {
      i = counts.indexWhere((c) => c < 4);
      if (i < 0) {
        break;
      }
    }
    counts[i]++;
    extra--;
    guard++;
  }
  final seq = <String>[];
  for (var k = 0; k < picked.length; k++) {
    for (var c = 0; c < counts[k]; c++) {
      seq.add(picked[k]);
    }
  }
  // from box 3 on the kinds are mixed instead of grouped
  if (nn >= 3) {
    for (var i = seq.length - 1; i > 0; i--) {
      final j = (r() * (i + 1)).floor();
      final t = seq[i];
      seq[i] = seq[j];
      seq[j] = t;
    }
  }

  final style = dailyStyles[(r() * dailyStyles.length).floor()];
  final theme = (r() * 5).floor();
  final slots = <Slot>[];
  final firstRow = math.min(cols, seq.length);
  for (var k = 0; k < seq.length; k++) {
    final row = k < firstRow ? 0 : 1;
    final rowCount = row == 0 ? firstRow : seq.length - firstRow;
    final idx = row == 0 ? k : k - firstRow;
    final offset = (cols - rowCount) * colW / 2;
    final cx = 42 + offset + colW * (idx + 0.5);
    final cy = row == 0 ? 136.5 : 267.5;
    final g = itemGeometryBox(seq[k]);
    slots.add(Slot(seq[k], cx - g.center.dx, cy - g.center.dy));
  }
  return Level(
    outer: style[0],
    inner: style[1],
    theme: theme,
    dividers: <Prim>[Prim.rect(42, 201, 276, 6, 3, style[2])],
    slots: slots,
    mystery: mystery,
  );
}

bool _fits(Rect g, double maxW) => g.width <= maxW && g.height <= _maxItemHeight;
