import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:tidy_nook/monet/billing.dart';
import 'package:tidy_nook/monet/consent.dart';
import 'package:flutter/foundation.dart';
import 'package:tidy_nook/services/haptics.dart';
import 'package:tidy_nook/services/licenses.dart';
import 'package:tidy_nook/services/reminder.dart';
import 'package:tidy_nook/services/review.dart';
import 'package:tidy_nook/services/telemetry.dart';

PurchaseDetails purchase(String id, PurchaseStatus status) => PurchaseDetails(
      purchaseID: 'p-$id',
      productID: id,
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: '',
        source: 'google_play',
      ),
      transactionDate: '0',
      status: status,
    );

void main() {
  group('reminderTimes', () {
    test('7 evenings at 19:00 starting today when the box is not done yet', () {
      final now = DateTime(2026, 11, 11, 9, 30);
      final t = reminderTimes(now, dailyDoneToday: false);
      expect(t.length, 7);
      expect(t.first, DateTime(2026, 11, 11, 19));
      expect(t.last, DateTime(2026, 11, 17, 19));
      expect(t.every((d) => d.hour == 19 && d.minute == 0), isTrue);
    });

    test('today is skipped when the daily box is done', () {
      final now = DateTime(2026, 11, 11, 9, 30);
      final t = reminderTimes(now, dailyDoneToday: true);
      expect(t.length, 7);
      expect(t.first, DateTime(2026, 11, 12, 19));
      expect(t.last, DateTime(2026, 11, 18, 19));
    });

    test('today is skipped after 19:00', () {
      final now = DateTime(2026, 11, 11, 19, 0);
      expect(reminderTimes(now, dailyDoneToday: false).first, DateTime(2026, 11, 12, 19));
    });

    test('month and year ends roll over by calendar', () {
      final t = reminderTimes(DateTime(2026, 12, 30, 20), dailyDoneToday: false);
      expect(t.first, DateTime(2026, 12, 31, 19));
      expect(t[1], DateTime(2027, 1, 1, 19));
    });

    test('the plugin is never touched in tests', () async {
      final r = Reminder();
      expect(await r.requestAndEnable(title: 't', body: 'b', dailyDoneToday: false), isFalse);
      await r.reschedule(enabled: true, title: 't', body: 'b', dailyDoneToday: false);
      await r.disable();
    });
  });

  group('review', () {
    const now = 5000000000;
    test('only once, only after 6 levels, never right after an ad', () {
      expect(shouldAskReview(alreadyAsked: false, completedLevels: 6, lastFullScreenAdMs: 0, nowMs: now), isTrue);
      expect(shouldAskReview(alreadyAsked: true, completedLevels: 6, lastFullScreenAdMs: 0, nowMs: now), isFalse);
      expect(shouldAskReview(alreadyAsked: false, completedLevels: 5, lastFullScreenAdMs: 0, nowMs: now), isFalse);
      expect(
          shouldAskReview(alreadyAsked: false, completedLevels: 9, lastFullScreenAdMs: now - 5000, nowMs: now),
          isFalse);
      expect(
          shouldAskReview(alreadyAsked: false, completedLevels: 9, lastFullScreenAdMs: now - 61000, nowMs: now),
          isTrue);
    });

    test('maybeAsk does nothing in tests', () async {
      var marked = false;
      final asked = await ReviewPrompt().maybeAsk(
        alreadyAsked: false,
        completedLevels: 10,
        lastFullScreenAdMs: 0,
        markAsked: () => marked = true,
      );
      expect(asked, isFalse);
      expect(marked, isFalse);
    });
  });

  group('consent', () {
    test('the form waits for the foreground and for the player to leave a level', () {
      final g = ConsentFormGate();
      expect(g.beginSession(), isTrue);
      expect(g.beginSession(), isFalse);
      expect(g.active, isTrue);
      expect(g.tryShow(foreground: true, interruptible: false), isFalse);
      expect(g.pending, isTrue);
      expect(g.retryPending(foreground: false), isFalse);
      expect(g.retryPending(foreground: true), isTrue);
      expect(g.busy, isTrue);
      expect(g.tryShow(foreground: true), isFalse, reason: 'only one form at a time');
      g.finished();
      expect(g.active, isFalse);
      expect(g.retryPending(foreground: true), isFalse, reason: 'nothing pending any more');
    });

    test('Firebase consent signals from UMP', () {
      expect(deriveTelemetryConsent(umpStatus: 'notRequired').analyticsStorage, isTrue);
      expect(deriveTelemetryConsent(umpStatus: 'required'), TelemetryConsent.denied);
      expect(deriveTelemetryConsent(umpStatus: 'unknown'), TelemetryConsent.denied);
      final all = deriveTelemetryConsent(umpStatus: 'obtained', gdprApplies: true, purposeConsents: '1111111111');
      expect(all, const TelemetryConsent(analyticsStorage: true, adStorage: true, adUserData: true));
      final none = deriveTelemetryConsent(umpStatus: 'obtained', gdprApplies: true, purposeConsents: '0000000000');
      expect(none, TelemetryConsent.denied);
      final noP7 = deriveTelemetryConsent(umpStatus: 'obtained', gdprApplies: true, purposeConsents: '1111110111');
      expect(noP7.analyticsStorage, isTrue);
      expect(noP7.adUserData, isFalse);
      expect(all.adPersonalization, isFalse);
    });
  });

  group('billing', () {
    test('entitlements: supporter includes remove_ads', () {
      expect(entitlementsFor(<String>{}), (adsRemoved: false, supporter: false));
      expect(entitlementsFor(<String>{Billing.removeAdsId}), (adsRemoved: true, supporter: false));
      expect(entitlementsFor(<String>{Billing.supporterId}), (adsRemoved: true, supporter: true));
    });

    test('a disabled Billing never throws and reports failures', () async {
      final b = Billing(onEntitlements: ({required bool adsRemoved, required bool supporter}) {});
      final events = <PurchaseEvent>[];
      final sub = b.events.listen(events.add);
      await b.init();
      expect(b.available, isFalse);
      expect(b.priceOf(Billing.removeAdsId), isNull);
      await b.buy(Billing.removeAdsId);
      await b.restore();
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.kind), <PurchaseEventKind>[PurchaseEventKind.failed, PurchaseEventKind.failed]);
      await sub.cancel();
      b.dispose();
    });

    test('purchased grants, pending does not, a restore answer replaces', () async {
      final pushed = <({bool adsRemoved, bool supporter})>[];
      final b = Billing(
        enabled: true,
        onEntitlements: ({required bool adsRemoved, required bool supporter}) =>
            pushed.add((adsRemoved: adsRemoved, supporter: supporter)),
      );
      final events = <PurchaseEvent>[];
      final sub = b.events.listen(events.add);

      await b.debugHandle(<PurchaseDetails>[purchase(Billing.supporterId, PurchaseStatus.pending)]);
      expect(b.supporter, isFalse);
      expect(pushed, isEmpty);

      await b.debugHandle(<PurchaseDetails>[purchase(Billing.supporterId, PurchaseStatus.purchased)]);
      expect(b.supporter, isTrue);
      expect(b.adsRemoved, isTrue);
      expect(b.owns(Billing.removeAdsId), isTrue);
      expect(pushed.last, (adsRemoved: true, supporter: true));

      // Play answers a restore with nothing (refund): entitlements go away
      await b.debugHandle(<PurchaseDetails>[], asRestoreAnswer: true);
      expect(b.adsRemoved, isFalse);
      expect(pushed.last, (adsRemoved: false, supporter: false));

      await b.debugHandle(<PurchaseDetails>[purchase(Billing.removeAdsId, PurchaseStatus.canceled)]);
      await b.debugHandle(<PurchaseDetails>[purchase(Billing.removeAdsId, PurchaseStatus.error)]);
      await Future<void>.delayed(Duration.zero);
      expect(events.map((e) => e.kind), <PurchaseEventKind>[
        PurchaseEventKind.pending,
        PurchaseEventKind.success,
        PurchaseEventKind.cancelled,
        PurchaseEventKind.failed,
      ]);
      await sub.cancel();
      b.dispose();
    });

    test('cached entitlements are known before Play answers', () {
      final b = Billing(
        onEntitlements: ({required bool adsRemoved, required bool supporter}) {},
        adsRemoved: true,
      );
      expect(b.adsRemoved, isTrue);
      expect(b.supporter, isFalse);
      b.dispose();
    });
  });

  test('telemetry is a silent no-op without Firebase', () async {
    final t = Telemetry();
    expect(await t.init(), isFalse);
    t.logLevelStart(0);
    t.logLevelComplete(3, seconds: 99999);
    t.logDaily(streak: 2, total: 5);
    t.logBonus(1);
    t.logPurchase(Billing.removeAdsId, currency: 'TRY', value: 59.99);
    t.logAd('interstitial', 'shown');
    await t.applyUmpStatus('obtained');
    expect(t.ready, isFalse);
  });

  test('haptics honour the setting', () {
    final ticks = <String>[];
    Haptics.debugSink = ticks.add;
    var on = true;
    final h = Haptics(enabled: () => on);
    h.tick();
    on = false;
    h.tick();
    h.success();
    on = true;
    h.success();
    Haptics.debugSink = null;
    expect(ticks, <String>['tick', 'success']);
  });

  testWidgets('the font license is registered once and readable', (WidgetTester tester) async {
    registerFontLicense();
    registerFontLicense();
    final entries = await tester.runAsync(() => LicenseRegistry.licenses.toList());
    final baloo = entries!.where((e) => e.packages.contains('Baloo Bhaijaan 2')).toList();
    expect(baloo.length, 1);
    final text = baloo.first.paragraphs.map((p) => p.text).join(' ');
    expect(text, contains('Open Font License'));
  });
}
