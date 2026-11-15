import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidy_nook/game/art.dart';
import 'package:tidy_nook/game/board_logic.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/daily.dart';
import 'package:tidy_nook/game/progress.dart';

import 'game_data_test.dart' show expectFlutterSvgSafe;

const Rect _inside = Rect.fromLTRB(42, 72, 318, 328);

Rect _slotBox(Slot s) => itemGeometryBox(s.kind).shift(Offset(s.x, s.y));

void _expectTidy(Level l, String name) {
  final boxes = <Rect>[for (final s in l.slots) _slotBox(s)];
  for (var i = 0; i < boxes.length; i++) {
    final b = boxes[i];
    final kind = l.slots[i].kind;
    expect(kinds.containsKey(kind), isTrue, reason: '$name $kind');
    expect(
        b.left >= _inside.left &&
            b.right <= _inside.right &&
            b.top >= _inside.top &&
            b.bottom <= _inside.bottom,
        isTrue,
        reason: '$name $kind inside the box');
    for (final d in l.dividers) {
      expect(b.overlaps(d.bounds), isFalse, reason: '$name $kind / divider');
    }
    for (var j = i + 1; j < boxes.length; j++) {
      expect(b.overlaps(boxes[j]), isFalse,
          reason: '$name $kind / ${l.slots[j].kind}');
    }
  }
}

/// Plays [level] to the end the way a player would: always drags a free item
/// onto the slot the hint points at (snapping through findSnap). Returns the
/// number of placements; fails if the board ever gets stuck.
int _playThrough(Level level, int seed) {
  final slots = makeSlots(level);
  final items = scatter(level, math.Random(seed));
  final r = math.Random(seed + 1);
  var moves = 0;
  while (items.any((i) => !i.placed)) {
    final h = pickHint(items, slots, r);
    expect(h, isNotNull, reason: 'stuck after $moves moves');
    final snap = findSnap(slots, h!.item.kind, h.slot.slot.x, h.slot.slot.y);
    expect(snap, isNotNull);
    expect(slotOpen(slots, snap!), isTrue);
    snap.filled = true;
    h.item.placed = true;
    moves++;
    expect(moves <= level.slots.length, isTrue);
  }
  return moves;
}

const String _schema3Fixture =
    '{"v":3,"lang":"de","level":23,"done":[0,1,2,3,4,5,6,7,8,9,10,11,12,21,22],'
    '"sound":false,"styles":{"3":1,"5":2,"21":2},'
    '"daily":{"last":"2026-11-14","streak":4,"total":17,'
    '"days":["2026-11-11","2026-11-12","2026-11-13","2026-11-14"]},'
    '"extraStyles":[5,21],"adsRemoved":true,"supporter":false,"bonusDone":7,'
    '"vibration":false,"reminderOn":true,"reminderAsked":true,"reviewAsked":true,'
    '"adCounter":2,"lastAdMs":1763100000000,"streakSaveDay":"2026-11-10",'
    '"hintDay":"2026-11-14","hintsUsed":2,"extraHints":3}';

Progress _withTasks(DateTime day, List<TaskType> types, {Set<int>? done}) {
  final p = Progress(done: done ?? <int>{0, 1, 2});
  p.clock = () => day;
  p.taskDay = dayString(day);
  p.tasks = <DailyTask>[
    for (final t in types) DailyTask(type: t, target: t == TaskType.boxes ? 2 : 1),
  ];
  return p;
}

void main() {
  group('chapter 3 content', () {
    test('15 new levels in three new rooms of five', () {
      expect(levels.length, 45);
      expect(levelsOfRoom(10), [30, 31, 32, 33, 34]);
      expect(levelsOfRoom(11), [35, 36, 37, 38, 39]);
      expect(levelsOfRoom(12), [40, 41, 42, 43, 44]);
      expect(topFloorRooms, [10, 11]);
      expect(greenhouseRoom, 12);
      expect(chapter3Start, 30);
      expect(mechanicIntroLevel, 30);
    });

    test('new levels are tidy and gently harder (10 to 14 items)', () {
      for (var i = 30; i < 45; i++) {
        expect(levels[i].slots.length, inInclusiveRange(10, 14), reason: 'level $i');
        _expectTidy(levels[i], 'level $i');
      }
      expect(levels[30].slots.length, 10);
      expect(levels[43].slots.length, 14);
      expect(levels[44].slots.length, 14);
      final first = levels.sublist(30, 37).map((l) => l.slots.length).reduce((a, b) => a + b) / 7;
      final last = levels.sublist(38, 45).map((l) => l.slots.length).reduce((a, b) => a + b) / 7;
      expect(last > first, isTrue);
    });

    test('no reused layouts and new box colours', () {
      final seen = <String>{};
      for (final l in levels) {
        final sig = l.slots.map((s) => '${s.kind}@${s.x},${s.y}').join(';');
        expect(seen.add(sig), isTrue);
      }
      final old = <String>{for (var i = 0; i < 30; i++) levels[i].outer};
      for (var i = 30; i < 45; i++) {
        expect(old.contains(levels[i].outer), isFalse, reason: 'level $i');
      }
    });

    test('drawer levels 30, 33, 37, 40, 43 and mystery levels 35, 41', () {
      final dr = <int>[for (var i = 0; i < levels.length; i++) if (levels[i].hasDrawers) i];
      expect(dr, [30, 33, 37, 40, 43]);
      final m = <int>[for (var i = 30; i < levels.length; i++) if (levels[i].mystery) i];
      expect(m, [35, 41]);
      for (final i in m) {
        final ks = levels[i].slots.map((s) => s.kind).toSet().toList();
        for (var a = 0; a < ks.length; a++) {
          for (var b = a + 1; b < ks.length; b++) {
            expect(kindsLookAlike(ks[a], ks[b]), isFalse, reason: 'level $i ${ks[a]} ${ks[b]}');
          }
        }
      }
      for (var i = 0; i < 30; i++) {
        expect(levels[i].drawers, isEmpty);
      }
      expect(dailyLevel('2026-12-24').drawers, isEmpty);
      expect(bonusLevel(9).drawers, isEmpty);
    });

    test('drawers sit inside the box and hold only their own slots', () {
      for (var i = 0; i < levels.length; i++) {
        final l = levels[i];
        for (var d = 0; d < l.drawers.length; d++) {
          final a = l.drawers[d].area;
          expect(_inside.contains(a.topLeft) && _inside.contains(a.bottomRight - const Offset(1, 1)), isTrue);
          for (final div in l.dividers) {
            expect(a.overlaps(div.bounds), isFalse);
          }
          expect(l.drawers[d].slots, isNotEmpty);
          for (var s = 0; s < l.slots.length; s++) {
            final b = _slotBox(l.slots[s]);
            if (l.drawers[d].slots.contains(s)) {
              final inner = a.deflate(3);
              expect(
                  b.left >= inner.left &&
                      b.right <= inner.right &&
                      b.top >= inner.top &&
                      b.bottom <= inner.bottom,
                  isTrue,
                  reason: 'level $i slot $s in the drawer');
            } else {
              expect(a.overlaps(b), isFalse, reason: 'level $i slot $s outside');
            }
          }
          final keys = drawerKeys(l, d);
          expect(keys.length + l.drawers[d].slots.length, l.slots.length);
          expect(keys.toSet().intersection(l.drawers[d].slots.toSet()), isEmpty);
        }
      }
    });

    test('new kinds: 55 more, families differ by pattern', () {
      expect(kinds.length, 212);
      for (final fam in <List<String>>[
        ['peg-rose', 'peg-mint', 'peg-sun'],
        ['cloth-sky', 'cloth-rose', 'cloth-sun'],
        ['candle-rose', 'candle-sky', 'candle-sun'],
        ['pawn-rose', 'pawn-sky', 'pawn-sun'],
        ['herb-basil', 'herb-mint', 'herb-sage'],
        ['tulip-rose', 'tulip-lav', 'tulip-sun'],
        ['ornament-rose', 'ornament-sky', 'ornament-sun'],
      ]) {
        expect(kindsLookAlike(fam[0], fam[1]), isTrue);
        final counts = fam.map((k) => kinds[k]!.prims.length).toSet();
        expect(counts.length > 1, isTrue, reason: '${fam[0]}: each member has its own pattern');
      }
      for (final id in kinds.keys) {
        expectFlutterSvgSafe(itemSvg(id));
      }
    });
  });

  group('drawer mechanic (board rules)', () {
    test('drawer slots stay closed until every key is filled, then open', () {
      for (final i in <int>[30, 33, 37, 40, 43]) {
        final l = levels[i];
        final slots = makeSlots(l);
        final inner = l.drawers[0].slots;
        final keys = drawerKeys(l, 0);
        for (final s in inner) {
          expect(slots[s].waitFor, keys);
          expect(slotOpen(slots, slots[s]), isFalse);
          final sl = slots[s].slot;
          final got = findSnap(slots, sl.kind, sl.x, sl.y);
          expect(got == null || !inner.contains(got.id), isTrue, reason: 'level $i');
        }
        expect(drawerOpen(l, 0, slots), isFalse);
        expect(drawerRemaining(l, 0, slots), keys.length);
        for (var k = 0; k < keys.length; k++) {
          slots[keys[k]].filled = true;
          final opened = drawersOpenedBy(l, slots, keys[k]);
          if (k < keys.length - 1) {
            expect(opened, isEmpty);
            expect(drawerRemaining(l, 0, slots), keys.length - k - 1);
          } else {
            expect(opened, [0]);
          }
        }
        expect(drawerOpen(l, 0, slots), isTrue);
        for (final s in inner) {
          final sl = slots[s].slot;
          expect(findSnap(slots, sl.kind, sl.x, sl.y)?.id, s);
        }
      }
    });

    test('hints never point into a closed drawer', () {
      final l = levels[30];
      final slots = makeSlots(l);
      final items = scatter(l, math.Random(5));
      for (var k = 0; k < 40; k++) {
        final h = pickHint(items, slots, math.Random(k))!;
        expect(l.drawers[0].slots.contains(h.slot.id), isFalse);
      }
    });

    test('every level and every winter box can be finished (never stuck)', () {
      for (var i = 0; i < levels.length; i++) {
        for (var seed = 0; seed < 3; seed++) {
          expect(_playThrough(levels[i], seed * 31 + i), levels[i].slots.length);
        }
      }
      for (final w in winterLevels) {
        expect(_playThrough(w, 7), w.slots.length);
      }
    });

    test('boards without drawers behave as before', () {
      final slots = makeSlots(levels[0]);
      for (final s in slots) {
        expect(s.waitFor, isEmpty);
        expect(slotOpen(slots, s), isTrue);
      }
    });

    test('board, tray and drawer front art', () {
      final l = levels[30];
      final board = boardSvg(l, matColor: '#B3A5C6', stitchColor: '#FFFFFF');
      expectFlutterSvgSafe(board);
      expect(board, contains('x="192" y="214" width="120" height="106" rx="12"'));
      final plain = boardSvg(levels[31], matColor: '#B3A5C6', stitchColor: '#FFFFFF');
      expect(plain.contains('rx="12"'), isFalse);
      final front = drawerFrontSvg(l, 0);
      expectFlutterSvgSafe(front);
      expect(front, contains('viewBox="0 40 360 594"'));
      expect(front, contains(l.drawers[0].front));
      expect(drawerKnobCenter(l, 0), l.drawers[0].area.center);
    });
  });

  group('house 1.2', () {
    final all = <int>{for (var i = 0; i < levels.length; i++) i};
    String h({bool snow = false, bool snowman = false, Set<int> decor = const <int>{}}) => houseSvg(
          done: all,
          styles: const <int, int>{},
          dailyTotal: 30,
          roomNames: const <String>[],
          houseLine: '#3A3046',
          extended: true,
          snow: snow,
          snowman: snowman,
          chestDecors: decor,
        );

    test('new rooms, snow, snowman and chest decor', () {
      final base = h();
      expectFlutterSvgSafe(base);
      expect(base, contains('viewBox="10 -466 340 1276"'));
      for (var i = 30; i < 45; i++) {
        expect(base, contains(decorSvg(i, 0)), reason: 'piece $i');
      }
      final snow = h(snow: true);
      expectFlutterSvgSafe(snow);
      expect(snow.length > base.length, isTrue);
      expect(base.contains('#BFD6E6'), isFalse);
      expect(snow, contains('#BFD6E6'));
      final man = h(snowman: true);
      expectFlutterSvgSafe(man);
      expect(man.length > base.length, isTrue);
      var last = base.length;
      for (var d = 0; d < chestDecorCount; d++) {
        final s = h(decor: <int>{for (var k = 0; k <= d; k++) k});
        expectFlutterSvgSafe(s);
        expect(s.length > last, isTrue);
        last = s.length;
      }
      // the 1.0 frame ignores the 1.2 extras
      final legacy = houseSvg(
          done: all,
          styles: const <int, int>{},
          dailyTotal: 30,
          roomNames: const <String>[],
          houseLine: '#3A3046',
          snow: true,
          snowman: true);
      expect(legacy, contains('viewBox="$houseViewBoxLegacy"'));
      expect(legacy.contains('#BFD6E6'), isFalse);
    });

    test('spots and previews are inside the house and safe', () {
      final house = houseOrigin & houseSize;
      expect(house.contains(snowmanSpot), isTrue);
      for (var d = 0; d < chestDecorCount; d++) {
        expect(house.contains(chestDecorSpot(d)), isTrue);
        expectFlutterSvgSafe(chestDecorPreviewSvg(d));
      }
      expectFlutterSvgSafe(snowmanPreviewSvg());
      expect(snowmanPreviewSvg(locked: true), contains('opacity="0.35"'));
      for (final ri in <int>[10, 11, 12]) {
        final r = rooms[ri];
        expect(house.contains(Offset(r.x, r.y)) && house.contains(Offset(r.x + 150, r.y + 160)), isTrue);
      }
      // the new rooms do not overlap the old ones
      for (final a in <int>[10, 11, 12]) {
        for (var b = 0; b < rooms.length; b++) {
          if (a == b) {
            continue;
          }
          final ra = Rect.fromLTWH(rooms[a].x, rooms[a].y, 150, 160);
          final rb = Rect.fromLTWH(rooms[b].x, rooms[b].y, 150, 160);
          expect(ra.deflate(1).overlaps(rb.deflate(1)), isFalse, reason: '$a / $b');
        }
      }
    });
  });

  group('winter event', () {
    test('window 1 December to 15 January, across the year change', () {
      expect(winterActive(DateTime(2026, 11, 30, 23, 59)), isFalse);
      expect(winterActive(DateTime(2026, 12, 1)), isTrue);
      expect(winterActive(DateTime(2026, 12, 31, 23, 59)), isTrue);
      expect(winterActive(DateTime(2027, 1, 1)), isTrue);
      expect(winterActive(DateTime(2027, 1, 15, 23, 59)), isTrue);
      expect(winterActive(DateTime(2027, 1, 16)), isFalse);
      expect(winterActive(DateTime(2027, 7, 1)), isFalse);
      expect(snowOnHouse(DateTime(2026, 12, 24)), isTrue);
      expect(snowOnHouse(DateTime(2026, 6, 24)), isFalse);
      expect(winterSeasonOf(DateTime(2026, 12, 20)), 2026);
      expect(winterSeasonOf(DateTime(2027, 1, 10)), 2026);
      expect(winterSeasonOf(DateTime(2027, 12, 2)), 2027);
      expect(winterDaysLeft(DateTime(2026, 12, 1)), 46);
      expect(winterDaysLeft(DateTime(2027, 1, 15, 22)), 1);
      expect(winterDaysLeft(DateTime(2027, 1, 16)), 0);
    });

    test('seven tidy winter boxes', () {
      expect(winterLevels.length, winterLevelCount);
      expect(winterLevelCount, 7);
      for (var i = 0; i < winterLevels.length; i++) {
        final l = winterLevels[i];
        expect(l.slots.length, inInclusiveRange(9, 12));
        expect(l.drawers, isEmpty);
        expect(l.mystery, isFalse);
        _expectTidy(l, 'winter $i');
      }
      expect(winterLevel(-3), winterLevels.first);
      expect(winterLevel(99), winterLevels.last);
    });

    test('progress: seasons, the snowman and its keeping', () {
      final p = Progress(done: <int>{0});
      final dec = DateTime(2026, 12, 5);
      expect(p.winterAvailable(dec), isTrue);
      expect(Progress().winterAvailable(dec), isFalse, reason: 'needs a done level');
      expect(p.winterAvailable(DateTime(2026, 11, 5)), isFalse);
      expect(p.winterNext(dec), 0);
      var calls = 0;
      p.addListener(() => calls++);
      for (var i = 0; i < 6; i++) {
        final r = p.completeWinter(i, dec);
        expect(r.fresh, isTrue);
        expect(r.snowman, isFalse);
      }
      expect(p.completeWinter(2, dec).fresh, isFalse);
      expect(p.winterDoneCount(dec), 6);
      expect(p.winterNext(dec), 6);
      final last = p.completeWinter(6, DateTime(2027, 1, 16, 0, 5)); // opened on the 15th
      expect(last.fresh, isTrue);
      expect(last.snowman, isTrue);
      expect(p.snowman, isTrue);
      expect(p.winterNext(dec), -1);
      expect(calls, 8);
      expect(p.completeWinter(7, dec).fresh, isFalse);
      // next winter: boxes start over, the snowman stays
      final next = DateTime(2027, 12, 3);
      expect(p.winterDoneCount(next), 0);
      expect(p.winterBoxDone(0, next), isFalse);
      final r = p.completeWinter(0, next);
      expect(r.fresh && !r.snowman, isTrue);
      expect(p.snowman, isTrue);
      expect(p.winterSeason, 2027);
      p.reset();
      expect(p.snowman, isTrue, reason: 'seasonal keepsake');
      expect(p.winterDone, isEmpty);
    });
  });

  group('daily tasks', () {
    test('generation is deterministic, three different possible tasks', () {
      const ctx = TaskContext(hasDone: true, bonusUnlocked: true, mysteryReachable: true);
      final sets = <String>{};
      for (var d = 1; d <= 30; d++) {
        final day = dayString(DateTime(2026, 11, d));
        final a = generateDailyTasks(day, ctx);
        final b = generateDailyTasks(day, ctx);
        expect(a.length, tasksPerDay);
        expect(a.map((t) => t.type).toList(), b.map((t) => t.type).toList());
        expect(a.map((t) => t.type).toSet().length, 3);
        for (final t in a) {
          expect(ctx.allows(t.type), isTrue);
          expect(t.target, t.type == TaskType.boxes ? inInclusiveRange(2, 3) : 1);
          expect(t.progress, 0);
        }
        sets.add(a.map((t) => t.type.name).join(','));
      }
      expect(sets.length >= 8, isTrue, reason: 'tasks vary by day');
      // a new player only gets tasks they can do
      const fresh = TaskContext();
      for (var d = 1; d <= 30; d++) {
        for (final t in generateDailyTasks(dayString(DateTime(2026, 12, d)), fresh)) {
          expect(<TaskType>[TaskType.boxes, TaskType.newLevel, TaskType.daily, TaskType.hint],
              contains(t.type));
        }
      }
      expect(TaskType.values.length, 10);
    });

    test('tasks are made once per day and kept when the clock goes back', () {
      final p = Progress(done: <int>{0, 1});
      final d1 = DateTime(2026, 11, 20, 9);
      final t1 = p.tasksFor(d1).map((t) => t.type).toList();
      expect(t1.length, 3);
      expect(p.taskDay, '2026-11-20');
      p.done.addAll(<int>{2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13});
      expect(p.tasksFor(DateTime(2026, 11, 20, 22)).map((t) => t.type).toList(), t1);
      expect(p.tasksFor(DateTime(2026, 11, 19)).map((t) => t.type).toList(), t1);
      p.tasksFor(DateTime(2026, 11, 21));
      expect(p.taskDay, '2026-11-21');
    });

    test('each task type is detected from the existing game calls', () {
      final day = DateTime(2026, 11, 20, 10);
      void check(TaskType type, void Function(Progress p) act, {Set<int>? done}) {
        final p = _withTasks(day, <TaskType>[type], done: done);
        final before = p.extraHints;
        act(p);
        expect(p.tasks.single.done, isTrue, reason: type.name);
        expect(p.extraHints, before, reason: '${type.name}: the hint waits for the claim');
        expect(p.takeCompletedTasks(), [0], reason: type.name);
        expect(p.takeCompletedTasks(), isEmpty);
        expect(p.canClaimTask(0, day), isTrue);
        expect(p.claimTask(0, day), isTrue);
        expect(p.extraHints, before + taskHintReward, reason: type.name);
        expect(p.claimTask(0, day), isFalse);
      }

      check(TaskType.newLevel, (p) => p.completeLevel(5));
      check(TaskType.replay, (p) => p.completeLevel(1));
      check(TaskType.daily, (p) => p.completeDaily(day));
      check(TaskType.bonus, (p) => p.completeBonus());
      check(TaskType.style, (p) => p.setStyle(1, 1));
      check(TaskType.hint, (p) => p.useFreeHint(day));
      check(TaskType.mystery, (p) => p.completeLevel(21));
      check(TaskType.mystery, (p) {
        p.bonusDone = 6; // bonus box 6 is a mystery box
        p.completeBonus();
      });
      check(TaskType.drawer, (p) => p.completeLevel(30));
      check(TaskType.winter, (p) => p.completeWinter(0, day));
      check(TaskType.boxes, (p) {
        p.completeLevel(1);
        p.completeWinter(0, day);
      });
    });

    test('a style set to the same value or a refused hint does not count', () {
      final day = DateTime(2026, 11, 20);
      final p = _withTasks(day, <TaskType>[TaskType.style, TaskType.hint]);
      p.setStyle(1, 0);
      p.setStyle(1, 2); // not available
      expect(p.tasks[0].done, isFalse);
      for (var i = 0; i < freeHintsPerDay; i++) {
        p.useFreeHint(day);
      }
      p.extraHints = 0;
      p.tasks[1].progress = 0;
      expect(p.useFreeHint(day), isFalse);
      expect(p.tasks[1].done, isFalse);
    });

    test('three done tasks fill one chest step per day; doubling once', () {
      final day = DateTime(2026, 11, 20);
      final p = _withTasks(day, <TaskType>[TaskType.boxes, TaskType.style, TaskType.hint]);
      p.completeLevel(1);
      expect(p.tasks[0].progress, 1);
      expect(p.tasks[0].done, isFalse);
      p.completeLevel(2);
      p.setStyle(1, 1);
      expect(p.chestSteps, 0);
      expect(p.tasksAllDone(day), isFalse);
      expect(p.takeChestStepEarned(), isFalse);
      p.useFreeHint(day);
      expect(p.tasksAllDone(day), isTrue);
      expect(p.chestSteps, 1);
      expect(p.chestDay, '2026-11-20');
      expect(p.takeChestStepEarned(), isTrue);
      expect(p.takeChestStepEarned(), isFalse);
      expect(p.takeCompletedTasks(), [0, 1, 2]);
      // more actions the same day change nothing
      p.completeLevel(3);
      expect(p.chestSteps, 1);
      // task_double: once per task, only for finished tasks; twice the hint
      var hints = p.extraHints;
      expect(p.canDoubleTask(1, day), isTrue);
      expect(p.doubleTask(1, day), isTrue);
      expect(p.extraHints, hints + 2 * taskHintReward, reason: 'not claimed yet');
      expect(p.doubleTask(1, day), isFalse);
      expect(p.claimTask(1, day), isFalse);
      hints = p.extraHints;
      expect(p.claimTask(0, day), isTrue);
      expect(p.doubleTask(0, day), isTrue);
      expect(p.extraHints, hints + 2 * taskHintReward, reason: 'claim + double');
      expect(p.canDoubleTask(7, day), isFalse);
      expect(p.claimTask(-1, day), isFalse);
      final q = _withTasks(day, <TaskType>[TaskType.bonus]);
      expect(q.canDoubleTask(0, day), isFalse);
      expect(q.doubleTask(0, day), isFalse);
      expect(q.claimTask(0, day), isFalse);
    });

    test('unclaimed hints of finished tasks are given the next day', () {
      final day = DateTime(2026, 11, 20);
      final p = _withTasks(day, <TaskType>[TaskType.boxes, TaskType.hint, TaskType.style]);
      p.useFreeHint(day); // hint task done, not claimed
      p.setStyle(1, 1); // style task done
      p.claimTask(2, day);
      final hints = p.extraHints;
      p.tasksFor(DateTime(2026, 11, 21));
      expect(p.extraHints, hints + taskHintReward, reason: 'only the unclaimed one');
      expect(p.taskDay, '2026-11-21');
    });

    test('a full chest gives a 3rd style, then decor, then hints', () {
      final p = Progress(done: <int>{0, 1});
      expect(p.openTaskChest(), isNull);
      p.chestSteps = taskChestSteps;
      expect(p.taskChestReady, isTrue);
      var calls = 0;
      p.addListener(() => calls++);
      final a = p.openTaskChest()!;
      expect(a.kind, ChestRewardKind.style);
      expect(<int>{0, 1}, contains(a.value));
      expect(p.extraStyles, {a.value});
      expect(p.chestSteps, 0);
      expect(p.chestsOpened, 1);
      expect(calls, 1);
      p.chestSteps = taskChestSteps;
      final b = p.openTaskChest()!;
      expect(b.kind, ChestRewardKind.style);
      expect(p.extraStyles, {0, 1});
      // every 3rd style owned (here through the Supporter Pack): decor pieces
      final s = Progress(done: <int>{0, 1, 2}, supporter: true);
      for (var d = 0; d < chestDecorCount; d++) {
        s.chestSteps = taskChestSteps;
        expect(s.openTaskChest(), ChestReward(ChestRewardKind.decor, d));
      }
      expect(s.chestDecors, {0, 1, 2, 3});
      s.chestSteps = taskChestSteps;
      final hints = s.extraHints;
      expect(s.openTaskChest(), const ChestReward(ChestRewardKind.hints, chestBonusHints));
      expect(s.extraHints, hints + chestBonusHints);
    });

    test('the chest never goes past seven steps', () {
      final p = Progress(done: <int>{0});
      for (var d = 1; d <= 9; d++) {
        final day = DateTime(2026, 11, d);
        p.clock = () => day;
        p.taskDay = dayString(day);
        p.tasks = <DailyTask>[DailyTask(type: TaskType.boxes, target: 1)];
        p.completeLevel(0);
      }
      expect(p.chestSteps, taskChestSteps);
    });

    test('mechanic tip is marked once', () {
      final p = Progress();
      expect(p.markMechanicTipSeen(), isTrue);
      expect(p.markMechanicTipSeen(), isFalse);
      expect(p.mechanicTipSeen, isTrue);
    });
  });

  group('progress schema 4', () {
    test('a schema 3 save from 1.1 loads without loss', () {
      final old = jsonDecode(_schema3Fixture) as Map<String, dynamic>;
      final p = Progress.fromJsonString(_schema3Fixture);
      final out = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      for (final k in old.keys) {
        if (k == 'v') {
          continue;
        }
        expect(jsonEncode(out[k]), jsonEncode(old[k]), reason: k);
      }
      expect(out['v'], 4);
      expect(Progress.schemaVersion, 4);
      expect(p.styleOf(5), 2);
      expect(p.styleOf(21), 2);
      expect(p.styleOf(3), 1);
      expect(p.hintsUsedToday(DateTime(2026, 11, 14)), 2);
      expect(p.extraHints, 3);
      // the new fields start at their defaults
      expect(p.taskDay, '');
      expect(p.tasks, isEmpty);
      expect(p.chestSteps, 0);
      expect(p.chestDay, '');
      expect(p.chestsOpened, 0);
      expect(p.chestDecors, isEmpty);
      expect(p.winterSeason, 0);
      expect(p.winterDone, isEmpty);
      expect(p.snowman, isFalse);
      expect(p.mechanicTipSeen, isFalse);
      // and a second load of the migrated save is identical
      expect(Progress.fromJson(out).toJson(), p.toJson());
    });

    test('JSON round trip of every schema 4 field', () {
      final day = DateTime(2026, 12, 3);
      final p = _withTasks(day, <TaskType>[TaskType.boxes, TaskType.winter, TaskType.style]);
      p.completeWinter(1, day);
      p.completeWinter(4, day);
      p.chestSteps = 5;
      p.chestDay = '2026-12-02';
      p.chestsOpened = 2;
      p.chestDecors.addAll(<int>{0, 2});
      p.snowman = true;
      p.markMechanicTipSeen();
      p.doubleTask(0, day);
      final q = Progress.fromJsonString(jsonEncode(p.toJson()));
      expect(q.toJson(), p.toJson());
      expect(q.taskDay, '2026-12-03');
      expect(q.tasks.map((t) => t.type).toList(), [TaskType.boxes, TaskType.winter, TaskType.style]);
      expect(q.tasks[0].done && q.tasks[0].doubled && q.tasks[0].claimed, isTrue);
      expect(q.tasks[1].claimed, isFalse);
      expect(q.tasks[1].done, isTrue);
      expect(q.tasks[2].progress, 0);
      expect(q.winterSeason, 2026);
      expect(q.winterDone, {1, 4});
      expect(q.chestSteps, 5);
      expect(q.chestDecors, {0, 2});
      expect(q.snowman && q.mechanicTipSeen, isTrue);
    });

    test('bad schema 4 values fall back', () {
      final p = Progress.fromJsonString(
          '{"v":4,"tasks":{"day":"today","list":[{"t":"boxes"}]},"chestSteps":99,'
          '"chestDay":5,"chestsOpened":-1,"chestDecors":[1,9,"x",-2],'
          '"winter":{"season":2026,"done":[0,3,8,"y"]},"snowman":"yes","mechanicTipSeen":1}');
      expect(p.taskDay, '');
      expect(p.tasks, isEmpty);
      expect(p.chestSteps, taskChestSteps);
      expect(p.chestDay, '');
      expect(p.chestsOpened, 0);
      expect(p.chestDecors, {1});
      expect(p.winterDone, {0, 3});
      expect(p.snowman, isFalse);
      expect(p.mechanicTipSeen, isFalse);
      final t = Progress.fromJsonString(
          '{"tasks":{"day":"2026-11-20","list":[{"t":"nope"},{"t":"hint","n":0,"p":7,"x":true},5]}}');
      expect(t.tasks.length, 1);
      expect(t.tasks.single.type, TaskType.hint);
      expect(t.tasks.single.target, 1);
      expect(t.tasks.single.progress, 1);
      expect(t.tasks.single.doubled, isTrue);
    });

    test('reset clears tasks, chest and winter boxes but keeps the snowman', () {
      final p = _withTasks(DateTime(2026, 12, 3), <TaskType>[TaskType.boxes]);
      p.chestSteps = 3;
      p.chestDecors.add(1);
      p.completeWinter(0, DateTime(2026, 12, 3));
      p.snowman = true;
      p.markMechanicTipSeen();
      p.reset();
      expect(p.tasks, isEmpty);
      expect(p.taskDay, '');
      expect(p.chestSteps, 0);
      expect(p.chestDecors, isEmpty);
      expect(p.winterDone, isEmpty);
      expect(p.snowman, isTrue);
      expect(p.mechanicTipSeen, isTrue);
    });
  });
}
