import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tidy_nook/game/content.dart';
import 'package:tidy_nook/game/progress.dart';

import 'game_data_test.dart' show expectFlutterSvgSafe;

/// A schema 4 save as 1.2 writes it (every 1.2 key set to a non-default value).
const String _schema4Fixture =
    '{"v":4,"lang":"ar","level":33,"done":[0,1,2,3,4,5,6,7,8,9,10,11,12,19,30,31,32],'
    '"sound":true,"styles":{"1":1,"5":2,"8":2,"19":1},'
    '"daily":{"last":"2026-11-20","streak":6,"total":24,'
    '"days":["2026-11-15","2026-11-16","2026-11-17","2026-11-18","2026-11-19","2026-11-20"]},'
    '"extraStyles":[5,8],"adsRemoved":false,"supporter":false,"bonusDone":9,'
    '"vibration":true,"reminderOn":false,"reminderAsked":true,"reviewAsked":false,'
    '"adCounter":1,"lastAdMs":1763600000000,"streakSaveDay":"",'
    '"hintDay":"2026-11-20","hintsUsed":1,"extraHints":4,'
    '"tasks":{"day":"2026-11-20","list":[{"t":"boxes","n":2,"p":1,"c":false,"x":false},'
    '{"t":"style","n":1,"p":1,"c":true,"x":false},{"t":"hint","n":1,"p":0,"c":false,"x":false}]},'
    '"chestSteps":4,"chestDay":"2026-11-19","chestsOpened":1,"chestDecors":[0],'
    '"winter":{"season":2025,"done":[0,1,2,3,4,5,6]},"snowman":true,"mechanicTipSeen":true}';

bool _overlaps(Rect a, Rect b) =>
    a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom;

void main() {
  final all = <int>{for (var i = 0; i < levels.length; i++) i};

  String house({
    bool pack = false,
    bool gift = false,
    bool snow = false,
    Map<int, int> styles = const <int, int>{},
  }) =>
      houseSvg(
        done: all,
        styles: styles,
        dailyTotal: 30,
        roomNames: const <String>[],
        houseLine: '#3A3046',
        puppy: true,
        extended: true,
        snow: snow,
        snowman: true,
        chestDecors: const <int>{0, 1, 2, 3},
        winterPack: pack,
        winterGift: gift,
      );

  group('winter pack content', () {
    test('constants', () {
      expect(winterPackId, 'winter_pack');
      expect(winterStyle, 3);
      expect(maxStyleCount, 4);
      expect(styleCount, 3, reason: 'unchanged for every piece');
      expect(winterStylePieces.length, 6);
      expect(winterStylePieces.toSet().length, 6);
      for (final i in winterStylePieces) {
        expect(i >= 0 && i < decorCount, isTrue);
        expect(hasWinterStyle(i), isTrue);
      }
      expect(hasWinterStyle(0), isFalse);
      expect(winterDecorCount, 5);
      expect(winterPackItems.where((x) => x.isDecor).map((x) => x.index).toList(), [0, 1, 2, 3, 4]);
      expect(winterPackItems.where((x) => !x.isDecor).map((x) => x.index).toList(), winterStylePieces);
    });

    test('winter style differs from A, B, C and is safe; others draw style A', () {
      for (var i = 0; i < decorCount; i++) {
        final a = decorSvg(i, 0);
        final w = decorSvg(i, winterStyle);
        if (hasWinterStyle(i)) {
          expect(w, isNot(a), reason: 'piece $i');
          expect(w, isNot(decorSvg(i, 1)), reason: 'piece $i');
          expect(w, isNot(decorSvg(i, 2)), reason: 'piece $i');
          expectFlutterSvgSafe(decorPreviewSvg(i, winterStyle));
        } else {
          expect(w, a, reason: 'piece $i');
        }
      }
      expect(decorSvg(1, 4), decorSvg(1, 0));
    });

    test('decor pieces and gift do not overlap furniture, pets, other decor or each other', () {
      final obstacles = <String, Rect>{
        for (var i = 0; i < decorCount; i++) 'piece $i': decorBounds(i),
        for (var k = 0; k < petCount; k++) 'pet $k': petBounds(k),
        'garden bush right': const Rect.fromLTRB(310, 398, 354, 427),
        for (var d = 0; d < chestDecorCount; d++) 'chest decor $d': chestDecorBounds(d),
        'snowman': snowmanRect,
        'chimney': const Rect.fromLTRB(248.5, -450, 278, -392.5),
        'round roof window': const Rect.fromLTRB(165.5, -422.5, 194.5, -393.5),
        'greenhouse': const Rect.fromLTRB(97, 640, 263, 804),
        for (var r = 0; r < rooms.length; r++)
          'room $r check mark': Rect.fromLTRB(rooms[r].x + 127, rooms[r].y + 5, rooms[r].x + 145, rooms[r].y + 23),
      };
      final mine = <String, List<Rect>>{
        for (var d = 0; d < winterDecorCount; d++) 'winter decor $d': winterDecorParts(d),
        'winter gift': <Rect>[winterGiftRect],
      };
      final houseRect = houseOrigin & houseSize;
      mine.forEach((name, parts) {
        for (final p in parts) {
          expect(houseRect.contains(p.topLeft) && houseRect.contains(p.bottomRight), isTrue, reason: name);
          obstacles.forEach((on, o) {
            expect(_overlaps(p, o), isFalse, reason: '$name / $on');
          });
          mine.forEach((other, oparts) {
            if (other == name) {
              return;
            }
            for (final q in oparts) {
              expect(_overlaps(p, q), isFalse, reason: '$name / $other');
            }
          });
        }
      });
      // the roof lights hang inside the roof, above the top floor
      for (final b in winterDecorParts(2)) {
        final x = b.center.dx;
        final edge = x <= 180 ? -376 - (x - 16) * 0.5 : -458 + (x - 180) * 0.5;
        expect(b.center.dy > edge, isTrue, reason: 'bulb at $x under the roof edge');
        expect(b.bottom <= -380, isTrue, reason: 'bulb at $x above the top floor');
      }
      for (var d = 0; d < winterDecorCount; d++) {
        expect(winterDecorBounds(d).contains(winterDecorSpot(d)), isTrue);
      }
      expect(winterGiftRect.contains(winterGiftSpot), isTrue);
    });

    test('houseSvg draws the pack and the gift only when asked, over the snow', () {
      final base = house();
      final withPack = house(pack: true);
      final withGift = house(gift: true);
      for (final s in <String>[base, withPack, withGift, house(pack: true, gift: true, snow: true)]) {
        expectFlutterSvgSafe(s);
      }
      for (var d = 0; d < winterDecorCount; d++) {
        expect(base.contains(winterDecorSvg(d)), isFalse);
        expect(withPack.contains(winterDecorSvg(d)), isTrue, reason: 'decor $d');
      }
      expect(base.contains(winterGiftSvg()), isFalse);
      expect(withGift.contains(winterGiftSvg()), isTrue);
      final snowy = house(pack: true, snow: true);
      expect(snowy.indexOf(winterDecorSvg(2)) > snowy.indexOf('#BFD6E6'), isTrue,
          reason: 'lights drawn after the snow');
      // winter styles show in the house
      final styled = house(styles: <int, int>{for (final i in winterStylePieces) i: winterStyle});
      for (final i in winterStylePieces) {
        expect(styled.contains(decorSvg(i, winterStyle)), isTrue);
      }
      // the 1.0 frame ignores them
      final legacy = houseSvg(
          done: all,
          styles: const <int, int>{},
          dailyTotal: 30,
          roomNames: const <String>[],
          houseLine: '#3A3046',
          winterPack: true,
          winterGift: true);
      expect(legacy.contains(winterGiftSvg()), isFalse);
      expect(legacy.contains(winterDecorSvg(0)), isFalse);
    });

    test('previews are safe', () {
      for (var d = 0; d < winterDecorCount; d++) {
        expectFlutterSvgSafe(winterDecorPreviewSvg(d));
      }
      expectFlutterSvgSafe(winterDecorPreviewSvg(-3));
      expectFlutterSvgSafe(winterGiftPreviewSvg());
      expect(winterGiftPreviewSvg(locked: true), contains('opacity="0.35"'));
      final pack = winterPackPreviewSvg();
      expectFlutterSvgSafe(pack);
      expect(pack, contains('viewBox="0 0 300 200"'));
      expect(pack, contains(decorSvg(8, winterStyle)));
    });
  });

  group('progress 1.3', () {
    test('winter style needs the pack; picker counts stay 3 for non-owners', () {
      final p = Progress(done: <int>{0, 1, 2, 5, 8});
      for (var i = 0; i < decorCount; i++) {
        expect(p.styleCountOf(i), styleCount);
        expect(p.styleChoices(i), [0, 1, 2]);
        expect(p.styleAvailable(i, winterStyle), isFalse);
      }
      var calls = 0;
      p.addListener(() => calls++);
      p.setStyle(8, winterStyle);
      expect(p.styleOf(8), 0);
      expect(calls, 0);
      // older callers (no winterPack) never change the pack
      p.setEntitlements(adsRemoved: false, supporter: false);
      expect(calls, 0);
      p.setEntitlements(adsRemoved: false, supporter: false, winterPack: true);
      expect(calls, 1);
      expect(p.winterPackOwned, isTrue);
      expect(p.noAds, isFalse, reason: 'the pack does not remove ads');
      expect(p.hintsLeft(DateTime(2026, 12, 2)), freeHintsPerDay, reason: 'no hints in the pack');
      p.setEntitlements(adsRemoved: true, supporter: false);
      expect(p.winterPack, isTrue);
      for (final i in winterStylePieces) {
        expect(p.styleCountOf(i), 4);
        expect(p.styleChoices(i), [0, 1, 2, 3]);
        expect(p.styleAvailable(i, winterStyle), isTrue);
      }
      expect(p.styleCountOf(0), 3);
      expect(p.styleAvailable(0, winterStyle), isFalse);
      p.setStyle(8, winterStyle);
      expect(p.styleOf(8), winterStyle);
      // a refund hides the winter style, it comes back with the pack
      p.setEntitlements(adsRemoved: true, supporter: false, winterPack: false);
      expect(p.styleOf(8), 0);
      expect(p.styleCountOf(8), 3);
      p.setEntitlements(adsRemoved: true, supporter: false, winterPack: true);
      expect(p.styleOf(8), winterStyle);
    });

    test('nextStyleOf cycles over the available styles', () {
      final p = Progress(done: <int>{8});
      expect(p.nextStyleOf(8), 1);
      p.setStyle(8, 1);
      expect(p.nextStyleOf(8), 0, reason: 'style 2 locked, no pack');
      p.setEntitlements(adsRemoved: false, supporter: false, winterPack: true);
      expect(p.nextStyleOf(8), winterStyle, reason: 'skips the locked style 2');
      p.setStyle(8, winterStyle);
      expect(p.nextStyleOf(8), 0);
      p.unlockExtraStyle(8);
      p.setStyle(8, 1);
      expect(p.nextStyleOf(8), 2);
      p.setStyle(8, 2);
      expect(p.nextStyleOf(8), 3);
      // a piece without a winter style keeps 3
      p.setStyle(0, 1);
      expect(p.nextStyleOf(0), 0);
    });

    test('free winter gift: first winter box, once, kept forever', () {
      final day = DateTime(2026, 12, 4);
      final p = Progress(done: <int>{0});
      p.clock = () => day;
      expect(p.winterGift, isFalse);
      expect(p.winterGiftToReveal, isFalse);
      expect(p.takeWinterGiftGranted(), isFalse);
      expect(p.markWinterGiftShown(), isFalse);
      p.completeWinter(2, day);
      expect(p.winterGift, isTrue);
      expect(p.winterGiftToReveal, isTrue);
      expect(p.takeWinterGiftGranted(), isTrue);
      expect(p.takeWinterGiftGranted(), isFalse);
      // the reveal survives a restart until it is marked
      final q = Progress.fromJsonString(jsonEncode(p.toJson()));
      expect(q.winterGiftToReveal, isTrue);
      expect(p.markWinterGiftShown(), isTrue);
      expect(p.markWinterGiftShown(), isFalse);
      expect(p.winterGiftToReveal, isFalse);
      p.completeWinter(3, day);
      expect(p.takeWinterGiftGranted(), isFalse);
      expect(p.winterGiftToReveal, isFalse);
      p.reset();
      expect(p.winterGift, isTrue, reason: 'keepsake');
      expect(p.winterGiftShown, isTrue);
      // next season: no second gift
      p.completeWinter(0, DateTime(2027, 12, 2));
      expect(p.takeWinterGiftGranted(), isFalse);
    });

    test('pack offer on a card: once per day, event only, never for owners', () {
      final p = Progress(done: <int>{0});
      final d1 = DateTime(2026, 12, 5, 9);
      expect(p.canOfferWinterPack(DateTime(2026, 11, 30)), isFalse, reason: 'before the event');
      expect(p.canOfferWinterPack(DateTime(2027, 1, 16)), isFalse, reason: 'after the event');
      expect(p.canOfferWinterPack(d1), isTrue);
      expect(p.markWinterPackOffered(d1), isTrue);
      expect(p.winterOfferDay, '2026-12-05');
      expect(p.canOfferWinterPack(DateTime(2026, 12, 5, 22)), isFalse);
      expect(p.markWinterPackOffered(DateTime(2026, 12, 5, 23)), isFalse);
      expect(p.canOfferWinterPack(DateTime(2026, 12, 4)), isFalse, reason: 'clock set back');
      expect(p.canOfferWinterPack(DateTime(2026, 12, 6, 0, 1)), isTrue);
      expect(p.canOfferWinterPack(DateTime(2027, 1, 15)), isTrue);
      p.setEntitlements(adsRemoved: false, supporter: false, winterPack: true);
      expect(p.canOfferWinterPack(DateTime(2026, 12, 6)), isFalse);
      p.reset();
      expect(p.winterPack, isTrue, reason: 'purchases stay');
      expect(p.winterOfferDay, '2026-12-05');
    });
  });

  group('progress schema 5', () {
    test('a schema 4 save from 1.2 loads without loss', () {
      final old = jsonDecode(_schema4Fixture) as Map<String, dynamic>;
      final p = Progress.fromJsonString(_schema4Fixture);
      final out = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      for (final k in old.keys) {
        if (k == 'v') {
          continue;
        }
        expect(jsonEncode(out[k]), jsonEncode(old[k]), reason: k);
      }
      expect(Progress.schemaVersion, 5);
      expect(out['v'], 5);
      expect(p.styleOf(5), 2);
      expect(p.styleOf(8), 2);
      expect(p.styleOf(19), 1);
      expect(p.snowman, isTrue);
      expect(p.chestDecors, {0});
      expect(p.tasks.length, 3);
      // the new fields start at their defaults
      expect(p.winterPack, isFalse);
      expect(p.winterGift, isFalse);
      expect(p.winterGiftShown, isFalse);
      expect(p.winterOfferDay, '');
      expect(Progress.fromJson(out).toJson(), p.toJson());
    });

    test('JSON round trip of every schema 5 field and a stored winter style', () {
      final p = Progress(done: <int>{8});
      p.setEntitlements(adsRemoved: false, supporter: false, winterPack: true);
      p.setStyle(8, winterStyle);
      p.completeWinter(0, DateTime(2026, 12, 3));
      p.markWinterGiftShown();
      p.markWinterPackOffered(DateTime(2026, 12, 3));
      final q = Progress.fromJsonString(jsonEncode(p.toJson()));
      expect(q.toJson(), p.toJson());
      expect(q.winterPack && q.winterGift && q.winterGiftShown, isTrue);
      expect(q.winterOfferDay, '2026-12-03');
      expect(q.styles[8], winterStyle);
      expect(q.styleOf(8), winterStyle);
    });

    test('bad schema 5 values fall back', () {
      final p = Progress.fromJsonString(
          '{"v":5,"styles":{"8":3,"1":9},"winterPack":"yes","winterGift":1,'
          '"winterGiftShown":true,"winterOfferDay":"tomorrow"}');
      expect(p.styles, {8: 3, 1: 2});
      expect(p.styleOf(8), 0, reason: 'stored, but no pack');
      expect(p.winterPack, isFalse);
      expect(p.winterGift, isFalse);
      expect(p.winterGiftShown, isFalse, reason: 'no gift, nothing shown');
      expect(p.winterOfferDay, '');
    });
  });
}
