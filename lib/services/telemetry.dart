// Firebase Analytics + Crashlytics, fully optional (ported from Arrowtile's core/telemetry.dart and
// services/firebase_telemetry.dart).
//
//  - The app builds and runs WITHOUT android/app/google-services.json: then Firebase.initializeApp()
//    fails, [Telemetry.init] returns false and every call is a silent no-op. CI writes the file from
//    the GOOGLE_SERVICES_JSON secret when it is set (docs/MONETIZATION.md).
//  - No-op on the web, in tests and off Android. init() never throws and gives up after 5 s.
//  - Debug builds collect nothing (unless --dart-define=TELEMETRY_IN_DEBUG=true).
//  - Analytics collection starts OFF and is switched on only when the UMP consent result allows it
//    ([applyUmpStatus]); ad personalization signals are always off (Google signals are off too).
//  - Event parameters are numbers and fixed words only: no free text, no ids, no e-mail.
import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../monet/consent.dart' show ConsentSignals, TelemetryConsent;
import '../monet/env.dart';

class Telemetry {
  Telemetry({bool? enabled}) : _enabled = enabled ?? MonetEnv.pluginsEnabled;

  /// The app-wide instance (main.dart calls `Telemetry.instance.init()`).
  static final Telemetry instance = Telemetry();

  static const bool _inDebug = bool.fromEnvironment('TELEMETRY_IN_DEBUG');

  /// This build may collect (release/profile, or a debug build that asked for it).
  static bool get collectionAllowed => !kDebugMode || _inDebug;

  final bool _enabled;
  FirebaseAnalytics? _fa;
  FirebaseCrashlytics? _fc;
  bool _ready = false;
  bool _initStarted = false;

  /// Firebase is configured and initialised.
  bool get ready => _ready;

  static void _log(String m) {
    if (kDebugMode) {
      debugPrint('Telemetry: $m');
    }
  }

  /// Initialises Firebase and hooks Crashlytics into Flutter's error handlers. Returns true when Firebase
  /// is configured. Never throws; without google-services.json it simply returns false.
  Future<bool> init() async {
    if (!_enabled || _initStarted) {
      return _ready;
    }
    _initStarted = true;
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    } catch (e) {
      _log('Firebase not configured (${e.runtimeType}); telemetry off');
      return false;
    }
    try {
      final fc = FirebaseCrashlytics.instance;
      final fa = FirebaseAnalytics.instance;
      await fc.setCrashlyticsCollectionEnabled(collectionAllowed);
      await fa.setAnalyticsCollectionEnabled(false); // until consent is known
      _fc = fc;
      _fa = fa;
      _ready = true;
      _installCrashHandlers();
      return true;
    } catch (e) {
      _log('init: ${e.runtimeType}');
      return false;
    }
  }

  void _installCrashHandlers() {
    final previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      try {
        if (previous != null) {
          previous(details);
        } else {
          FlutterError.presentError(details);
        }
      } catch (_) {}
      final fc = _fc;
      if (fc != null) {
        try {
          unawaited(fc.recordFlutterFatalError(details).catchError((Object _) {}));
        } catch (_) {}
      }
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final fc = _fc;
      if (fc != null) {
        try {
          unawaited(fc.recordError(error, stack, fatal: true).catchError((Object _) {}));
        } catch (_) {}
      }
      return true;
    };
  }

  /// Wire to Consent.onStatus: derives the Firebase consent signals from the UMP status and applies them.
  Future<void> applyUmpStatus(String umpStatus) async {
    if (!_ready) {
      return;
    }
    try {
      await setConsent(await ConsentSignals.resolve(umpStatus));
    } catch (_) {}
  }

  Future<void> setConsent(TelemetryConsent c) async {
    final fa = _fa;
    if (!_ready || fa == null) {
      return;
    }
    try {
      await fa.setConsent(
        analyticsStorageConsentGranted: c.analyticsStorage,
        adStorageConsentGranted: c.adStorage,
        adUserDataConsentGranted: c.adUserData,
        adPersonalizationSignalsConsentGranted: c.adPersonalization,
      );
      await fa.setAnalyticsCollectionEnabled(c.analyticsStorage && collectionAllowed);
    } catch (e) {
      _log('setConsent: ${e.runtimeType}');
    }
  }

  void _event(String name, Map<String, Object> params) {
    final fa = _fa;
    if (!_ready || fa == null || !collectionAllowed) {
      return;
    }
    try {
      unawaited(fa.logEvent(name: name, parameters: params).catchError((Object _) {}));
    } catch (_) {}
  }

  // ------------------------------------------------------------------ events (all silent)
  /// A level was opened. [level] is the 0-based level index.
  void logLevelStart(int level, {bool mystery = false}) =>
      _event('level_start', <String, Object>{'level': level + 1, 'mystery': mystery ? 1 : 0});

  /// A level box was completed. [seconds] is clamped to 0..3600; [first] = first time done.
  void logLevelComplete(int level, {int seconds = 0, bool first = true, bool mystery = false}) =>
      _event('level_complete', <String, Object>{
        'level': level + 1,
        'duration_s': seconds.clamp(0, 3600).toInt(),
        'first': first ? 1 : 0,
        'mystery': mystery ? 1 : 0,
      });

  /// The daily box was completed; [streak] after it, [total] daily boxes so far.
  void logDaily({required int streak, required int total, int seconds = 0}) => _event('daily_complete', <String, Object>{
        'streak': streak.clamp(0, 10000).toInt(),
        'total': total.clamp(0, 100000).toInt(),
        'duration_s': seconds.clamp(0, 3600).toInt(),
      });

  /// Bonus box [n] (0-based) was completed.
  void logBonus(int n, {int seconds = 0}) => _event('bonus_complete', <String, Object>{
        'n': n + 1,
        'duration_s': seconds.clamp(0, 3600).toInt(),
      });

  /// A purchase SUCCEEDED (not for pending / cancelled / failed).
  void logPurchase(String productId, {String? currency, double? value}) {
    final fa = _fa;
    if (!_ready || fa == null || !collectionAllowed) {
      return;
    }
    try {
      unawaited(fa
          .logPurchase(
            currency: currency,
            value: value,
            items: <AnalyticsEventItem>[AnalyticsEventItem(itemId: productId, itemName: productId, quantity: 1)],
          )
          .catchError((Object _) {}));
    } catch (_) {}
  }

  /// Ad outcome (wire to Ads.onEvent). [format]: interstitial | rewarded;
  /// [result]: shown | skipped | failed | rewarded | closed | unavailable.
  void logAd(String format, String result) => _event('ad_$format', <String, Object>{'result': result});

  /// A rewarded offer was answered. [placement]: surprise_box | streak_save; [result]: rewarded | closed |
  /// unavailable | declined.
  void logRewarded(String placement, String result) =>
      _event('rewarded_offer', <String, Object>{'placement': placement, 'result': result});

  /// User property app_lang (tr | en | de | ar).
  void setLanguage(String lang) {
    final fa = _fa;
    if (!_ready || fa == null || !collectionAllowed) {
      return;
    }
    try {
      unawaited(fa.setUserProperty(name: 'app_lang', value: lang).catchError((Object _) {}));
    } catch (_) {}
  }
}
