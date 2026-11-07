import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidy_nook/game/art.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/daily.dart';

/// Very small well-formedness check: tags are balanced and properly nested.
bool wellFormed(String svg) {
  final tag = RegExp(r'<(/?)([A-Za-z][\w-]*)([^>]*?)(/?)>');
  final stack = <String>[];
  for (final m in tag.allMatches(svg)) {
    final closing = m[1] == '/';
    final selfClosing = m[4] == '/';
    final name = m[2]!;
    if (selfClosing) {
      continue;
    }
    if (closing) {
      if (stack.isEmpty || stack.removeLast() != name) {
        return false;
      }
    } else {
      stack.add(name);
    }
  }
  return stack.isEmpty;
}

void expectFlutterSvgSafe(String svg) {
  expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg"'));
  expect(svg, contains('viewBox="'));
  expect(svg, endsWith('</svg>'));
  expect(svg.contains('rgba('), isFalse, reason: 'rgba() must be flattened');
  expect(svg.contains('class='), isFalse);
  expect(svg.contains('<style'), isFalse);
  expect(svg.contains('var('), isFalse);
  expect(svg.contains('filter'), isFalse);
  expect(svg.contains('<animate'), isFalse);
  expect(wellFormed(svg), isTrue);
}

/// Shape of a primitive without its colour.
String geometry(Prim p) {
  return '${p.type}|${p.x}|${p.y}|${p.w}|${p.h}|${p.rx}|${p.ry}|${p.r}|'
      '${p.points.map((o) => '${o.dx},${o.dy}').join(' ')}';
}

void main() {
  group('data counts', () {
    test('18 levels, 6 rooms, 18 furniture pieces, 3 milestones', () {
      expect(levels.length, 18);
      expect(rooms.length, 6);
      expect(levelRoom.length, 18);
      expect(decorCount, 18);
      expect(milestones, [3, 7, 14]);
      for (final r in levelRoom) {
        expect(r >= 0 && r < rooms.length, isTrue);
      }
      for (var i = 0; i < decorCount; i++) {
        expect(decorSvg(i, 0), isNotEmpty);
        expect(decorSvg(i, 1), isNotEmpty);
      }
      expect(kinds.length, 90);
    });

    test('level slot counts match the HTML', () {
      final counts = levels.map((l) => l.slots.length).toList();
      expect(counts,
          [6, 5, 6, 6, 7, 6, 8, 10, 9, 7, 8, 9, 7, 8, 8, 8, 8, 9]);
    });

    test('every room has at least one level', () {
      for (var r = 0; r < rooms.length; r++) {
        expect(levelsOfRoom(r), isNotEmpty);
      }
    });

    test('every slot kind exists in kinds', () {
      for (final l in levels) {
        for (final s in l.slots) {
          expect(kinds.containsKey(s.kind), isTrue, reason: s.kind);
        }
      }
    });

    test('daily pool kinds exist', () {
      for (final k in dailyPool) {
        expect(kinds.containsKey(k), isTrue, reason: k);
      }
      expect(dailyPool.length, 40);
      expect(dailyStyles.length, 9);
    });

    test('no two kinds differ by colour only', () {
      final seen = <String, String>{};
      for (final k in kinds.values) {
        final sig = k.prims.map(geometry).join('#');
        expect(seen.containsKey(sig), isFalse,
            reason: '${k.id} has the same shape as ${seen[sig]}');
        seen[sig] = k.id;
      }
    });
  });

  group('art', () {
    test('itemBox adds the 3.5 outline to the geometry', () {
      final egg = itemBox('egg');
      expect(egg.left, closeTo(-23.5, 1e-9));
      expect(egg.right, closeTo(23.5, 1e-9));
      expect(egg.top, closeTo(-29.5, 1e-9));
      expect(egg.bottom, closeTo(29.5, 1e-9));
      // pencil: rect -36..48 high, polygon tip at -52
      final pencil = itemBox('pencil-sun');
      expect(pencil.top, closeTo(-55.5, 1e-9));
      expect(pencil.bottom, closeTo(51.5, 1e-9));
      expect(pencil.left, closeTo(-10.5, 1e-9));
      expect(itemGeometryBox('pencil-sun').height, 100);
    });

    test('itemSvg and ghostSvg are complete, flutter_svg-safe documents', () {
      for (final id in kinds.keys) {
        final svg = itemSvg(id);
        expectFlutterSvgSafe(svg);
        final box = itemBox(id);
        expect(svg, contains(
            'viewBox="${fmtNum(box.left)} ${fmtNum(box.top)} ${fmtNum(box.width)} ${fmtNum(box.height)}"'));
        final ghost = ghostSvg(id);
        expectFlutterSvgSafe(ghost);
        expect(ghost, contains('stroke-dasharray="4 3"'));
        expect(ghost, contains('stroke-opacity="0.8"'));
      }
    });

    test('itemSvg draws outline, rim and fills', () {
      final svg = itemSvg('egg');
      expect(svg, contains('stroke="#2E2638" stroke-width="7"'));
      expect(svg, contains('stroke="#FFFFFF" stroke-width="3"'));
      // translucent highlight of the pencil became hex + fill-opacity
      expect(itemSvg('pencil-sun'), contains('fill="#FFFFFF" fill-opacity="0.35"'));
    });

    test('flattenRgba converts fills and strokes', () {
      expect(flattenRgba('<rect fill="rgba(255,255,255,.6)"/>'),
          '<rect fill="#FFFFFF" fill-opacity="0.6"/>');
      expect(flattenRgba('<rect stroke="rgba(20, 12, 30, 0.5)"/>'),
          '<rect stroke="#140C1E" stroke-opacity="0.5"/>');
      expect(flattenRgba('<rect fill="rgba(0,0,0,1)"/>'),
          '<rect fill="#000000"/>');
    });
  });

  group('svg builders', () {
    test('boardSvg, lidSvg, houseSvg and previews', () {
      final board = boardSvg(levels[0],
          matColor: '#B3A5C6', stitchColor: 'rgba(255,255,255,.55)');
      expectFlutterSvgSafe(board);
      expect(board, contains('viewBox="0 40 360 594"'));
      expect(board, contains('stroke="#FFFFFF" stroke-opacity="0.55"'));

      final lid = lidSvg(levels[3], tapText: 'Tap to open');
      expectFlutterSvgSafe(lid);
      expect(lid, contains('Tap to open'));
      expect(lidSvg(levels[3]).contains('<text'), isFalse);

      final names = ['A', 'B', 'C', 'D', "Kids' Room", 'F'];
      final house = houseSvg(
          done: <int>{0, 1, 3, 6},
          styles: <int, int>{0: 1},
          dailyTotal: 7,
          roomNames: names,
          houseLine: '#3A3046');
      expectFlutterSvgSafe(house);
      expect(house, contains('viewBox="10 -146 340 574"'));
      expect(house, contains('A · 3/4'));
      expect(house, contains('stroke="#3A3046"'));

      final empty = houseSvg(
          done: <int>{},
          styles: <int, int>{},
          dailyTotal: 0,
          roomNames: names,
          houseLine: '#3A3046');
      expectFlutterSvgSafe(empty);
      expect(empty, contains('A · 0/4'));

      for (var i = 0; i < decorCount; i++) {
        expectFlutterSvgSafe(decorPreviewSvg(i, 0));
        expectFlutterSvgSafe(decorPreviewSvg(i, 1));
        final hit = decorHitRect(i);
        expect(hit.width >= 40 && hit.height >= 40, isTrue);
      }
      for (var p = 0; p < 3; p++) {
        expectFlutterSvgSafe(petPreviewSvg(p, locked: false));
        final locked = petPreviewSvg(p, locked: true);
        expectFlutterSvgSafe(locked);
        expect(locked, contains('opacity="0.35"'));
      }
    });

    test('style B swaps colours', () {
      // piece 0 (potted plant): pot #D9825B becomes #8FB8E8
      expect(decorSvg(0, 0), contains('#D9825B'));
      expect(decorSvg(0, 1).contains('#D9825B'), isFalse);
      expect(decorSvg(0, 1), contains('#8FB8E8'));
      // swaps are a single pass (piece 7 swaps #B07D52 -> #F4F1EA and #F4F1EA -> #9FD3C0)
      expect(decorSvg(7, 1), contains('#F4F1EA'));
      expect(decorSvg(7, 1), contains('#9FD3C0'));
    });
  });

  group('daily level', () {
    List<String> kindsOf(Level l) => l.slots.map((s) => s.kind).toList();

    test('2026-11-07 matches the HTML', () {
      final l = dailyLevel('2026-11-07');
      expect(kindsOf(l), [
        'cup', 'cup', 'cup', 'cup', 'toothbrush',
        'toothbrush', 'sd-red', 'sd-red', 'egg', 'egg',
      ]);
      expect(l.theme, 2);
      expect(l.outer, '#E5BE4E');
      expect(l.inner, '#4A2F4F');
      expect(l.dividers.single.fill, '#3A2440');
    });

    test('2026-12-25 matches the HTML', () {
      final l = dailyLevel('2026-12-25');
      expect(kindsOf(l), [
        'note-sky', 'note-sky', 'note-sky', 'note-sky', 'note-sun',
        'note-sun', 'jar-turmeric', 'jar-turmeric', 'ring-rose', 'ring-rose',
      ]);
      expect(l.theme, 1);
      expect(l.outer, '#B98A5E');
      expect(l.inner, '#80583A');
      expect(l.dividers.single.fill, '#6C4A30');
    });

    test('2027-01-01 matches the HTML', () {
      final l = dailyLevel('2027-01-01');
      expect(kindsOf(l), [
        'ring-rose', 'ring-rose', 'ring-rose', 'note-sky', 'note-sky',
        'note-sky', 'tube-yellow', 'tube-yellow', 'jar-paprika', 'jar-paprika',
      ]);
      expect(l.theme, 4);
      expect(l.outer, '#7FB89A');
    });

    test('slot positions follow the HTML grid', () {
      final l = dailyLevel('2026-11-07');
      expect(l.slots[0].x, closeTo(69.6, 1e-9));
      expect(l.slots[4].x, closeTo(290.4, 1e-9));
      expect(l.slots[0].y, 140);
      expect(l.slots[5].x, closeTo(69.6, 1e-9));
      expect(l.slots[5].y, 268);
    });

    test('seeded is deterministic and in [0, 1)', () {
      final a = seeded('tidynook:2026-11-07');
      final b = seeded('tidynook:2026-11-07');
      for (var i = 0; i < 100; i++) {
        final x = a();
        expect(x, b());
        expect(x >= 0 && x < 1, isTrue);
      }
    });

    test('deterministic, 10 slots, no overlapping boxes, all inside the box', () {
      final inside = Rect.fromLTWH(42, 72, 276, 256);
      for (var n = 0; n < 400; n++) {
        final d = DateTime(2026, 1, 1 + n);
        final day = dayString(d);
        final l = dailyLevel(day);
        final again = dailyLevel(day);
        expect(kindsOf(again), kindsOf(l));
        expect(again.theme, l.theme);
        expect(l.slots.length, 10, reason: day);
        expect(l.theme >= 0 && l.theme < 5, isTrue);
        final boxes = <Rect>[
          for (final s in l.slots) itemGeometryBox(s.kind).shift(Offset(s.x, s.y)),
        ];
        for (var i = 0; i < boxes.length; i++) {
          final b = boxes[i];
          expect(b.left >= inside.left && b.right <= inside.right, isTrue,
              reason: '$day ${l.slots[i].kind} horizontally');
          expect(b.top >= inside.top && b.bottom <= inside.bottom, isTrue,
              reason: '$day ${l.slots[i].kind} vertically');
          for (var j = i + 1; j < boxes.length; j++) {
            expect(b.overlaps(boxes[j]), isFalse,
                reason: '$day ${l.slots[i].kind} / ${l.slots[j].kind}');
          }
        }
      }
    });

    test('dayString pads month and day', () {
      expect(dayString(DateTime(2026, 3, 5)), '2026-03-05');
      expect(dayString(DateTime(2026, 12, 25)), '2026-12-25');
    });
  });
}
