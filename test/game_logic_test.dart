import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidy_nook/game/art.dart';
import 'package:tidy_nook/game/board_logic.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/progress.dart';

void main() {
  group('progress: levels', () {
    test('fresh progress', () {
      final p = Progress();
      expect(p.lang, isNull);
      expect(p.sound, isTrue);
      expect(p.level, 0);
      expect(p.done, isEmpty);
      expect(p.unlocked, 0);
      expect(p.nextOpen, 0);
      expect(p.styleOf(3), 0);
    });

    test('unlocked and nextOpen follow the HTML', () {
      final p = Progress(done: <int>{0, 1, 2, 4});
      // the first three are done in a row, level 4 unlocks level 5
      expect(p.unlocked, 5);
      expect(p.nextOpen, 3);
      p.done.add(3);
      expect(p.unlocked, 5);
      expect(p.nextOpen, 5);
      final all = Progress(done: <int>{for (var i = 0; i < levels.length; i++) i});
      expect(all.unlocked, levels.length - 1);
      expect(all.nextOpen, -1);
    });

    test('completeLevel reports only new levels', () {
      final p = Progress();
      expect(p.completeLevel(0), 0);
      expect(p.completeLevel(0), -1);
      expect(p.done, {0});
      expect(p.completeLevel(99), -1);
    });

    test('roomComplete needs every level of the room', () {
      final p = Progress();
      expect(levelsOfRoom(0), [0, 3, 6, 7]);
      p.completeLevel(0);
      p.completeLevel(3);
      p.completeLevel(6);
      expect(p.roomComplete(0), isFalse);
      p.completeLevel(7);
      expect(p.roomComplete(0), isTrue);
      expect(p.roomComplete(1), isFalse);
    });

    test('styles', () {
      final p = Progress();
      p.setStyle(2, 1);
      expect(p.styleOf(2), 1);
      p.setStyle(2, 0);
      expect(p.styleOf(2), 0);
    });

    test('reset keeps language and sound', () {
      final p = Progress(lang: 'de', sound: false, level: 5, done: <int>{1, 2});
      p.setStyle(1, 1);
      p.completeDaily(DateTime(2026, 11, 7));
      p.reset();
      expect(p.done, isEmpty);
      expect(p.styles, isEmpty);
      expect(p.level, 0);
      expect(p.daily.total, 0);
      expect(p.daily.last, '');
      expect(p.lang, 'de');
      expect(p.sound, isFalse);
    });

    test('listeners are notified', () {
      final p = Progress();
      var calls = 0;
      p.addListener(() => calls++);
      p.completeLevel(1);
      p.setStyle(1, 1);
      expect(calls, 2);
    });
  });

  group('progress: daily streak', () {
    test('first box starts the streak at 1', () {
      final p = Progress();
      final now = DateTime(2026, 11, 7, 9, 30);
      expect(p.dailyDoneToday(now), isFalse);
      expect(p.liveStreak(now), 0);
      p.completeDaily(now);
      expect(p.daily.streak, 1);
      expect(p.daily.total, 1);
      expect(p.daily.last, '2026-11-07');
      expect(p.dailyDoneToday(now), isTrue);
      expect(p.liveStreak(now), 1);
    });

    test('consecutive day adds one, also across a month change', () {
      final p = Progress();
      p.completeDaily(DateTime(2026, 10, 31));
      p.completeDaily(DateTime(2026, 11, 1));
      expect(p.daily.streak, 2);
      p.completeDaily(DateTime(2026, 11, 2));
      expect(p.daily.streak, 3);
      expect(p.daily.total, 3);
    });

    test('a gap resets the streak to 1', () {
      final p = Progress();
      p.completeDaily(DateTime(2026, 11, 1));
      p.completeDaily(DateTime(2026, 11, 2));
      expect(p.daily.streak, 2);
      p.completeDaily(DateTime(2026, 11, 4));
      expect(p.daily.streak, 1);
      expect(p.daily.total, 3);
    });

    test('the same day again changes nothing', () {
      final p = Progress();
      p.completeDaily(DateTime(2026, 11, 7, 8));
      final again = p.completeDaily(DateTime(2026, 11, 7, 22));
      expect(again, -1);
      expect(p.daily.streak, 1);
      expect(p.daily.total, 1);
      expect(p.daily.days, ['2026-11-07']);
    });

    test('liveStreak stays alive until the day after, then drops', () {
      final p = Progress();
      p.completeDaily(DateTime(2026, 11, 6));
      p.completeDaily(DateTime(2026, 11, 7));
      expect(p.liveStreak(DateTime(2026, 11, 7)), 2);
      expect(p.liveStreak(DateTime(2026, 11, 8)), 2);
      expect(p.liveStreak(DateTime(2026, 11, 9)), 0);
      expect(p.dailyDoneToday(DateTime(2026, 11, 8)), isFalse);
    });

    test('keeps only the last 30 days', () {
      final p = Progress();
      for (var i = 0; i < 40; i++) {
        p.completeDaily(DateTime(2026, 1, 1 + i));
      }
      expect(p.daily.days.length, 30);
      expect(p.daily.total, 40);
      expect(p.daily.streak, 40);
      expect(p.daily.days.last, '2026-02-09');
    });

    test('milestone pets at 3, 7, 14, 21 and 30', () {
      final p = Progress();
      final earned = <int, int>{};
      for (var i = 1; i <= 31; i++) {
        final pet = p.completeDaily(DateTime(2026, 3, i));
        if (pet >= 0) {
          earned[i] = pet;
        }
      }
      expect(earned, {3: 0, 7: 1, 14: 2, 21: 3, 30: 4});
    });
  });

  group('progress: daily robustness', () {
    Progress withLast(String last, int streak, {int total = 5}) =>
        Progress(daily: DailyState(last: last, streak: streak, total: total));

    test('explicit day: opened 23:59, finished 00:01 credits the opening day',
        () {
      final p = withLast('2026-11-06', 2);
      final pet = p.completeDaily(DateTime(2026, 11, 8, 0, 1), day: '2026-11-07');
      expect(pet, -1); // total 6 is no milestone
      expect(p.daily.last, '2026-11-07');
      expect(p.daily.streak, 3);
      expect(p.daily.total, 6);
      expect(p.daily.days.last, '2026-11-07');
      // after midnight the next box is offered and keeps the streak alive
      final later = DateTime(2026, 11, 8, 0, 1);
      expect(p.dailyDoneToday(later), isFalse);
      expect(p.liveStreak(later), 3);
      p.completeDaily(DateTime(2026, 11, 8, 9));
      expect(p.daily.streak, 4);
    });

    test('explicit day: a malformed day falls back to now', () {
      final p = Progress();
      p.completeDaily(DateTime(2026, 11, 7, 12), day: 'garbage');
      expect(p.daily.last, '2026-11-07');
    });

    test('clock set back one day: no reset and no double count', () {
      final p = withLast('2026-11-07', 4);
      final back = DateTime(2026, 11, 6, 10);
      expect(p.dailyDoneToday(back), isTrue);
      expect(p.liveStreak(back), 4);
      expect(p.completeDaily(back), -1);
      expect(p.daily.streak, 4);
      expect(p.daily.total, 5);
      expect(p.daily.last, '2026-11-07');
      expect(p.daily.days, isEmpty);
    });

    test('travelling west (last = tomorrow) keeps the streak', () {
      // finished 00:30 on the 8th in Istanbul, now 17:30 on the 7th in New York
      final p = withLast('2026-11-08', 13, total: 13);
      final ny = DateTime(2026, 11, 7, 17, 30);
      expect(p.dailyDoneToday(ny), isTrue);
      expect(p.liveStreak(ny), 13);
      expect(p.completeDaily(ny), -1);
      expect(p.daily.streak, 13);
      expect(p.daily.total, 13);
      // the next real day continues the streak
      p.completeDaily(DateTime(2026, 11, 9, 8));
      expect(p.daily.streak, 14);
    });

    test('explicit day older than last changes nothing', () {
      final p = withLast('2026-11-07', 2);
      expect(p.completeDaily(DateTime(2026, 11, 8), day: '2026-11-06'), -1);
      expect(p.daily.streak, 2);
      expect(p.daily.total, 5);
    });

    test('streak survives the DST change weeks', () {
      for (final start in <DateTime>[
        DateTime(2026, 3, 1), // EU change on 29 March, US on 8 March
        DateTime(2026, 10, 18), // EU change on 25 October
        DateTime(2026, 10, 25), // US change on 1 November
      ]) {
        final p = Progress();
        for (var i = 0; i < 21; i++) {
          p.completeDaily(DateTime(start.year, start.month, start.day + i, 0, 30));
        }
        expect(p.daily.streak, 21, reason: 'from $start');
        expect(p.daily.total, 21);
        final end = DateTime(start.year, start.month, start.day + 21, 23, 30);
        expect(p.liveStreak(end), 21);
      }
    });
  });

  group('progress: json', () {
    test('saves carry the schema version and files without it still load', () {
      expect(Progress().toJson()['v'], 3);
      final p = Progress.fromJsonString('{"level":3,"done":[0]}');
      expect(p.level, 3);
      expect(p.done, {0});
      final v2 = Progress.fromJsonString(jsonEncode(Progress(level: 2).toJson()));
      expect(v2.level, 2);
    });

    test('corrupt text is handed back for a backup, good or empty is not', () {
      final bad = Progress.parseSaved('{"level": 3,');
      expect(bad.corruptRaw, '{"level": 3,');
      expect(bad.progress.done, isEmpty);
      expect(Progress.parseSaved('[1,2]').corruptRaw, '[1,2]');
      expect(Progress.parseSaved('"text"').corruptRaw, '"text"');
      expect(Progress.parseSaved(null).corruptRaw, isNull);
      expect(Progress.parseSaved('').corruptRaw, isNull);
      final ok = Progress.parseSaved('{"level":4}');
      expect(ok.corruptRaw, isNull);
      expect(ok.progress.level, 4);
      expect(Progress.corruptKey, 'tidynook-v1-corrupt');
    });

    const webSave =
        '{"lang":"de","level":4,"done":[0,1,2,4],"sound":false,'
        '"styles":{"3":1,"0":1},'
        '"daily":{"last":"2026-11-06","streak":2,"total":5,'
        '"days":["2026-11-05","2026-11-06"]}}';

    test('reads the web save', () {
      final p = Progress.fromJsonString(webSave);
      expect(p.lang, 'de');
      expect(p.level, 4);
      expect(p.done, {0, 1, 2, 4});
      expect(p.sound, isFalse);
      expect(p.styleOf(3), 1);
      expect(p.styleOf(0), 1);
      expect(p.styleOf(1), 0);
      expect(p.daily.last, '2026-11-06');
      expect(p.daily.streak, 2);
      expect(p.daily.total, 5);
      expect(p.daily.days, ['2026-11-05', '2026-11-06']);
    });

    test('round trip keeps the web shape', () {
      final p = Progress.fromJsonString(webSave);
      final out = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      // the web keys are unchanged; schema 3 adds its own keys with defaults
      final web = jsonDecode(webSave) as Map<String, dynamic>;
      for (final k in web.keys) {
        expect(out[k], web[k], reason: k);
      }
      expect(out['v'], 3);
      expect(out.keys.toSet(), {
        'v', 'lang', 'level', 'done', 'sound', 'styles', 'daily', //
        'extraStyles', 'adsRemoved', 'supporter', 'bonusDone', 'vibration',
        'reminderOn', 'reminderAsked', 'reviewAsked', 'adCounter', 'lastAdMs',
        'streakSaveDay', 'hintDay', 'hintsUsed', 'extraHints',
      });
      expect((out['styles'] as Map).keys.toSet(), {'3', '0'});
      final again = Progress.fromJson(out);
      expect(again.toJson(), p.toJson());
    });

    test('done keeps its order', () {
      final p = Progress();
      p.completeLevel(5);
      p.completeLevel(2);
      p.completeLevel(9);
      expect(p.toJson()['done'], [5, 2, 9]);
    });

    test('old saves without daily and bad data load safely', () {
      final p = Progress.fromJsonString(
          '{"lang":"xx","level":99,"done":[1,"x",null,2,2,500],"styles":{"a":1}}');
      expect(p.lang, isNull);
      expect(p.level, levels.length - 1);
      expect(p.done, {1, 2});
      expect(p.styles, isEmpty);
      expect(p.daily.total, 0);
      expect(p.daily.days, isEmpty);
      expect(Progress.fromJsonString('not json').done, isEmpty);
      expect(Progress.fromJsonString(null).sound, isTrue);
      expect(Progress.fromJsonString('[1,2]').done, isEmpty);
    });

    test('storage key matches the web game', () {
      expect(Progress.storageKey, 'tidynook-v1');
    });
  });

  group('board logic', () {
    test('scatter puts one item per slot on the rug', () {
      for (var li = 0; li < levels.length; li++) {
        final level = levels[li];
        final items = scatter(level, math.Random(li));
        expect(items.length, level.slots.length);
        for (var i = 0; i < items.length; i++) {
          final it = items[i];
          expect(it.id, i);
          expect(it.kind, level.slots[i].kind);
          expect(it.placed, isFalse);
          expect(it.scale, 1);
          expect(it.x, inInclusiveRange(14 + 83 / 2 - 6, 346 - 83 / 2 + 6));
          expect(it.y, inInclusiveRange(364, 626));
          expect(it.home, Offset(it.x, it.y));
        }
      }
    });

    test('scatter keeps every rotated item box inside the rug', () {
      for (var li = 0; li < levels.length; li++) {
        final level = levels[li];
        for (var seed = 0; seed < 200; seed++) {
          final items = scatter(level, math.Random(seed));
          for (final it in items) {
            final ext = rotatedExtent(itemBox(it.kind), it.rotation);
            final reason = 'level $li seed $seed item ${it.id} ${it.kind}';
            expect(it.x + ext.left, greaterThanOrEqualTo(14 + 6 - 1e-6),
                reason: reason);
            expect(it.x + ext.right, lessThanOrEqualTo(346 - 6 + 1e-6),
                reason: reason);
            expect(it.y + ext.top, greaterThanOrEqualTo(364 + 6 - 1e-6),
                reason: reason);
            expect(it.y + ext.bottom, lessThanOrEqualTo(626 - 6 + 1e-6),
                reason: reason);
            expect(it.home, Offset(it.x, it.y));
          }
        }
      }
    });

    test('rotatedExtent of a quarter turn swaps width and height', () {
      final e = rotatedExtent(const Rect.fromLTRB(-10, -30, 10, 30), 90);
      expect(e.width, closeTo(60, 1e-9));
      expect(e.height, closeTo(20, 1e-9));
    });

    test('rotation rules: tall items lie down, others tilt', () {
      // level 4 (bookshelf) has books of 78..104 high
      final level = levels[4];
      for (var seed = 0; seed < 20; seed++) {
        final items = scatter(level, math.Random(seed));
        for (final it in items) {
          final a = it.rotation.abs();
          if (level.slots[it.id].kind == 'book3') {
            // 78 high: not tall
            expect(a, lessThanOrEqualTo(28));
          } else {
            expect(a, inInclusiveRange(62, 84));
          }
        }
      }
    });

    test('findSnap takes the nearest free slot of the same kind within 54', () {
      final slots = makeSlots(levels[0]); // six eggs
      final near = findSnap(slots, 'egg', 130, 160);
      expect(near, isNotNull);
      expect(near!.id, 0);
      expect(findSnap(slots, 'egg', 200, 150)!.id, 1);
      // too far from every slot
      expect(findSnap(slots, 'egg', 330, 40), isNull);
      // exactly 54 away is not enough
      expect(findSnap(slots, 'egg', 110 - 54, 150), isNull);
      expect(findSnap(slots, 'egg', 110 - 53.9, 150)!.id, 0);
      // wrong kind
      expect(findSnap(slots, 'milk', 110, 150), isNull);
      // filled slots are skipped
      slots[0].filled = true;
      expect(findSnap(slots, 'egg', 110, 150), isNull);
      expect(findSnap(slots, 'egg', 140, 150)!.id, 1);
      slots[1].filled = true;
      expect(findSnap(slots, 'egg', 140, 150), isNull);
    });

    test('isAboveRug and clampToRug', () {
      expect(isAboveRug(351.9), isTrue);
      expect(isAboveRug(352), isFalse);
      expect(clampToRug(0, 0), const Offset(30, 380));
      expect(clampToRug(500, 900), const Offset(330, 610));
      expect(clampToRug(100, 500), const Offset(100, 500));
    });

    test('pickHint returns a free item and its nearest free slot', () {
      final level = levels[1]; // pencils and an eraser, all different kinds
      final slots = makeSlots(level);
      final items = scatter(level, math.Random(1));
      final hint = pickHint(items, slots, math.Random(2));
      expect(hint, isNotNull);
      expect(hint!.item.placed, isFalse);
      expect(hint.slot.slot.kind, hint.item.kind);
      expect(hint.slot.id, hint.item.id);
    });

    test('pickHint skips placed items and filled slots', () {
      final level = levels[0]; // six eggs
      final slots = makeSlots(level);
      final items = scatter(level, math.Random(3));
      for (var i = 0; i < 5; i++) {
        items[i].placed = true;
        slots[i].filled = true;
      }
      for (var k = 0; k < 10; k++) {
        final hint = pickHint(items, slots, math.Random(k))!;
        expect(hint.item.id, 5);
        expect(hint.slot.id, 5);
      }
      items[5].placed = true;
      slots[5].filled = true;
      expect(pickHint(items, slots, math.Random(0)), isNull);
    });

    test('pickHint chooses the nearest of several matching slots', () {
      final slots = makeSlots(levels[0]);
      final item = ItemState(
        id: 0,
        kind: 'egg',
        x: 245,
        y: 245,
        home: const Offset(245, 245),
      );
      final hint = pickHint(<ItemState>[item], slots, math.Random(0))!;
      expect(hint.slot.id, 5); // egg slot at (250, 250)
    });
  });
}
