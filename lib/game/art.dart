// Item art for Tidy Nook: drawing primitives, every item kind and the SVG
// builders for the sticker-style items and their ghosts.
//
// Ported from the shipped HTML game (web-preview/index.html): prim(), art(),
// ghost() and the KINDS table. All SVG output uses explicit attributes only
// (no CSS classes, no CSS variables, no filters) so that flutter_svg can draw it.
// rgba(...) colours are converted to a hex colour plus fill-opacity /
// stroke-opacity because flutter_svg does not parse rgba() reliably.

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// The shape kinds a [Prim] can have.
enum PrimType { rect, circle, ellipse, polygon }

/// One drawing primitive: rect | circle | ellipse | polygon, with a fill colour
/// string such as "#F6E7D3" or "rgba(255,255,255,.6)".
///
/// Field usage by type:
///  - rect:    x, y (top-left), w, h, rx (corner radius)
///  - circle:  x, y (centre), r
///  - ellipse: x, y (centre), rx, ry
///  - polygon: points
class Prim {
  final PrimType type;
  final double x;
  final double y;
  final double w;
  final double h;
  final double rx;
  final double ry;
  final double r;
  final List<Offset> points;
  final String fill;

  const Prim._(this.type, this.x, this.y, this.w, this.h, this.rx, this.ry,
      this.r, this.points, this.fill);

  factory Prim.rect(num x, num y, num w, num h, num rx, String fill) {
    return Prim._(PrimType.rect, x.toDouble(), y.toDouble(), w.toDouble(),
        h.toDouble(), rx.toDouble(), 0.0, 0.0, const <Offset>[], fill);
  }

  factory Prim.circle(num cx, num cy, num r, String fill) {
    return Prim._(PrimType.circle, cx.toDouble(), cy.toDouble(), 0.0, 0.0,
        0.0, 0.0, r.toDouble(), const <Offset>[], fill);
  }

  factory Prim.ellipse(num cx, num cy, num rx, num ry, String fill) {
    return Prim._(PrimType.ellipse, cx.toDouble(), cy.toDouble(), 0.0, 0.0,
        rx.toDouble(), ry.toDouble(), 0.0, const <Offset>[], fill);
  }

  /// [pts] is the SVG points string, for example "-7,-36 7,-36 0,-52".
  factory Prim.polygon(String pts, String fill) {
    final list = <Offset>[];
    for (final pair in pts.trim().split(RegExp(r'\s+'))) {
      final xy = pair.split(',');
      list.add(Offset(double.parse(xy[0]), double.parse(xy[1])));
    }
    return Prim._(PrimType.polygon, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, list,
        fill);
  }

  /// Centre x of a circle or ellipse.
  double get cx => x;

  /// Centre y of a circle or ellipse.
  double get cy => y;

  /// Geometric bounds (no stroke).
  Rect get bounds {
    switch (type) {
      case PrimType.rect:
        return Rect.fromLTWH(x, y, w, h);
      case PrimType.circle:
        return Rect.fromLTRB(x - r, y - r, x + r, y + r);
      case PrimType.ellipse:
        return Rect.fromLTRB(x - rx, y - ry, x + rx, y + ry);
      case PrimType.polygon:
        var minX = points.first.dx;
        var maxX = minX;
        var minY = points.first.dy;
        var maxY = minY;
        for (final p in points) {
          minX = math.min(minX, p.dx);
          maxX = math.max(maxX, p.dx);
          minY = math.min(minY, p.dy);
          maxY = math.max(maxY, p.dy);
        }
        return Rect.fromLTRB(minX, minY, maxX, maxY);
    }
  }
}

/// One kind of item: an id such as "egg" or "pencil-sun", its main colour and
/// its drawing primitives (centre of the item is (0, 0)).
class ItemKind {
  final String id;
  final String main;
  final List<Prim> prims;
  const ItemKind(this.id, this.main, this.prims);
}

/// Colours used by the sticker outline.
const String artOutline = '#2E2638';

// ---------------------------------------------------------------------------
// SVG helpers shared with content.dart
// ---------------------------------------------------------------------------

/// Formats a number the way JavaScript prints it: integers without ".0".
String fmtNum(num v) {
  final d = v.toDouble();
  if (d == d.roundToDouble() && d.abs() < 1e15) {
    return d.toInt().toString();
  }
  return d.toString();
}

/// Escapes text for use inside SVG text nodes.
String xmlEscape(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

final RegExp _rgbaAttr = RegExp(
    r'(fill|stroke)="rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)"');

String _hex2(int v) {
  final c = v < 0 ? 0 : (v > 255 ? 255 : v);
  return c.toRadixString(16).padLeft(2, '0').toUpperCase();
}

/// Replaces every fill="rgba(r,g,b,a)" and stroke="rgba(r,g,b,a)" attribute
/// with a hex colour plus fill-opacity / stroke-opacity (omitted when a >= 1).
String flattenRgba(String svg) {
  return svg.replaceAllMapped(_rgbaAttr, (Match m) {
    final attr = m[1]!;
    final hex =
        '#${_hex2(int.parse(m[2]!))}${_hex2(int.parse(m[3]!))}${_hex2(int.parse(m[4]!))}';
    var a = m[5]!;
    if (a.startsWith('.')) {
      a = '0$a';
    }
    final alpha = double.tryParse(a) ?? 1.0;
    if (alpha >= 1.0) {
      return '$attr="$hex"';
    }
    return '$attr="$hex" $attr-opacity="${fmtNum(alpha)}"';
  });
}

/// Wraps [body] in a complete SVG document with the given viewBox string.
/// rgba() colours in [body] are flattened.
String svgDocument(String viewBox, String body) {
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">'
      '${flattenRgba(body)}</svg>';
}

String _viewBoxOf(Rect r) {
  return '${fmtNum(r.left)} ${fmtNum(r.top)} ${fmtNum(r.width)} ${fmtNum(r.height)}';
}

// ---------------------------------------------------------------------------
// primitives -> SVG
// ---------------------------------------------------------------------------

String _primSvg(Prim p, {String? fill, String extra = ''}) {
  final f = fill ?? p.fill;
  switch (p.type) {
    case PrimType.rect:
      return '<rect x="${fmtNum(p.x)}" y="${fmtNum(p.y)}" width="${fmtNum(p.w)}" '
          'height="${fmtNum(p.h)}" rx="${fmtNum(p.rx)}" fill="$f"$extra/>';
    case PrimType.circle:
      return '<circle cx="${fmtNum(p.x)}" cy="${fmtNum(p.y)}" r="${fmtNum(p.r)}" '
          'fill="$f"$extra/>';
    case PrimType.ellipse:
      return '<ellipse cx="${fmtNum(p.x)}" cy="${fmtNum(p.y)}" rx="${fmtNum(p.rx)}" '
          'ry="${fmtNum(p.ry)}" fill="$f"$extra/>';
    case PrimType.polygon:
      final pts =
          p.points.map((o) => '${fmtNum(o.dx)},${fmtNum(o.dy)}').join(' ');
      return '<polygon points="$pts" fill="$f"$extra/>';
  }
}

/// SVG markup (no svg wrapper) for a list of primitives with their own colours.
/// Used for the box dividers.
String primsSvg(List<Prim> prims) {
  return prims.map((p) => _primSvg(p)).join();
}

/// SVG markup (no svg wrapper) for a single primitive with its own colour.
String primSvg(Prim p) => _primSvg(p);

// ---------------------------------------------------------------------------
// item kinds
// ---------------------------------------------------------------------------

/// Every item kind, exactly as in the HTML (KINDS), in the same order.
final Map<String, ItemKind> kinds = _buildKinds();

Map<String, ItemKind> _buildKinds() {
  final m = <String, ItemKind>{};
  final r = Prim.rect;
  final c = Prim.circle;
  final e = Prim.ellipse;
  final p = Prim.polygon;
  void k(String id, String main, List<Prim> prims) {
    m[id] = ItemKind(id, main, prims);
  }

  k('egg', '#F6E7D3', [e(0, 0, 20, 26, '#F6E7D3'), e(-6, -9, 5, 7, '#FFFDF8')]);
  k('pencil-sun', '#F6D26B', [r(-7, -36, 14, 72, 2, '#F6D26B'), r(-7, -36, 4, 72, 1, 'rgba(255,255,255,.35)'), p('-7,-36 7,-36 0,-52', '#F2D3A8'), p('-2.4,-46.6 2.4,-46.6 0,-52', '#3B3346'), r(-7, 34, 14, 5, 1, '#C9C3CF'), r(-7, 38, 14, 10, 3, '#F4A7B9')]);
  k('pencil-mint', '#9FD3C0', [r(-7, -36, 14, 72, 2, '#9FD3C0'), r(-7, -36, 4, 72, 1, 'rgba(255,255,255,.35)'), p('-7,-36 7,-36 0,-52', '#F2D3A8'), p('-2.4,-46.6 2.4,-46.6 0,-52', '#3B3346'), r(-7, -4, 14, 4, 0, '#FFFFFF'), r(-7, 34, 14, 5, 1, '#C9C3CF'), r(-7, 38, 14, 10, 3, '#F4A7B9')]);
  k('pencil-rose', '#F4A7B9', [r(-7, -36, 14, 72, 2, '#F4A7B9'), r(-7, -36, 4, 72, 1, 'rgba(255,255,255,.35)'), p('-7,-36 7,-36 0,-52', '#F2D3A8'), p('-2.4,-46.6 2.4,-46.6 0,-52', '#3B3346'), r(-7, -10, 14, 4, 0, '#FFFFFF'), r(-7, 0, 14, 4, 0, '#FFFFFF'), r(-7, 34, 14, 5, 1, '#C9C3CF'), r(-7, 38, 14, 10, 3, '#F4A7B9')]);
  k('pencil-peach', '#F2B48C', [r(-7, -36, 14, 72, 2, '#F2B48C'), r(-7, -36, 4, 72, 1, 'rgba(255,255,255,.35)'), p('-7,-36 7,-36 0,-52', '#F2D3A8'), p('-2.4,-46.6 2.4,-46.6 0,-52', '#3B3346'), c(0, -14, 3, '#FFFFFF'), c(0, -2, 3, '#FFFFFF'), c(0, 10, 3, '#FFFFFF'), r(-7, 34, 14, 5, 1, '#C9C3CF'), r(-7, 38, 14, 10, 3, '#F4A7B9')]);
  k('eraser', '#F7B9C8', [r(-14, -20, 28, 40, 6, '#F7B9C8'), r(-14, 2, 28, 18, 4, '#8FB8E8'), r(-14, 2, 28, 3, 1, '#7AA6DA')]);
  k('sock-rose', '#F4A7B9', [r(-17, -42, 34, 84, 14, '#F4A7B9'), r(-17, -42, 34, 16, 6, 'rgba(255,255,255,.6)'), r(-17, -30, 34, 3, 1, 'rgba(0,0,0,.10)'), r(-17, -8, 34, 6, 0, 'rgba(255,255,255,.6)'), r(-17, 6, 34, 6, 0, 'rgba(255,255,255,.6)'), e(0, 30, 12, 8, 'rgba(0,0,0,.10)')]);
  k('sock-mint', '#9FD3C0', [r(-17, -42, 34, 84, 14, '#9FD3C0'), r(-17, -42, 34, 16, 6, 'rgba(255,255,255,.6)'), r(-17, -30, 34, 3, 1, 'rgba(0,0,0,.10)'), c(-7, -6, 3.5, 'rgba(255,255,255,.6)'), c(6, 4, 3.5, 'rgba(255,255,255,.6)'), c(-5, 15, 3.5, 'rgba(255,255,255,.6)'), c(7, -17, 3.5, 'rgba(255,255,255,.6)'), e(0, 30, 12, 8, 'rgba(0,0,0,.10)')]);
  k('sock-lav', '#CDBFE3', [r(-17, -42, 34, 84, 14, '#CDBFE3'), r(-17, -42, 34, 16, 6, 'rgba(255,255,255,.6)'), r(-17, -30, 34, 3, 1, 'rgba(0,0,0,.10)'), r(-17, 26, 34, 16, 8, 'rgba(255,255,255,.6)'), e(0, 30, 12, 8, 'rgba(0,0,0,.10)')]);
  k('spoon', '#C9CDD6', [r(-4, -10, 8, 58, 4, '#C9CDD6'), e(0, -30, 13, 20, '#C9CDD6'), e(-4, -34, 4, 8, 'rgba(255,255,255,.65)')]);
  k('fork', '#C9CDD6', [r(-4, -22, 8, 70, 4, '#C9CDD6'), r(-12, -40, 24, 22, 6, '#C9CDD6'), r(-12, -58, 5, 22, 2.5, '#C9CDD6'), r(-2.5, -58, 5, 22, 2.5, '#C9CDD6'), r(7, -58, 5, 22, 2.5, '#C9CDD6')]);
  k('knife', '#D5D9E1', [p('-5,8 7,8 7,-46 -5,-58', '#D5D9E1'), r(-6, 6, 12, 46, 5, '#A9A2B5')]);
  k('book0', '#F4A7B9', [r(-14, -48, 28, 96, 3, '#F4A7B9'), r(-14, -38, 28, 5, 1, 'rgba(255,255,255,.6)'), r(-14, 32, 28, 5, 1, 'rgba(255,255,255,.6)'), r(-14, -48, 3, 96, 1, 'rgba(0,0,0,.10)')]);
  k('book1', '#9FD3C0', [r(-12, -42, 24, 84, 3, '#9FD3C0'), r(-12, -32, 24, 5, 1, 'rgba(255,255,255,.6)'), r(-12, 26, 24, 5, 1, 'rgba(255,255,255,.6)'), r(-12, -42, 3, 84, 1, 'rgba(0,0,0,.10)')]);
  k('book2', '#8FB8E8', [r(-16, -52, 32, 104, 3, '#8FB8E8'), r(-16, -42, 32, 5, 1, 'rgba(255,255,255,.6)'), r(-16, 36, 32, 5, 1, 'rgba(255,255,255,.6)'), r(-16, -52, 3, 104, 1, 'rgba(0,0,0,.10)')]);
  k('book3', '#F6D26B', [r(-13, -39, 26, 78, 3, '#F6D26B'), r(-13, -29, 26, 5, 1, 'rgba(255,255,255,.6)'), r(-13, 23, 26, 5, 1, 'rgba(255,255,255,.6)'), r(-13, -39, 3, 78, 1, 'rgba(0,0,0,.10)')]);
  k('book4', '#CDBFE3', [r(-15, -46, 30, 92, 3, '#CDBFE3'), r(-15, -36, 30, 5, 1, 'rgba(255,255,255,.6)'), r(-15, 30, 30, 5, 1, 'rgba(255,255,255,.6)'), r(-15, -46, 3, 92, 1, 'rgba(0,0,0,.10)')]);
  k('book5', '#F2B48C', [r(-11, -44, 22, 88, 3, '#F2B48C'), r(-11, -34, 22, 5, 1, 'rgba(255,255,255,.6)'), r(-11, 28, 22, 5, 1, 'rgba(255,255,255,.6)'), r(-11, -44, 3, 88, 1, 'rgba(0,0,0,.10)')]);
  k('book6', '#E58FA6', [r(-17, -50, 34, 100, 3, '#E58FA6'), r(-17, -40, 34, 5, 1, 'rgba(255,255,255,.6)'), r(-17, 34, 34, 5, 1, 'rgba(255,255,255,.6)'), r(-17, -50, 3, 100, 1, 'rgba(0,0,0,.10)')]);
  k('bookflat', '#CDBFE3', [r(-32, -15, 64, 30, 3, '#CDBFE3'), r(-22, -15, 5, 30, 1, 'rgba(255,255,255,.6)'), r(17, -15, 5, 30, 1, 'rgba(255,255,255,.6)'), r(-32, 12, 64, 3, 1, 'rgba(0,0,0,.10)')]);
  k('lip-red', '#D9637A', [r(-9, 0, 18, 30, 3, '#D9CFE3'), r(-9, 0, 18, 4, 1, '#BFB2CC'), r(-7, -16, 14, 17, 2, '#E9E3EF'), p('-6,-16 6,-16 6,-26 -6,-33', '#D9637A')]);
  k('lip-berry', '#9E4470', [r(-9, 0, 18, 30, 3, '#D9CFE3'), r(-9, 0, 18, 4, 1, '#BFB2CC'), r(-7, -16, 14, 17, 2, '#E9E3EF'), p('-6,-16 6,-16 6,-26 -6,-33', '#9E4470'), r(-9, 12, 18, 4, 0, '#9E4470')]);
  k('lip-coral', '#F08A6C', [r(-9, 0, 18, 30, 3, '#D9CFE3'), r(-9, 0, 18, 4, 1, '#BFB2CC'), r(-7, -16, 14, 17, 2, '#E9E3EF'), p('-6,-16 6,-16 6,-26 -6,-33', '#F08A6C'), c(0, 16, 4, '#F08A6C')]);
  k('compact', '#F7C6D0', [c(0, 0, 26, '#F0AFC0'), c(0, 0, 19, '#FBE3E8'), c(-7, -7, 5, 'rgba(255,255,255,.85)')]);
  k('brush', '#E58FA6', [r(-5, -8, 10, 58, 5, '#E6C9A8'), r(-6, -26, 12, 20, 3, '#C9C3CF'), e(0, -38, 8, 14, '#E58FA6')]);
  k('palette', '#F2E6D8', [r(-36, -24, 72, 48, 10, '#F2E6D8'), c(-20, -8, 8, '#F4A7B9'), c(0, -8, 8, '#F2B48C'), c(20, -8, 8, '#CDBFE3'), c(-20, 10, 8, '#9FD3C0'), c(0, 10, 8, '#F6D26B'), c(20, 10, 8, '#E58FA6')]);
  k('jar-paprika', '#E57A5B', [r(-20, -22, 40, 50, 9, '#E57A5B'), r(-20, -22, 8, 50, 4, 'rgba(255,255,255,.3)'), r(-18, -34, 36, 13, 4, '#B9A389'), r(-14, -6, 28, 16, 3, '#FFF8EC'), p('-8,4 6,-2 9,1 -5,6', '#C9452E')]);
  k('jar-turmeric', '#F2C14E', [r(-20, -22, 40, 50, 9, '#F2C14E'), r(-20, -22, 8, 50, 4, 'rgba(255,255,255,.3)'), r(-18, -34, 36, 13, 4, '#B9A389'), r(-14, -6, 28, 16, 3, '#FFF8EC'), c(-5, 2, 3.5, '#D99A1E'), c(5, 2, 3.5, '#D99A1E')]);
  k('jar-herb', '#8FBF7A', [r(-20, -22, 40, 50, 9, '#8FBF7A'), r(-20, -22, 8, 50, 4, 'rgba(255,255,255,.3)'), r(-18, -34, 36, 13, 4, '#B9A389'), r(-14, -6, 28, 16, 3, '#FFF8EC'), e(0, 2, 9, 4, '#5E9C4E')]);
  k('jar-cinnamon', '#B07D52', [r(-20, -22, 40, 50, 9, '#B07D52'), r(-20, -22, 8, 50, 4, 'rgba(255,255,255,.3)'), r(-18, -34, 36, 13, 4, '#B9A389'), r(-14, -6, 28, 16, 3, '#FFF8EC'), r(-9, -1, 18, 3, 1.5, '#7A5435'), r(-9, 4, 18, 3, 1.5, '#7A5435')]);
  k('jar-jam', '#D9637A', [r(-20, -22, 40, 50, 9, '#D9637A'), r(-20, -22, 8, 50, 4, 'rgba(255,255,255,.3)'), r(-18, -34, 36, 13, 4, '#B9A389'), r(-14, -6, 28, 16, 3, '#FFF8EC'), c(-4, 1, 3.5, '#B04060'), c(4, 1, 3.5, '#B04060'), p('-7.5,2.5 7.5,2.5 0,9', '#B04060')]);
  k('jar-pickle', '#A8C686', [r(-20, -22, 40, 50, 9, '#A8C686'), r(-20, -22, 8, 50, 4, 'rgba(255,255,255,.3)'), r(-18, -34, 36, 13, 4, '#B9A389'), r(-14, -6, 28, 16, 3, '#FFF8EC'), r(-9, 0, 18, 4, 2, '#6F8F4E')]);
  k('milk', '#F4F1EA', [r(-15, -20, 30, 68, 10, '#F4F1EA'), r(-7, -38, 14, 22, 4, '#F4F1EA'), r(-8, -46, 16, 9, 3, '#8FB8E8'), r(-15, 4, 30, 20, 2, '#8FB8E8'), p('0,7 5,15 0,20 -5,15', '#FFFFFF')]);
  k('juice', '#F6B26B', [r(-15, -20, 30, 68, 10, '#F6B26B'), r(-7, -38, 14, 22, 4, '#F6B26B'), r(-8, -46, 16, 9, 3, '#7FC4AA'), r(-15, 4, 30, 20, 2, '#FFF3E0'), c(0, 14, 6, '#F08A6C'), r(-1, 6, 2, 4, 1, '#5E9C6E')]);
  k('shampoo', '#CDBFE3', [r(-15, -20, 30, 68, 10, '#CDBFE3'), r(-7, -38, 14, 22, 4, '#CDBFE3'), r(-8, -46, 16, 9, 3, '#E58FA6'), r(-15, 4, 30, 20, 2, '#FFF3E0'), c(-5, 12, 3, '#CDBFE3'), c(3, 17, 4, '#CDBFE3'), c(6, 9, 2, '#CDBFE3')]);
  k('can-mint', '#9FD3C0', [r(-18, -25, 36, 50, 6, '#9FD3C0'), r(-18, -25, 36, 6, 2, '#C9CDD6'), r(-18, 19, 36, 6, 2, '#C9CDD6'), r(-18, -6, 36, 10, 0, 'rgba(255,255,255,.6)'), c(0, 10, 4, '#5E9C7E')]);
  k('can-rose', '#F4A7B9', [r(-18, -25, 36, 50, 6, '#F4A7B9'), r(-18, -25, 36, 6, 2, '#C9CDD6'), r(-18, 19, 36, 6, 2, '#C9CDD6'), r(-18, -6, 36, 10, 0, 'rgba(255,255,255,.6)'), r(-6, 7, 12, 6, 2, '#C9587C')]);
  k('sd-red', '#E57A5B', [r(-2.5, -50, 5, 64, 2, '#C9CDD6'), r(-9, 10, 18, 40, 8, '#E57A5B'), r(-9, 10, 18, 6, 3, 'rgba(0,0,0,.12)')]);
  k('sd-blue', '#8FB8E8', [r(-2.5, -50, 5, 64, 2, '#C9CDD6'), r(-9, 10, 18, 40, 8, '#8FB8E8'), r(-9, 10, 18, 6, 3, 'rgba(0,0,0,.12)'), r(-9, 24, 18, 3, 1, 'rgba(255,255,255,.6)'), r(-9, 32, 18, 3, 1, 'rgba(255,255,255,.6)')]);
  k('hammer', '#8E8798', [r(-5, -24, 10, 74, 4, '#D9B48F'), r(-26, -38, 52, 20, 5, '#A8A1B2'), r(-26, -38, 52, 5, 2, 'rgba(255,255,255,.3)')]);
  k('wrench', '#B9BEC9', [r(-5, -36, 10, 72, 5, '#B9BEC9'), c(0, -40, 13, '#B9BEC9'), c(0, -40, 5, '#8E93A0'), c(0, 40, 10, '#B9BEC9'), c(0, 40, 4, '#8E93A0')]);
  k('tape', '#F6D26B', [c(0, 0, 26, '#F6D26B'), c(0, 0, 10, '#4A4057'), r(14, 12, 16, 12, 3, '#E5BE4E')]);
  k('battery', '#9FD3C0', [r(-9, -22, 18, 44, 4, '#6E6680'), r(-4, -27, 8, 6, 2, '#C9CDD6'), r(-9, -22, 18, 16, 4, '#9FD3C0')]);
  k('shirt-rose', '#F4A7B9', [r(-40, -26, 80, 52, 8, '#F4A7B9'), p('-14,-26 14,-26 0,-10', 'rgba(255,255,255,.6)'), r(-1, -8, 2, 30, 1, 'rgba(0,0,0,.12)'), c(0, -2, 2, 'rgba(0,0,0,.2)'), c(0, 10, 2, 'rgba(0,0,0,.2)')]);
  k('shirt-sun', '#F6D26B', [r(-40, -26, 80, 52, 8, '#F6D26B'), p('-14,-26 14,-26 0,-10', 'rgba(255,255,255,.6)'), r(-1, -8, 2, 30, 1, 'rgba(0,0,0,.12)'), c(0, -2, 2, 'rgba(0,0,0,.2)'), c(0, 10, 2, 'rgba(0,0,0,.2)'), r(14, -10, 16, 13, 2, 'rgba(255,255,255,.6)')]);
  k('toiletry', '#9FD3C0', [r(-34, -22, 68, 44, 14, '#9FD3C0'), r(-30, -17, 60, 4, 2, '#4A4057'), r(22, -21, 6, 10, 2, '#C9CDD6')]);
  k('glasses', '#6E6680', [r(-4, -4, 8, 4, 2, '#6E6680'), c(-16, 0, 13, '#6E6680'), c(16, 0, 13, '#6E6680'), c(-16, 0, 9, '#BFE0F2'), c(16, 0, 9, '#BFE0F2'), c(-19, -3, 3, '#FFFFFF'), c(13, -3, 3, '#FFFFFF')]);
  k('toothbrush', '#8FB8E8', [r(-5, -50, 10, 98, 5, '#8FB8E8'), r(-15, -48, 10, 28, 3, '#FFFFFF'), r(-15, -41, 10, 2, 1, 'rgba(0,0,0,.12)'), r(-15, -33, 10, 2, 1, 'rgba(0,0,0,.12)'), r(-5, 12, 10, 4, 1, 'rgba(255,255,255,.6)')]);
  k('toothpaste', '#F4F1EA', [r(-15, -48, 30, 8, 2, '#E5BE4E'), p('-14,-41 14,-41 10,30 -10,30', '#F4F1EA'), r(-7, 30, 14, 14, 3, '#D9637A'), r(-12, -16, 24, 16, 2, '#8FB8E8')]);
  k('soap', '#F7B9C8', [r(-26, -16, 52, 32, 14, '#F7B9C8'), e(0, 0, 15, 7, 'rgba(255,255,255,.5)')]);
  k('cotton', '#BFE0EA', [r(-22, -24, 44, 54, 10, '#BFE0EA'), r(-20, -36, 40, 13, 4, '#C9CDD6'), c(-8, 10, 8, '#FFFFFF'), c(8, 14, 8, '#FFFFFF'), c(0, -4, 8, '#FFFFFF')]);
  k('towel-rose', '#F4A7B9', [c(0, 0, 25, '#F4A7B9'), c(0, 0, 16, 'rgba(0,0,0,.10)'), c(0, 0, 7, 'rgba(0,0,0,.14)'), r(-25, -3, 50, 6, 0, 'rgba(255,255,255,.6)')]);
  k('towel-sun', '#F6D26B', [c(0, 0, 25, '#F6D26B'), c(0, 0, 16, 'rgba(0,0,0,.10)'), c(0, 0, 7, 'rgba(0,0,0,.14)'), r(-3, -25, 6, 50, 0, 'rgba(255,255,255,.6)')]);
  k('towel-mint', '#9FD3C0', [c(0, 0, 25, '#9FD3C0'), c(0, 0, 16, 'rgba(0,0,0,.10)'), c(0, 0, 7, 'rgba(0,0,0,.14)')]);
  k('duck', '#F6D26B', [e(0, 8, 26, 18, '#F6D26B'), c(10, -14, 13, '#F6D26B'), p('21,-17 35,-12 21,-8', '#F08A6C'), c(13, -17, 2.5, '#4A4057'), e(-7, 6, 12, 7, 'rgba(255,255,255,.45)')]);
  k('bathbomb', '#CDBFE3', [c(0, 0, 19, '#CDBFE3'), c(-6, -6, 3, 'rgba(255,255,255,.6)'), c(7, 4, 2.5, 'rgba(255,255,255,.6)'), c(-2, 9, 2, 'rgba(255,255,255,.6)'), c(8, -8, 2, 'rgba(255,255,255,.6)')]);
  k('ball', '#E57A5B', [c(0, 0, 24, '#E57A5B'), e(0, 0, 24, 7, '#F6D26B'), c(-8, -10, 5, 'rgba(255,255,255,.6)')]);
  k('block-sun', '#F6D26B', [r(-22, -22, 44, 44, 6, '#F6D26B'), r(-15, -15, 30, 30, 4, 'rgba(255,255,255,.35)'), c(0, 0, 7, '#FFFFFF')]);
  k('block-mint', '#7FC4AA', [r(-22, -22, 44, 44, 6, '#7FC4AA'), r(-15, -15, 30, 30, 4, 'rgba(255,255,255,.35)'), p('0,-9 9,7 -9,7', '#FFFFFF')]);
  k('block-rose', '#E58FA6', [r(-22, -22, 44, 44, 6, '#E58FA6'), r(-15, -15, 30, 30, 4, 'rgba(255,255,255,.35)'), r(-7, -7, 14, 14, 2, '#FFFFFF')]);
  k('car', '#8FB8E8', [r(-34, -6, 68, 22, 8, '#8FB8E8'), p('-18,-6 -10,-22 14,-22 22,-6', '#8FB8E8'), r(-8, -18, 18, 10, 3, '#DDF0FA'), c(-18, 18, 8, '#4A4057'), c(18, 18, 8, '#4A4057'), c(-18, 18, 3, '#C9CDD6'), c(18, 18, 3, '#C9CDD6')]);
  k('rocket', '#F4F1EA', [p('-14,10 -24,32 -10,26', '#E57A5B'), p('14,10 24,32 10,26', '#E57A5B'), p('-6,30 6,30 0,42', '#F6D26B'), e(0, -4, 14, 34, '#F4F1EA'), c(0, -12, 6, '#8FB8E8'), e(0, -30, 8, 8, '#E57A5B')]);
  k('note-sky', '#BFE0F2', [r(-26, -34, 52, 68, 4, '#BFE0F2'), r(-26, -34, 7, 68, 2, 'rgba(0,0,0,.15)'), r(-10, -20, 28, 14, 2, '#FFFFFF'), c(4, 16, 5, '#5E86C0')]);
  k('note-sun', '#F6D26B', [r(-26, -34, 52, 68, 4, '#F6D26B'), r(-26, -34, 7, 68, 2, 'rgba(0,0,0,.15)'), r(-10, -20, 28, 14, 2, '#FFFFFF'), r(-2, 12, 14, 8, 2, '#C9952A')]);
  k('ruler', '#F6D26B', [r(-8, -50, 16, 100, 3, '#F6D26B'), r(-8, -40, 8, 2, 1, '#8C6240'), r(-8, -30, 5, 2, 1, '#8C6240'), r(-8, -20, 8, 2, 1, '#8C6240'), r(-8, -10, 5, 2, 1, '#8C6240'), r(-8, 0, 8, 2, 1, '#8C6240'), r(-8, 10, 5, 2, 1, '#8C6240'), r(-8, 20, 8, 2, 1, '#8C6240'), r(-8, 30, 5, 2, 1, '#8C6240'), r(-8, 40, 8, 2, 1, '#8C6240')]);
  k('lunchbox', '#E57A5B', [r(-10, -30, 20, 8, 4, '#4A4057'), r(-30, -22, 60, 44, 10, '#E57A5B'), r(-30, -10, 60, 4, 1, 'rgba(0,0,0,.10)'), c(0, 6, 5, 'rgba(255,255,255,.6)')]);
  k('bottle-kid', '#7FC4AA', [r(-8, -44, 16, 12, 4, '#4A4057'), r(-12, -34, 24, 68, 10, '#7FC4AA'), r(-12, -4, 24, 8, 0, 'rgba(255,255,255,.6)')]);
  k('sneaker', '#9FD3C0', [r(-30, -18, 30, 26, 8, '#9FD3C0'), r(-30, -4, 62, 16, 8, '#9FD3C0'), r(-32, 9, 66, 7, 3, '#FFFFFF'), r(-10, -10, 4, 8, 1, 'rgba(255,255,255,.6)'), r(-2, -7, 4, 8, 1, 'rgba(255,255,255,.6)')]);
  k('boot', '#E8A86E', [r(-14, -34, 26, 50, 6, '#E8A86E'), r(-14, 4, 42, 16, 7, '#E8A86E'), r(-16, 17, 46, 7, 3, '#4A4057'), r(-14, -26, 26, 4, 1, 'rgba(255,255,255,.6)')]);
  k('heel', '#E58FA6', [r(-28, 8, 5, 16, 1, '#C9587C'), p('-28,10 -24,-12 -12,-12 0,0 28,4 28,10', '#E58FA6'), r(-28, 8, 58, 4, 2, '#4A4057')]);
  k('slipper', '#CDBFE3', [e(0, 6, 30, 11, '#CDBFE3'), e(8, 0, 16, 10, '#F4F1EA'), e(8, 0, 10, 5, '#CDBFE3')]);
  k('ring-rose', '#E58FA6', [c(0, 6, 14, '#E5BE4E'), c(0, 6, 8, '#B8902A'), c(0, -10, 7, '#E58FA6')]);
  k('ring-mint', '#7FC4AA', [c(0, 6, 14, '#E5BE4E'), c(0, 6, 8, '#B8902A'), r(-6, -16, 12, 12, 2, '#7FC4AA')]);
  k('ring-sky', '#8FB8E8', [c(0, 6, 14, '#E5BE4E'), c(0, 6, 8, '#B8902A'), p('0,-20 8,-10 0,-1 -8,-10', '#8FB8E8')]);
  k('earring', '#9FD3C0', [c(0, -16, 4, '#E5BE4E'), r(-1, -14, 2, 8, 1, '#E5BE4E'), e(0, 6, 9, 13, '#9FD3C0'), c(-3, 2, 3, 'rgba(255,255,255,.6)')]);
  k('necklace', '#E5BE4E', [e(0, 0, 34, 26, '#E5BE4E'), e(0, -3, 28, 20, '#B8902A'), c(0, 26, 8, '#E58FA6'), c(-3, 23, 2.5, 'rgba(255,255,255,.6)')]);
  k('bracelet', '#C9CDD6', [e(0, 0, 27, 13, '#C9CDD6'), e(0, 0, 19, 7, '#8E93A0'), c(-18, 0, 4, '#CDBFE3'), c(18, 0, 4, '#CDBFE3'), c(0, 10, 4, '#E58FA6')]);
  k('watch', '#B07D52', [r(-8, -36, 16, 72, 6, '#B07D52'), c(0, 0, 16, '#E5BE4E'), c(0, 0, 12, '#FFFFFF'), r(-1, -9, 2, 9, 1, '#4A4057'), r(0, -1, 7, 2, 1, '#4A4057')]);
  k('tube-red', '#E57A5B', [r(-6, -42, 12, 13, 3, '#4A4057'), p('-12,-30 12,-30 10,24 -10,24', '#E57A5B'), r(-10, 24, 20, 6, 2, '#C9CDD6'), r(-11, -14, 22, 16, 2, '#FFFFFF'), c(0, -6, 5, '#E57A5B')]);
  k('tube-blue', '#8FB8E8', [r(-6, -42, 12, 13, 3, '#4A4057'), p('-12,-30 12,-30 10,24 -10,24', '#8FB8E8'), r(-10, 24, 20, 6, 2, '#C9CDD6'), r(-11, -14, 22, 16, 2, '#FFFFFF'), r(-8, -8, 16, 5, 1, '#5E86C0')]);
  k('tube-yellow', '#F6D26B', [r(-6, -42, 12, 13, 3, '#4A4057'), p('-12,-30 12,-30 10,24 -10,24', '#F6D26B'), r(-10, 24, 20, 6, 2, '#C9CDD6'), r(-11, -14, 22, 16, 2, '#FFFFFF'), p('0,-12 6,-1 -6,-1', '#D99A1E')]);
  k('paintbrush', '#B07D52', [r(-3, -10, 6, 60, 3, '#B07D52'), r(-5, -26, 10, 18, 2, '#C9CDD6'), p('-5,-26 5,-26 0,-46', '#E57A5B')]);
  k('cup', '#BFE0F2', [r(-20, -22, 40, 48, 8, '#BFE0F2'), r(-17, -4, 34, 26, 6, '#8FB8E8'), r(-22, -26, 44, 8, 4, '#DDF0FA')]);
  k('sponge', '#F6D26B', [r(-24, -14, 48, 28, 8, '#F6D26B'), c(-12, -3, 3, '#D9B04A'), c(4, 4, 3.5, '#D9B04A'), c(14, -6, 2.5, '#D9B04A'), c(-4, -8, 2, '#D9B04A')]);
  k('sweater-rose', '#F4A7B9', [r(-34, -16, 68, 32, 6, '#F4A7B9'), r(-34, -4, 68, 3, 1, 'rgba(0,0,0,.10)'), e(0, -14, 10, 4, 'rgba(0,0,0,.14)'), r(-34, 5, 68, 4, 0, 'rgba(255,255,255,.6)')]);
  k('sweater-sky', '#8FB8E8', [r(-34, -16, 68, 32, 6, '#8FB8E8'), r(-34, -4, 68, 3, 1, 'rgba(0,0,0,.10)'), e(0, -14, 10, 4, 'rgba(0,0,0,.14)'), c(-18, 7, 3, 'rgba(255,255,255,.6)'), c(0, 7, 3, 'rgba(255,255,255,.6)'), c(18, 7, 3, 'rgba(255,255,255,.6)')]);
  k('sweater-sun', '#F6D26B', [r(-34, -16, 68, 32, 6, '#F6D26B'), r(-34, -4, 68, 3, 1, 'rgba(0,0,0,.10)'), e(0, -14, 10, 4, 'rgba(0,0,0,.14)'), p('0,0 7,7 0,14 -7,7', 'rgba(255,255,255,.6)')]);
  k('hat', '#E8A86E', [e(0, 10, 34, 8, '#E8A86E'), r(-18, -14, 36, 26, 10, '#E8A86E'), r(-18, 2, 36, 6, 0, '#4A4057')]);
  k('handbag', '#E57A5B', [r(-16, -26, 32, 7, 3.5, '#9C4A33'), r(-16, -26, 6, 18, 3, '#9C4A33'), r(10, -26, 6, 18, 3, '#9C4A33'), r(-28, -12, 56, 40, 8, '#E57A5B'), c(0, 4, 4, '#E5BE4E')]);
  k('scarf', '#9FD3C0', [r(-10, -34, 20, 64, 6, '#9FD3C0'), r(-10, -16, 20, 5, 0, 'rgba(255,255,255,.6)'), r(-10, 0, 20, 5, 0, 'rgba(255,255,255,.6)'), r(-10, 28, 20, 9, 1, '#F4F1EA')]);
  return m;
}

ItemKind _kind(String id) {
  final k = kinds[id];
  if (k == null) {
    throw ArgumentError.value(id, 'kindId', 'unknown item kind');
  }
  return k;
}

final Map<String, Rect> _geoCache = <String, Rect>{};

/// Item-local geometric bounding box (origin = item centre), without outline.
Rect itemGeometryBox(String kindId) {
  final cached = _geoCache[kindId];
  if (cached != null) {
    return cached;
  }
  final prims = _kind(kindId).prims;
  var box = prims.first.bounds;
  for (final p in prims.skip(1)) {
    box = box.expandToInclude(p.bounds);
  }
  _geoCache[kindId] = box;
  return box;
}

/// Item-local bounding box (origin = item centre) INCLUDING the 3.5 px outline.
Rect itemBox(String kindId) => itemGeometryBox(kindId).inflate(3.5);

final Map<String, String> _itemCache = <String, String>{};
final Map<String, String> _ghostCache = <String, String>{};

/// Sticker-style item art: dark outline (#2E2638, width 7), white rim (width 3),
/// then the fills, exactly like art() in the HTML. Returns a complete <svg>
/// document whose viewBox is itemBox(kindId).
String itemSvg(String kindId) {
  final cached = _itemCache[kindId];
  if (cached != null) {
    return cached;
  }
  final ps = _kind(kindId).prims;
  const outlineExtra =
      ' stroke="$artOutline" stroke-width="7" stroke-linejoin="round"';
  const rimExtra = ' stroke="#FFFFFF" stroke-width="3" stroke-linejoin="round"';
  final body = StringBuffer('<g stroke-linejoin="round">');
  for (final p in ps) {
    body.write(_primSvg(p, fill: artOutline, extra: outlineExtra));
  }
  for (final p in ps) {
    body.write(_primSvg(p, fill: '#FFFFFF', extra: rimExtra));
  }
  body.write('</g>');
  for (final p in ps) {
    body.write(_primSvg(p));
  }
  final svg = svgDocument(_viewBoxOf(itemBox(kindId)), body.toString());
  _itemCache[kindId] = svg;
  return svg;
}

/// Ghost (empty slot) art, like ghost() in the HTML, with the same viewBox as
/// [itemSvg].
String ghostSvg(String kindId) {
  final cached = _ghostCache[kindId];
  if (cached != null) {
    return cached;
  }
  final ps = _kind(kindId).prims;
  final body = StringBuffer('<g opacity="0.45">');
  for (final p in ps) {
    body.write(_primSvg(p));
  }
  body.write('</g>');
  body.write(_primSvg(ps.first,
      fill: 'none',
      extra:
          ' stroke="rgba(255,255,255,.8)" stroke-width="1.8" stroke-dasharray="4 3"'));
  final svg = svgDocument(_viewBoxOf(itemBox(kindId)), body.toString());
  _ghostCache[kindId] = svg;
  return svg;
}
