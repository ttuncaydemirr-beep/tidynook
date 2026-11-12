import 'dart:async';

import 'package:tidy_nook/game/progress.dart';
import 'package:tidy_nook/monet/ad_rules.dart';
import 'package:tidy_nook/monet/ads.dart';
import 'package:tidy_nook/monet/billing.dart';
import 'package:tidy_nook/monet/consent.dart';
import 'package:tidy_nook/services/haptics.dart';
import 'package:tidy_nook/services/reminder.dart';
import 'package:tidy_nook/services/review.dart';
import 'package:tidy_nook/services/telemetry.dart';

/// Ads, purchases, haptics, review, reminder and analytics, wired to
/// [Progress] as docs/MONETIZATION.md (Part 1) describes. Off a real Android
/// device (web, widget tests, desktop) every part is a silent no-op.
class AppServices {
  AppServices._({
    required this.consent,
    required this.ads,
    required this.billing,
    required this.haptics,
    required this.review,
    required this.reminder,
    required this.telemetry,
  });

  factory AppServices.create(Progress progress, {Telemetry? telemetry}) {
    final tel = telemetry ?? Telemetry.instance;
    final consent = Consent();
    final ads = Ads(
      state: CallbackAdsState(
        adsRemoved: () => progress.noAds,
        counter: () => progress.interstitialCounter,
        lastAdMs: () => progress.lastFullScreenAdMs,
        write: (counter, lastAdMs) {
          progress.interstitialCounter = counter < 0 ? 0 : counter;
          progress.lastFullScreenAdMs = lastAdMs < 0 ? 0 : lastAdMs;
          unawaited(progress.save());
        },
      ),
      consent: consent,
      onEvent: tel.logAd,
    );
    consent.onStatus = (s) => unawaited(tel.applyUmpStatus(s));
    final billing = Billing(
      adsRemoved: progress.adsRemoved,
      supporter: progress.supporter,
      onEntitlements: ({required bool adsRemoved, required bool supporter}) {
        progress.setEntitlements(adsRemoved: adsRemoved, supporter: supporter);
        ads.entitlementsChanged();
      },
    );
    return AppServices._(
      consent: consent,
      ads: ads,
      billing: billing,
      haptics: Haptics(enabled: () => progress.vibration),
      review: ReviewPrompt(),
      reminder: Reminder(),
      telemetry: tel,
    );
  }

  final Consent consent;
  final Ads ads;
  final Billing billing;
  final Haptics haptics;
  final ReviewPrompt review;
  final Reminder reminder;
  final Telemetry telemetry;

  bool _started = false;
  bool _disposed = false;

  /// After the first frame: telemetry first (so the consent result reaches
  /// Firebase), then ads (starts UMP, returns quickly), then billing.
  /// Never throws and never blocks the UI.
  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    try {
      await telemetry.init();
    } catch (_) {}
    if (_disposed) {
      return;
    }
    try {
      await ads.init();
    } catch (_) {}
    if (_disposed) {
      return;
    }
    try {
      await billing.init();
    } catch (_) {}
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      billing.dispose();
    } catch (_) {}
    try {
      ads.dispose();
    } catch (_) {}
  }
}
