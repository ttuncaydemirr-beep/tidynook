import 'package:flutter_test/flutter_test.dart';
import 'package:tidy_nook/monet/ad_rules.dart';

void main() {
  const now = 10 * 60 * 1000 * 1000; // some epoch ms

  bool rule({
    int level = 5,
    bool daily = false,
    int counter = 3,
    int lastAdMs = 0,
    int nowMs = now,
    bool removed = false,
  }) =>
      shouldShowInterstitial(
        completedLevelIndex: level,
        isDaily: daily,
        counter: counter,
        lastAdMs: lastAdMs,
        nowMs: nowMs,
        adsRemoved: removed,
      );

  group('shouldShowInterstitial', () {
    test('shows when every rule is met', () {
      expect(rule(), isTrue);
    });

    test('never before completed level index 3', () {
      expect(rule(level: 0), isFalse);
      expect(rule(level: 1), isFalse);
      expect(rule(level: 2), isFalse);
      expect(rule(level: 3), isTrue);
    });

    test('at most every 3 completed boxes', () {
      expect(rule(counter: 0), isFalse);
      expect(rule(counter: 1), isFalse);
      expect(rule(counter: 2), isFalse);
      expect(rule(counter: 3), isTrue);
      expect(rule(counter: 7), isTrue);
    });

    test('at least 90 s since the last full-screen ad', () {
      expect(rule(lastAdMs: now - 1000), isFalse);
      expect(rule(lastAdMs: now - 89999), isFalse);
      expect(rule(lastAdMs: now - 90000), isTrue);
      expect(rule(lastAdMs: now - 3600 * 1000), isTrue);
    });

    test('a last ad in the future (clock set back) does not block forever', () {
      expect(rule(lastAdMs: now + 5 * 60 * 1000), isTrue);
    });

    test('never after a daily box', () {
      expect(rule(daily: true), isFalse);
      expect(rule(daily: true, counter: 50, level: 20), isFalse);
    });

    test('never when ads are removed', () {
      expect(rule(removed: true), isFalse);
    });

    test('bonus boxes pass the level rule', () {
      expect(rule(level: kBonusBoxLevelIndex), isTrue);
    });
  });

  group('counterAfterBox', () {
    test('level boxes count, daily boxes do not', () {
      expect(counterAfterBox(counter: 0, isDaily: false), 1);
      expect(counterAfterBox(counter: 2, isDaily: false), 3);
      expect(counterAfterBox(counter: 2, isDaily: true), 2);
    });

    test('negative and huge values are clamped', () {
      expect(counterAfterBox(counter: -4, isDaily: false), 1);
      expect(counterAfterBox(counter: kCounterCap, isDaily: false), kCounterCap);
      expect(counterAfterBox(counter: 1000, isDaily: true), kCounterCap);
    });
  });

  test('a fresh player sees the first ad when leaving the 4th level, then every 3rd box', () {
    var counter = 0;
    var last = 0;
    var t = now;
    final shownAt = <int>[];
    for (var level = 0; level < 12; level++) {
      t += 5 * 60 * 1000; // five minutes per level
      counter = counterAfterBox(counter: counter, isDaily: false);
      if (shouldShowInterstitial(
        completedLevelIndex: level,
        isDaily: false,
        counter: counter,
        lastAdMs: last,
        nowMs: t,
        adsRemoved: false,
      )) {
        shownAt.add(level);
        counter = 0;
        last = t;
      }
    }
    expect(shownAt, <int>[3, 6, 9]);
  });

  test('quick boxes inside 90 s wait for the gap', () {
    var counter = 0;
    var last = now;
    var t = now;
    var shown = 0;
    for (var i = 0; i < 6; i++) {
      t += 20 * 1000; // 20 s per box
      counter = counterAfterBox(counter: counter, isDaily: false);
      if (shouldShowInterstitial(
        completedLevelIndex: 10,
        isDaily: false,
        counter: counter,
        lastAdMs: last,
        nowMs: t,
        adsRemoved: false,
      )) {
        shown++;
        counter = 0;
        last = t;
      }
    }
    // the 3rd box is at 60 s (too soon), the 4th at 80 s (too soon), the 5th at 100 s
    expect(shown, 1);
  });

  test('MemoryAdsState and CallbackAdsState store both values', () {
    final m = MemoryAdsState();
    m.writeAdState(interstitialCounter: 2, lastFullScreenAdMs: 77);
    expect(m.interstitialCounter, 2);
    expect(m.lastFullScreenAdMs, 77);
    expect(m.writes, 1);

    var c = 0;
    var l = 0;
    final cb = CallbackAdsState(
      adsRemoved: () => true,
      counter: () => c,
      lastAdMs: () => l,
      write: (counter, lastAdMs) {
        c = counter;
        l = lastAdMs;
      },
    );
    cb.writeAdState(interstitialCounter: 5, lastFullScreenAdMs: 9);
    expect(cb.adsRemoved, isTrue);
    expect(cb.interstitialCounter, 5);
    expect(cb.lastFullScreenAdMs, 9);
  });

  group('hints', () {
    const today = '2026-11-12';
    test('a few free hints per day, then the rewarded offer', () {
      var day = '';
      var used = 0;
      final offers = <HintOffer>[];
      for (var i = 0; i < kFreeHintsPerDay + 2; i++) {
        final o = hintOffer(usedDay: day, usedCount: used, today: today);
        offers.add(o);
        if (o == HintOffer.free) {
          final r = recordFreeHint(usedDay: day, usedCount: used, today: today);
          day = r.day;
          used = r.count;
        }
      }
      expect(offers.where((o) => o == HintOffer.free).length, kFreeHintsPerDay);
      expect(offers.sublist(kFreeHintsPerDay), everyElement(HintOffer.rewarded));
      expect(freeHintsLeft(usedDay: day, usedCount: used, today: today), 0);
    });

    test('a new day (or a clock set back) gives the free hints back', () {
      expect(freeHintsLeft(usedDay: '2026-11-11', usedCount: kFreeHintsPerDay, today: today), kFreeHintsPerDay);
      expect(freeHintsLeft(usedDay: '2026-11-13', usedCount: kFreeHintsPerDay, today: today), kFreeHintsPerDay);
      final r = recordFreeHint(usedDay: '2026-11-11', usedCount: 3, today: today);
      expect(r, (day: today, count: 1));
    });

    test('bad stored values are clamped', () {
      expect(freeHintsLeft(usedDay: today, usedCount: -5, today: today), kFreeHintsPerDay);
      expect(freeHintsLeft(usedDay: today, usedCount: 99, today: today), 0);
      expect(recordFreeHint(usedDay: today, usedCount: 99, today: today).count, kFreeHintsPerDay);
    });

    test('remove_ads gives unlimited free hints', () {
      expect(hintOffer(usedDay: today, usedCount: 50, today: today, adsRemoved: true), HintOffer.free);
      expect(hintOffer(usedDay: today, usedCount: 50, today: today), HintOffer.rewarded);
    });

    test('placement names', () {
      expect(<String>{kPlacementHint, kPlacementSurpriseBox, kPlacementStreakSave},
          <String>{'hint', 'surprise_box', 'streak_save'});
      expect(kFreeHintsPerDay, greaterThan(0));
    });
  });
}
