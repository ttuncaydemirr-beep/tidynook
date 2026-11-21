// The Winter Cozy Pack (1.3): a one-time product (`winter_pack`) with five
// winter decorations for the house and a 4th "winter" style for six pieces of
// furniture, kept forever and visible all year; plus the free winter gift (a
// little fir tree) that the first finished winter box of the event gives.
//
// Pure data and SVG builders, exported by content.dart. The ownership flags
// live in Progress (winterPack, winterGift); houseSvg(winterPack: ...,
// winterGift: ...) draws the pieces; decorSvg(i, winterStyle) draws the
// winter style (content.dart). See docs/V1_3_PLAN.md, "Contract A 1.3".

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'art.dart';

/// Play product id of the Winter Cozy Pack (one-time, non-consumable).
const String winterPackId = 'winter_pack';

/// Style index of the winter style (the 4th style, after styles 0, 1 and 2).
/// Only the pieces in [winterStylePieces] have it, and only with the pack.
const int winterStyle = 3;

/// Highest number of styles a piece can have (0..3). [styleCount] (3) stays
/// the number every piece has; use Progress.styleCountOf(level) for the
/// picker of one piece.
const int maxStyleCount = 4;

/// Furniture (level indexes) that get the winter style: floor lamp, rug, bed,
/// kitchen table, armchair and rocking chair.
const List<int> winterStylePieces = <int>[1, 2, 5, 7, 8, 19];

/// True when furniture [level] has a winter style (with the pack).
bool hasWinterStyle(int level) => winterStylePieces.contains(level);

/// The five winter decorations of the pack (text keys winterDecorName0..4):
/// 0 pine garland (top of the Bedroom wall), 1 holly wreath (Kitchen wall),
/// 2 warm string lights along the roof, 3 wooden sled (greenhouse lawn),
/// 4 paper star lantern (Reading Nook, above the bookcase).
const int winterDecorCount = 5;

/// What the pack contains, in the order a preview should list it.
enum WinterPackItemKind { decor, style }

/// One entry of the pack contents: a winter decoration ([index] =
/// 0..[winterDecorCount]-1, name winterDecorName(index), preview
/// winterDecorPreviewSvg(index)) or the winter style of a furniture piece
/// ([index] = level index, name decorName(index), preview
/// decorPreviewSvg(index, winterStyle)).
class WinterPackItem {
  final WinterPackItemKind kind;
  final int index;
  const WinterPackItem(this.kind, this.index);

  bool get isDecor => kind == WinterPackItemKind.decor;
}

/// The pack contents for the offer card / shop preview: 5 decorations, then
/// the 6 furniture pieces with a winter style.
const List<WinterPackItem> winterPackItems = <WinterPackItem>[
  WinterPackItem(WinterPackItemKind.decor, 0),
  WinterPackItem(WinterPackItemKind.decor, 1),
  WinterPackItem(WinterPackItemKind.decor, 2),
  WinterPackItem(WinterPackItemKind.decor, 3),
  WinterPackItem(WinterPackItemKind.decor, 4),
  WinterPackItem(WinterPackItemKind.style, 1),
  WinterPackItem(WinterPackItemKind.style, 2),
  WinterPackItem(WinterPackItemKind.style, 5),
  WinterPackItem(WinterPackItemKind.style, 7),
  WinterPackItem(WinterPackItemKind.style, 8),
  WinterPackItem(WinterPackItemKind.style, 19),
];

// ---------------------------------------------------------------------------
// art (house space)
// ---------------------------------------------------------------------------

const String _pine = '#4E8A6C';
const String _pine2 = '#5E9C6E';
const String _berry = '#C9452E';

String _n(num v) => fmtNum(v);

/// 0: a pine garland with berries and two bows along the top of the Bedroom
/// wall (above where the curtained window hangs).
String _buildGarland() {
  final b = StringBuffer();
  for (var t = 0; t <= 10; t++) {
    final x = 38 + t * 6.2;
    final y = 266 + 5 * math.sin(math.pi * t / 10);
    b.write('<ellipse cx="${_n(_r1(x))}" cy="${_n(_r1(y))}" rx="5" ry="3.5" '
        'fill="${t.isEven ? _pine : _pine2}"/>');
  }
  for (var t = 1; t < 10; t += 2) {
    final x = 38 + t * 6.2;
    final y = 266 + 5 * math.sin(math.pi * t / 10) + 1;
    b.write('<circle cx="${_n(_r1(x))}" cy="${_n(_r1(y))}" r="1.4" fill="$_berry"/>');
  }
  for (final x in <num>[38, 100]) {
    b.write('<polygon points="${_n(x - 5)},263 $x,266 ${_n(x - 5)},269" fill="$_berry"/>'
        '<polygon points="${_n(x + 5)},263 $x,266 ${_n(x + 5)},269" fill="$_berry"/>'
        '<circle cx="$x" cy="266" r="1.6" fill="#A8382A"/>');
  }
  return b.toString();
}

double _r1(double v) => (v * 10).roundToDouble() / 10;

/// 1: a holly wreath on the Kitchen wall, left of the pendant lamp.
const String _wreath = '<rect x="55" y="126" width="2" height="4" fill="#3A3046"/>'
    '<circle cx="56" cy="140" r="10" fill="none" stroke="$_pine" stroke-width="6"/>'
    '<circle cx="56" cy="130" r="2.5" fill="$_pine2"/>'
    '<circle cx="63.1" cy="132.9" r="2.5" fill="$_pine2"/>'
    '<circle cx="66" cy="140" r="2.5" fill="$_pine2"/>'
    '<circle cx="48.9" cy="132.9" r="2.5" fill="$_pine2"/>'
    '<circle cx="46" cy="140" r="2.5" fill="$_pine2"/>'
    '<circle cx="59" cy="131" r="1.5" fill="$_berry"/>'
    '<circle cx="65" cy="137" r="1.5" fill="$_berry"/>'
    '<circle cx="47" cy="136" r="1.5" fill="$_berry"/>'
    '<polygon points="50,147 56,150.5 50,154" fill="$_berry"/>'
    '<polygon points="62,147 56,150.5 62,154" fill="$_berry"/>'
    '<circle cx="56" cy="150.5" r="2" fill="#A8382A"/>';

/// 2: warm string lights hanging just under both roof slopes (skipping the
/// chimney). Bulb centres in house space.
const List<List<double>> _bulbs = <List<double>>[
  [50, -386], [63, -392.5], [76, -399], [89, -405.5], [102, -412], [115, -418.5],
  [128, -425], [141, -431.5], [154, -438], [167, -444.5], [180, -451],
  [193, -444.5], [206, -438], [219, -431.5], [232, -425],
  [284, -399], [297, -392.5], [310, -386],
];

const List<String> _bulbColours = <String>[
  '#F6D26B', '#E57A5B', '#7FC4AA', '#8FB8E8', '#F4A7B9',
];

/// Radius of a bulb's glow (its hit box).
const double _bulbGlow = 4.5;

String _buildLights() {
  final b = StringBuffer();
  void wire(int from, int to) {
    final p = StringBuffer('M${_n(_bulbs[from][0])} ${_n(_bulbs[from][1] - 2)}');
    for (var k = from + 1; k <= to; k++) {
      final mx = (_bulbs[k - 1][0] + _bulbs[k][0]) / 2;
      final my = (_bulbs[k - 1][1] + _bulbs[k][1]) / 2 + 1.5;
      p.write(' Q${_n(mx)} ${_n(my)} ${_n(_bulbs[k][0])} ${_n(_bulbs[k][1] - 2)}');
    }
    b.write('<path d="$p" stroke="#3A3046" stroke-width="1.2" fill="none"/>');
  }

  wire(0, 14);
  wire(15, 17);
  for (var k = 0; k < _bulbs.length; k++) {
    final x = _n(_bulbs[k][0]);
    final y = _bulbs[k][1];
    b
      ..write('<circle cx="$x" cy="${_n(y)}" r="${_n(_bulbGlow)}" fill="#FFE9A8" opacity=".35"/>')
      ..write('<ellipse cx="$x" cy="${_n(y + .5)}" rx="2.2" ry="3" '
          'fill="${_bulbColours[k % _bulbColours.length]}"/>')
      ..write('<rect x="${_n(_bulbs[k][0] - 1.2)}" y="${_n(y - 3)}" width="2.4" height="1.6" '
          'fill="#3A3046"/>');
  }
  return b.toString();
}

/// 3: a wooden sled on the greenhouse lawn, left of the greenhouse.
const String _sled = '<path d="M60 798 H88 Q93 798 93 793" stroke="#B07D52" stroke-width="2" '
    'fill="none" stroke-linecap="round"/>'
    '<rect x="66" y="790" width="2" height="8" fill="#8C6240"/>'
    '<rect x="82" y="790" width="2" height="8" fill="#8C6240"/>'
    '<rect x="62" y="786" width="26" height="5" rx="2" fill="$_berry"/>'
    '<rect x="64" y="787.5" width="22" height="1.2" fill="#FFFFFF" opacity=".5"/>'
    '<path d="M62 788 Q56 792 59 798" stroke="#E5BE4E" stroke-width="1.2" fill="none"/>';

/// 4: a paper star lantern hanging in the Reading Nook above the bookcase.
String _buildStar() {
  final b = StringBuffer()
    ..write('<circle cx="212" cy="-194" r="14" fill="#FFE9A8" opacity=".3"/>')
    ..write('<rect x="211.4" y="-220" width="1.2" height="16" fill="#3A3046"/>')
    ..write('<polygon points="${_starPoints(212, -194, 11, 4.6)}" fill="#F6D26B"/>')
    ..write('<polygon points="${_starPoints(212, -194, 6, 2.6)}" fill="#FFE9A8"/>')
    ..write('<rect x="211" y="-184.5" width="2" height="4" rx="1" fill="$_berry"/>');
  return b.toString();
}

String _starPoints(double cx, double cy, double ro, double ri) {
  final pts = <String>[];
  for (var k = 0; k < 10; k++) {
    final a = -math.pi / 2 + k * math.pi / 5;
    final r = k.isEven ? ro : ri;
    pts.add('${_n(_r1(cx + r * math.cos(a)))},${_n(_r1(cy + r * math.sin(a)))}');
  }
  return pts.join(' ');
}

final List<String> _winterDecorSvgs = <String>[
  _buildGarland(),
  _wreath,
  _buildLights(),
  _sled,
  _buildStar(),
];

/// SVG fragment (house space) of winter decoration [i] (clamped).
String winterDecorSvg(int i) => _winterDecorSvgs[_clampDecor(i)];

int _clampDecor(int i) => i < 0 ? 0 : (i >= winterDecorCount ? winterDecorCount - 1 : i);

/// The parts of winter decoration [i] in house space (one rect per bulb for
/// the roof lights): what may not overlap furniture, pets or other decor.
List<Rect> winterDecorParts(int i) {
  switch (_clampDecor(i)) {
    case 0:
      return const <Rect>[Rect.fromLTRB(33, 262.5, 105, 274.5)];
    case 1:
      return const <Rect>[Rect.fromLTRB(43, 126, 69, 155)];
    case 2:
      return <Rect>[
        for (final p in _bulbs)
          Rect.fromCircle(center: Offset(p[0], p[1]), radius: _bulbGlow),
      ];
    case 3:
      return const <Rect>[Rect.fromLTRB(56, 786, 94, 800)];
    default:
      return const <Rect>[Rect.fromLTRB(198, -220, 226, -180)];
  }
}

/// Bounds of winter decoration [i] in house space.
Rect winterDecorBounds(int i) {
  final parts = winterDecorParts(i);
  var r = parts.first;
  for (final p in parts.skip(1)) {
    r = r.expandToInclude(p);
  }
  return r;
}

/// Centre of winter decoration [i] in house space (sparkles, scrolling after
/// a purchase).
Offset winterDecorSpot(int i) => winterDecorBounds(i).center;

/// Background (wall, floor) behind each decoration in its preview.
const List<List<String>> _decorBackdrop = <List<String>>[
  ['#F3D6DE', '#F3D6DE'], // Bedroom wall
  ['#F6E3C6', '#F6E3C6'], // Kitchen wall
  ['#C9587C', '#C9587C'], // the roof
  ['#DDEFE3', '#C9E4D1'], // sky and lawn
  ['#E4F0E7', '#E4F0E7'], // Reading Nook wall
];

/// Preview of winter decoration [i] (offer card, shop, purchase toast).
String winterDecorPreviewSvg(int i) {
  final k = _clampDecor(i);
  final r = winterDecorBounds(k);
  final bg = _decorBackdrop[k];
  final box = k == 2
      // the lights preview zooms on the left slope only, so the bulbs read
      ? const Rect.fromLTRB(46, -456, 184, -380)
      : r;
  final body = StringBuffer()
    ..write('<rect x="${_n(box.left - 400)}" y="${_n(box.top - 400)}" width="${_n(box.width + 800)}" '
        'height="${_n(box.height + 800)}" fill="${bg[0]}"/>');
  if (k == 3) {
    body.write('<rect x="${_n(box.left - 400)}" y="796" width="${_n(box.width + 800)}" height="400" '
        'fill="${bg[1]}"/>');
  }
  body.write('<g>${_winterDecorSvgs[k]}</g>');
  return svgDocument(_zoom(box), body.toString());
}

String _zoom(Rect r) {
  final side = math.max(r.width, r.height) * 1.3 + 8;
  final cx = r.center.dx;
  final cy = r.center.dy;
  return '${(cx - side / 2).toStringAsFixed(1)} ${(cy - side / 2).toStringAsFixed(1)} '
      '${side.toStringAsFixed(1)} ${side.toStringAsFixed(1)}';
}

// ---------------------------------------------------------------------------
// the free winter gift
// ---------------------------------------------------------------------------

/// The free winter gift: a little fir tree with a star and baubles on the
/// greenhouse lawn (house space). Text key winterGiftName.
final String _firTree = _buildFirTree();

String _buildFirTree() {
  return '<rect x="42" y="792" width="4" height="7" fill="#8C6240"/>'
      '<polygon points="33,794 55,794 44,776" fill="$_pine"/>'
      '<polygon points="35,784 53,784 44,767" fill="$_pine2"/>'
      '<polygon points="37,774 51,774 44,758" fill="$_pine"/>'
      '<circle cx="40" cy="790" r="1.5" fill="$_berry"/>'
      '<circle cx="49" cy="788" r="1.5" fill="#F6D26B"/>'
      '<circle cx="42" cy="780" r="1.5" fill="#8FB8E8"/>'
      '<circle cx="47" cy="771" r="1.5" fill="$_berry"/>'
      '<polygon points="${_starPoints(44, 756, 4.5, 1.9)}" fill="#E5BE4E"/>';
}

/// Bounds of the winter gift in house space.
const Rect winterGiftRect = Rect.fromLTRB(33, 751, 55, 799);

/// Centre of the winter gift (sparkles and scrolling for the reveal).
const Offset winterGiftSpot = Offset(44, 775);

/// SVG fragment (house space) of the winter gift.
String winterGiftSvg() => _firTree;

/// Preview of the winter gift (reveal card), optionally greyed out.
String winterGiftPreviewSvg({bool locked = false}) {
  var body = '<rect x="-300" y="400" width="900" height="800" fill="#DDEFE3"/>'
      '<rect x="-300" y="796" width="900" height="400" fill="#C9E4D1"/>'
      '<g>$_firTree</g>';
  if (locked) {
    body = '<g opacity="0.35">${_grey(body)}</g>';
  }
  return svgDocument(_zoom(winterGiftRect), body);
}

final RegExp _hex6 = RegExp(r'#([0-9A-Fa-f]{6})');

String _grey(String svg) {
  return svg.replaceAllMapped(_hex6, (Match m) {
    final v = int.parse(m[1]!, radix: 16);
    final y = (0.2126 * ((v >> 16) & 0xFF) + 0.7152 * ((v >> 8) & 0xFF) + 0.0722 * (v & 0xFF))
        .round()
        .clamp(0, 255)
        .toInt();
    final h = y.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$h$h$h';
  });
}

// ---------------------------------------------------------------------------
// pack preview
// ---------------------------------------------------------------------------

/// One picture of the whole pack for the shop row and the offer card: the
/// five decorations on a 3 x 2 grid of tiles plus a tile with the winter
/// armchair ([armchairSvg] = decorSvg(8, winterStyle), passed in by
/// content.dart). viewBox "0 0 300 200".
String winterPackPreviewSvgWith(String armchairSvg) {
  final b = StringBuffer();
  const tile = 100.0;
  final cells = <String>[
    for (var k = 0; k < winterDecorCount; k++) _tile(_winterDecorSvgs[k], _previewBox(k), _decorBackdrop[k][0]),
    _tile(armchairSvg, const Rect.fromLTRB(10, 92, 80, 138), '#D6E4F0'),
  ];
  for (var c = 0; c < cells.length; c++) {
    final x = (c % 3) * tile;
    final y = (c ~/ 3) * tile;
    b.write('<g transform="translate(${_n(x + 4)} ${_n(y + 4)})">${cells[c]}</g>');
  }
  return svgDocument('0 0 300 200', b.toString());
}

Rect _previewBox(int k) => k == 2 ? const Rect.fromLTRB(46, -456, 184, -380) : winterDecorBounds(k);

/// A 92 x 92 rounded tile showing [fragment] (drawn in its own coordinates)
/// scaled onto [box].
String _tile(String fragment, Rect box, String bg) {
  const size = 92.0;
  final side = math.max(box.width, box.height) * 1.25;
  final s = size / side;
  final tx = size / 2 - box.center.dx * s;
  final ty = size / 2 - box.center.dy * s;
  return '<rect width="92" height="92" rx="14" fill="$bg"/>'
      '<g transform="translate(${tx.toStringAsFixed(2)} ${ty.toStringAsFixed(2)}) '
      'scale(${s.toStringAsFixed(4)})">$fragment</g>';
}
