import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidy_nook/game/art.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/daily.dart';
import 'package:tidy_nook/game/progress.dart';

import 'game_data_test.dart' show expectFlutterSvgSafe;

const Rect _inside = Rect.fromLTRB(42, 72, 318, 328);

List<Rect> _slotBoxes(Level l) => <Rect>[
      for (final s in l.slots) itemGeometryBox(s.kind).shift(Offset(s.x, s.y)),
    ];

void _expectTidyLayout(Level l, String name) {
  final boxes = _slotBoxes(l);
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

void _expectNoLookAlikes(Level l, String name) {
  final ks = l.slots.map((s) => s.kind).toSet().toList();
  for (var a = 0; a < ks.length; a++) {
    for (var b = a + 1; b < ks.length; b++) {
      expect(kindsLookAlike(ks[a], ks[b]), isFalse,
          reason: '$name: ${ks[a]} and ${ks[b]} have the same silhouette');
    }
  }
}

double _lum(String hex) {
  double ch(int v) {
    final c = v / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  final v = int.parse(hex.substring(1), radix: 16);
  return 0.2126 * ch((v >> 16) & 255) + 0.7152 * ch((v >> 8) & 255) + 0.0722 * ch(v & 255);
}

double _ratio(double a, double b) =>
    (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);

/// The UI's room label pill: black at 50% over the floor colour.
String _pillOver(String hex) {
  final v = int.parse(hex.substring(1), radix: 16);
  String h(int c) => (c / 2).round().toRadixString(16).padLeft(2, '0');
  return '#${h((v >> 16) & 255)}${h((v >> 8) & 255)}${h(v & 255)}';
}

Set<String> _fills(String svg) => RegExp(r'fill="([^"]*)"')
    .allMatches(svg)
    .map((m) => m[1]!)
    .toSet();

void main() {
  group('1.1 levels', () {
    test('new levels are tidy: inside the box, no overlaps, 9-12 items', () {
      for (var i = 18; i < levels.length; i++) {
        final l = levels[i];
        expect(l.slots.length, inInclusiveRange(9, 12), reason: 'level $i');
        _expectTidyLayout(l, 'level $i');
      }
    });

    test('item counts step up gently', () {
      for (var i = 19; i < levels.length; i++) {
        expect(levels[i].slots.length >= levels[i - 1].slots.length, isTrue,
            reason: 'level $i');
      }
    });

    test('rooms: attic 6, 7 and garden 8, 9 hold three levels each', () {
      expect(levelsOfRoom(6), [18, 19, 20]);
      expect(levelsOfRoom(7), [21, 22, 23]);
      expect(levelsOfRoom(8), [24, 25, 26]);
      expect(levelsOfRoom(9), [27, 28, 29]);
      expect(atticRooms, [6, 7]);
      expect(gardenRooms, [8, 9]);
    });

    test('mystery levels are 22, 25, 28 and 30 (indexes 21, 24, 27, 29)', () {
      final m = <int>[
        for (var i = 0; i < levels.length; i++)
          if (levels[i].mystery) i,
      ];
      expect(m, [21, 24, 27, 29]);
      for (final i in m) {
        _expectNoLookAlikes(levels[i], 'level $i');
      }
      expect(dailyLevel('2026-11-11').mystery, isFalse);
    });

    test('look-alike families differ by shape, not only colour', () {
      for (final fam in <List<String>>[
        ['spool-rose', 'spool-sky', 'spool-sun'],
        ['yarn-rose', 'yarn-sky', 'yarn-sun'],
        ['tea-mint', 'tea-rose', 'tea-sun'],
        ['hl-sun', 'hl-mint', 'hl-rose'],
      ]) {
        for (final k in fam) {
          expect(kinds.containsKey(k), isTrue, reason: k);
        }
        // same outline, so they are look-alikes and never share a mystery box
        expect(kindsLookAlike(fam[0], fam[1]), isTrue);
        expect(kinds[fam[0]]!.prims.length == kinds[fam[1]]!.prims.length &&
                kinds[fam[1]]!.prims.length == kinds[fam[2]]!.prims.length,
            isFalse,
            reason: '${fam[0]}: each member has its own pattern');
      }
    });
  });

  group('mystery ghosts', () {
    test('neutral grey silhouette, no colours, no patterns', () {
      for (final id in kinds.keys) {
        final g = ghostSvg(id, mystery: true);
        expectFlutterSvgSafe(g);
        expect(_fills(g), <String>{mysteryGhostRim, mysteryGhostFill},
            reason: id);
        expect(g.contains('stroke-dasharray'), isFalse);
        final box = itemBox(id);
        expect(
            g,
            contains('viewBox="${fmtNum(box.left)} ${fmtNum(box.top)} '
                '${fmtNum(box.width)} ${fmtNum(box.height)}"'));
        // the normal ghost is unchanged
        expect(ghostSvg(id), isNot(g));
        expect(ghostSvg(id, mystery: false), ghostSvg(id));
      }
    });
  });

  group('furniture and house', () {
    test('three styles per piece, all different', () {
      for (var i = 0; i < decorCount; i++) {
        final a = decorSvg(i, 0);
        final b = decorSvg(i, 1);
        final c = decorSvg(i, 2);
        expect(b, isNot(a), reason: 'piece $i');
        expect(c, isNot(a), reason: 'piece $i');
        expect(c, isNot(b), reason: 'piece $i');
        expect(decorSvg(i, 7), a);
        expect(decorSvg(i, -1), a);
        for (var v = 0; v < styleCount; v++) {
          expectFlutterSvgSafe(decorPreviewSvg(i, v));
        }
      }
    });

    test('hit rects, labels and pet spots are inside the 1.1 house', () {
      final house = houseOrigin & houseSize;
      for (var i = 0; i < decorCount; i++) {
        final r = decorHitRect(i);
        expect(r.width >= 40 && r.height >= 40, isTrue, reason: 'piece $i');
        expect(house.contains(r.center), isTrue, reason: 'piece $i');
        final room = rooms[levelRoom[i]];
        expect(Rect.fromLTWH(room.x, room.y, 150, 160).contains(r.center),
            isTrue,
            reason: 'piece $i is in its room');
      }
      for (var ri = 0; ri < rooms.length; ri++) {
        expect(house.contains(roomLabelCenter(ri)), isTrue, reason: 'room $ri');
      }
      for (var p = 0; p < petCount; p++) {
        expect(petSpots(p), isNotEmpty);
        for (final o in petSpots(p)) {
          expect(house.contains(o), isTrue, reason: 'pet $p');
        }
      }
      expect(petSpots(2), const [Offset(28, 410), Offset(332, 410)]);
      expect(petRoom(supporterPet), 8);
      expect(houseViewBox, '10 -306 340 912');
      expect(houseViewBoxLegacy, '10 -146 340 574');
    });

    test('extended house: attic, garden, pets and the puppy', () {
      final all = <int>{for (var i = 0; i < levels.length; i++) i};
      final styles = <int, int>{for (var i = 0; i < levels.length; i++) i: i % 3};
      String h({bool puppy = false, bool extended = true, int total = 30}) =>
          houseSvg(
            done: all,
            styles: styles,
            dailyTotal: total,
            roomNames: const <String>[],
            houseLine: '#3A3046',
            puppy: puppy,
            extended: extended,
          );
      final full = h(puppy: true);
      expectFlutterSvgSafe(full);
      expect(full, contains('viewBox="$houseViewBox"'));
      expect(full, contains(decorSvg(29, 2)));
      expect(full, contains(decorSvg(18, 0)));
      expect(h().length < full.length, isTrue, reason: 'puppy adds art');
      expect(h(total: 20).length < h(total: 30).length, isTrue);
      final empty = houseSvg(
          done: <int>{},
          styles: const <int, int>{},
          dailyTotal: 0,
          roomNames: const <String>[],
          houseLine: 'rgba(255,255,255,.8)',
          extended: true);
      expectFlutterSvgSafe(empty);

      // the 1.0 frame by default: no attic, no garden strip, no new pets
      final legacy = h(puppy: true, extended: false);
      expectFlutterSvgSafe(legacy);
      expect(legacy, contains('viewBox="$houseViewBoxLegacy"'));
      expect(legacy.contains(decorSvg(18, 0)), isFalse);
      expect(legacy.contains('-298'), isFalse);
      expect(legacy, contains(decorSvg(17, 2)));
    });

    test('room label pills stand out from every floor (WCAG)', () {
      for (var ri = 0; ri < rooms.length; ri++) {
        final floor = _lum(rooms[ri].floor);
        final pill = _lum(_pillOver(rooms[ri].floor));
        expect(_ratio(pill, floor) >= 3.0, isTrue,
            reason: 'room $ri pill/floor ${_ratio(pill, floor)}');
        expect(_ratio(1.0, pill) >= 4.5, isTrue, reason: 'room $ri text');
      }
    });

    test('pet previews for all six pets', () {
      for (var p = 0; p < petCount; p++) {
        expectFlutterSvgSafe(petPreviewSvg(p, locked: false));
        expect(petPreviewSvg(p, locked: true), contains('opacity="0.35"'));
      }
    });
  });

  group('bonus boxes', () {
    test('deterministic, ramped, tidy', () {
      var lastKinds = 0;
      var lastItems = 0;
      for (var n = 0; n < 300; n++) {
        final l = bonusLevel(n);
        final again = bonusLevel(n);
        expect(again.slots.map((s) => '${s.kind}@${s.x},${s.y}').toList(),
            l.slots.map((s) => '${s.kind}@${s.x},${s.y}').toList());
        expect(again.outer, l.outer);
        expect(again.theme, l.theme);
        final ks = l.slots.map((s) => s.kind).toSet();
        expect(ks.length, bonusKindCount(n), reason: 'box $n kinds');
        expect(l.slots.length, bonusItemCount(n), reason: 'box $n items');
        expect(ks.length >= lastKinds && l.slots.length >= lastItems, isTrue);
        lastKinds = ks.length;
        lastItems = l.slots.length;
        expect(l.theme >= 0 && l.theme < 5, isTrue);
        expect(l.mystery, bonusIsMystery(n));
        for (final k in ks) {
          expect(bonusPool.contains(k), isTrue, reason: k);
        }
        _expectTidyLayout(l, 'bonus $n');
        if (l.mystery) {
          _expectNoLookAlikes(l, 'bonus $n');
        }
      }
      expect(bonusKindCount(0), 4);
      expect(bonusItemCount(0), 8);
      expect(bonusKindCount(40), 7);
      expect(bonusItemCount(40), 12);
    });

    test('every 3rd box from 6 on is a mystery box', () {
      final m = <int>[
        for (var n = 0; n < 20; n++)
          if (bonusLevel(n).mystery) n,
      ];
      expect(m, [6, 9, 12, 15, 18]);
    });

    test('negative n is box 0; different boxes differ', () {
      String sig(Level l) => l.slots.map((s) => s.kind).join(',');
      expect(sig(bonusLevel(-4)), sig(bonusLevel(0)));
      expect(sig(bonusLevel(1)) == sig(bonusLevel(2)), isFalse);
      expect(bonusUnlockLevels, 12);
      expect(bonusStyleEvery, 5);
    });
  });

  group('progress 1.1', () {
    test('3rd style needs an unlock or the Supporter Pack', () {
      final p = Progress(done: <int>{0, 1, 2});
      expect(p.styleAvailable(0, 0), isTrue);
      expect(p.styleAvailable(0, 1), isTrue);
      expect(p.styleAvailable(0, 2), isFalse);
      expect(p.styleAvailable(0, 3), isFalse);
      var calls = 0;
      p.addListener(() => calls++);
      p.setStyle(0, 2);
      expect(p.styleOf(0), 0);
      expect(calls, 0, reason: 'ignored, no notification');
      expect(p.unlockExtraStyle(0), 0);
      expect(p.unlockExtraStyle(0), -1);
      expect(p.unlockExtraStyle(99), -1);
      p.setStyle(0, 2);
      expect(p.styleOf(0), 2);
      p.setStyle(1, 2);
      expect(p.styleOf(1), 0);
      p.setEntitlements(adsRemoved: false, supporter: true);
      expect(p.noAds, isTrue);
      p.setStyle(1, 2);
      expect(p.styleOf(1), 2);
      // a refund hides the stored 3rd style, it comes back with the pack
      p.setEntitlements(adsRemoved: false, supporter: false);
      expect(p.styleOf(1), 0);
      expect(p.styleOf(0), 2);
      p.setEntitlements(adsRemoved: true, supporter: true);
      expect(p.styleOf(1), 2);
    });

    test('setEntitlements notifies only on a change', () {
      final p = Progress();
      var calls = 0;
      p.addListener(() => calls++);
      p.setEntitlements(adsRemoved: false, supporter: false);
      expect(calls, 0);
      p.setEntitlements(adsRemoved: true, supporter: false);
      expect(calls, 1);
      expect(p.noAds, isTrue);
    });

    test('nextExtraStyleCandidate picks a done level without its 3rd style',
        () {
      final p = Progress();
      expect(p.nextExtraStyleCandidate(3), isNull);
      p.done.addAll(<int>{4, 1, 7});
      expect(p.nextExtraStyleCandidate(0), 1);
      expect(p.nextExtraStyleCandidate(1), 4);
      expect(p.nextExtraStyleCandidate(5), 7);
      expect(p.nextExtraStyleCandidate(-1), 4);
      p.unlockExtraStyle(4);
      expect(p.nextExtraStyleCandidate(1), 7);
      p.setEntitlements(adsRemoved: true, supporter: true);
      expect(p.nextExtraStyleCandidate(1), isNull);
    });

    test('every 5th bonus box unlocks a 3rd style', () {
      final p = Progress(done: <int>{for (var i = 0; i < 12; i++) i});
      expect(p.bonusUnlocked, isTrue);
      expect(Progress(done: <int>{0, 1}).bonusUnlocked, isFalse);
      final got = <int>[];
      for (var b = 1; b <= 20; b++) {
        final r = p.completeBonus();
        if (b % 5 == 0) {
          expect(r >= 0, isTrue, reason: 'box $b');
          got.add(r);
        } else {
          expect(r, -1, reason: 'box $b');
        }
      }
      expect(p.bonusDone, 20);
      expect(got.toSet().length, 4);
      expect(p.extraStyles, got.toSet());
      // nothing left to unlock: the box still counts
      final q = Progress(done: <int>{3});
      q.unlockExtraStyle(3);
      for (var b = 0; b < 5; b++) {
        expect(q.completeBonus(), -1);
      }
      expect(q.bonusDone, 5);
    });

    test('streak save: exactly one missed day, streak >= 2, once', () {
      Progress at(String last, int streak) => Progress(
          daily: DailyState(last: last, streak: streak, total: streak));
      final nov7 = DateTime(2026, 11, 7, 10);
      // played on the 5th, missed the 6th
      final p = at('2026-11-05', 4);
      expect(p.streakAtRisk(nov7), 4);
      expect(p.liveStreak(nov7), 0);
      expect(p.saveStreak(nov7), isTrue);
      expect(p.daily.last, '2026-11-06');
      expect(p.daily.streak, 4);
      expect(p.daily.total, 4);
      expect(p.liveStreak(nov7), 4);
      expect(p.streakAtRisk(nov7), 0);
      expect(p.saveStreak(nov7), isFalse);
      p.completeDaily(nov7);
      expect(p.daily.streak, 5);
      expect(p.daily.total, 5);

      // two missed days: no save
      expect(at('2026-11-04', 4).streakAtRisk(nov7), 0);
      expect(at('2026-11-04', 4).saveStreak(nov7), isFalse);
      // nothing missed: no save
      expect(at('2026-11-06', 4).streakAtRisk(nov7), 0);
      expect(at('2026-11-07', 4).streakAtRisk(nov7), 0);
      // streak of 1: no save
      expect(at('2026-11-05', 1).streakAtRisk(nov7), 0);
      expect(Progress().streakAtRisk(nov7), 0);

      // saved but not played afterwards: the next missed day cannot be saved
      final q = at('2026-11-05', 3);
      expect(q.saveStreak(nov7), isTrue);
      final nov8 = DateTime(2026, 11, 8, 9);
      expect(q.streakAtRisk(nov8), 0);
      expect(q.saveStreak(nov8), isFalse);
      // across a month change
      final r = at('2026-10-30', 2);
      expect(r.streakAtRisk(DateTime(2026, 11, 1)), 2);
    });

    test('3 free hints a day, then granted ones; unlimited without ads', () {
      expect(freeHintsPerDay, 3);
      final p = Progress();
      final d1 = DateTime(2026, 11, 12, 9);
      expect(p.hintsUsedToday(d1), 0);
      expect(p.hintsLeft(d1), 3);
      expect(p.useFreeHint(d1), isTrue);
      expect(p.useFreeHint(d1), isTrue);
      expect(p.useFreeHint(DateTime(2026, 11, 12, 23, 59)), isTrue);
      expect(p.hintsUsedToday(d1), 3);
      expect(p.hintsLeft(d1), 0);
      var calls = 0;
      p.addListener(() => calls++);
      expect(p.useFreeHint(d1), isFalse);
      expect(calls, 0);
      p.grantHint();
      expect(p.hintsLeft(d1), 1);
      expect(p.useFreeHint(d1), isTrue);
      expect(p.useFreeHint(d1), isFalse);
      // a clock set back keeps today's count
      expect(p.useFreeHint(DateTime(2026, 11, 11, 20)), isFalse);
      // next day: three again
      final d2 = DateTime(2026, 11, 13, 0, 1);
      expect(p.hintsUsedToday(d2), 0);
      expect(p.useFreeHint(d2), isTrue);
      expect(p.hintsUsedToday(d2), 1);
      // persisted with the date
      final q = Progress.fromJsonString(jsonEncode(p.toJson()));
      expect(q.hintsUsedToday(d2), 1);
      expect(q.hintDay, '2026-11-13');
      expect(q.hintsUsedToday(DateTime(2026, 11, 14)), 0);
      // Remove ads: unlimited
      q.setEntitlements(adsRemoved: true, supporter: false);
      expect(q.hintsLeft(d2), -1);
      for (var i = 0; i < 10; i++) {
        expect(q.useFreeHint(d2), isTrue);
      }
      // old saves have no hint data
      final old = Progress.fromJsonString('{"level":2}');
      expect(old.hintsUsedToday(d1), 0);
      expect(old.extraHints, 0);
    });

    test('simple prefs and ad pacing setters', () {
      final p = Progress();
      expect(p.vibration, isTrue);
      expect(p.reminderOn, isFalse);
      var calls = 0;
      p.addListener(() => calls++);
      p.setVibration(false);
      p.setReminderOn(true);
      p.setReminderAsked(true);
      p.setReviewAsked(true);
      p.setInterstitialCounter(2);
      p.setLastFullScreenAdMs(1234);
      p.setInterstitialCounter(-5);
      expect(calls, 7);
      expect(p.vibration, isFalse);
      expect(p.reminderOn && p.reminderAsked && p.reviewAsked, isTrue);
      expect(p.interstitialCounter, 0);
      expect(p.lastFullScreenAdMs, 1234);
    });

    test('JSON round trip of every new field', () {
      final p = Progress(lang: 'ar', level: 20, done: <int>{0, 5, 21});
      p.unlockExtraStyle(5);
      p.unlockExtraStyle(21);
      p.setStyle(5, 2);
      p.setStyle(0, 1);
      p.setEntitlements(adsRemoved: true, supporter: true);
      p.completeBonus();
      p.completeBonus();
      p.setVibration(false);
      p.setReminderOn(true);
      p.setReminderAsked(true);
      p.setReviewAsked(true);
      p.setInterstitialCounter(2);
      p.setLastFullScreenAdMs(1762000000000);
      p.streakSaveDay = '2026-11-06';
      p.grantHint();
      p.useFreeHint(DateTime(2026, 11, 12));
      final text = jsonEncode(p.toJson());
      final q = Progress.fromJsonString(text);
      expect(q.toJson(), p.toJson());
      expect(q.extraStyles, {5, 21});
      expect(q.styleOf(5), 2);
      expect(q.styleOf(0), 1);
      expect(q.adsRemoved && q.supporter, isTrue);
      expect(q.bonusDone, 2);
      expect(q.vibration, isFalse);
      expect(q.reminderOn && q.reminderAsked && q.reviewAsked, isTrue);
      expect(q.interstitialCounter, 2);
      expect(q.lastFullScreenAdMs, 1762000000000);
      expect(q.streakSaveDay, '2026-11-06');
      expect(q.level, 20);
      expect(q.done, {0, 5, 21});
    });

    test('a v2 save and the web shape load with defaults', () {
      for (final raw in <String>[
        '{"v":2,"lang":"tr","level":7,"done":[0,1,2,3,4,5,6],"sound":true,'
            '"styles":{"2":1},"daily":{"last":"2026-11-06","streak":2,'
            '"total":5,"days":["2026-11-05","2026-11-06"]}}',
        '{"lang":"tr","level":7,"done":[0,1,2,3,4,5,6],"sound":true,'
            '"styles":{"2":1},"daily":{"last":"2026-11-06","streak":2,'
            '"total":5,"days":["2026-11-05","2026-11-06"]}}',
      ]) {
        final p = Progress.fromJsonString(raw);
        expect(p.level, 7);
        expect(p.done.length, 7);
        expect(p.styleOf(2), 1);
        expect(p.daily.total, 5);
        expect(p.extraStyles, isEmpty);
        expect(p.adsRemoved, isFalse);
        expect(p.supporter, isFalse);
        expect(p.bonusDone, 0);
        expect(p.vibration, isTrue);
        expect(p.reminderOn, isFalse);
        expect(p.reminderAsked, isFalse);
        expect(p.reviewAsked, isFalse);
        expect(p.interstitialCounter, 0);
        expect(p.lastFullScreenAdMs, 0);
        expect(p.streakSaveDay, '');
        expect(p.toJson()['v'], 3);
      }
    });

    test('bad schema 3 values fall back, styles are clamped', () {
      final p = Progress.fromJsonString(
          '{"styles":{"1":7,"2":-3,"3":2,"40":1},"extraStyles":[3,"x",99,-1],'
          '"adsRemoved":"yes","supporter":1,"bonusDone":-4,"vibration":null,'
          '"adCounter":"2","lastAdMs":12.7,"streakSaveDay":"soon"}');
      expect(p.styles, {1: 2, 2: 0, 3: 2});
      expect(p.extraStyles, {3});
      expect(p.styleOf(1), 0, reason: 'clamped to 2, not unlocked');
      expect(p.styleOf(3), 2);
      expect(p.adsRemoved, isFalse);
      expect(p.supporter, isFalse);
      expect(p.bonusDone, 0);
      expect(p.vibration, isTrue);
      expect(p.interstitialCounter, 0);
      expect(p.lastFullScreenAdMs, 12);
      expect(p.streakSaveDay, '');
    });

    test('reset keeps purchases, settings and ad pacing', () {
      final p = Progress(lang: 'en', done: <int>{1, 2});
      p.unlockExtraStyle(1);
      p.completeBonus();
      p.setEntitlements(adsRemoved: true, supporter: false);
      p.setVibration(false);
      p.setInterstitialCounter(2);
      p.reset();
      expect(p.done, isEmpty);
      expect(p.extraStyles, isEmpty);
      expect(p.bonusDone, 0);
      expect(p.adsRemoved, isTrue);
      expect(p.vibration, isFalse);
      expect(p.interstitialCounter, 2);
      expect(p.lang, 'en');
    });
  });
}
