// Google UMP consent (EEA/UK/Switzerland), ported from Arrowtile (ads_service.dart gatherConsent,
// core/consent_gate.dart, services/consent_signals.dart).
//
// Google's documented pattern, plus Arrowtile's lesson (its docs/16: the form loaded late from the
// network, appeared over a running level and swallowed the player's taps):
//  - the consent info update runs ONCE per app start;
//  - the form is shown only while the app is in the foreground AND the player is not in a level
//    ([Consent.canInterrupt]); otherwise it waits and is shown at most once later ([Consent.retryPending]);
//  - ads are requested only when UMP says canRequestAds();
//  - a "Privacy choices" row belongs in Settings only when [Consent.privacyOptionsRequired] is true.
// Every call is a no-op on the web, in tests and off Android ([MonetEnv.pluginsEnabled]); nothing throws.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding;
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';
import 'env.dart';

/// Pure decision logic for WHEN the consent form may be shown (unit-tested).
class ConsentFormGate {
  bool _started = false;
  bool _updating = false;
  bool _busy = false;
  bool _pending = false;

  /// True only for the first call of an app run.
  bool beginSession() {
    if (_started) {
      return false;
    }
    _started = true;
    _updating = true;
    return true;
  }

  void updateFailed() => _updating = false;

  /// May the form be loaded and shown now? If true, call [finished] when it is done.
  bool tryShow({required bool foreground, bool interruptible = true}) {
    _updating = false;
    if (_busy) {
      return false;
    }
    if (!foreground || !interruptible) {
      _pending = true;
      return false;
    }
    _pending = false;
    _busy = true;
    return true;
  }

  /// A postponed form may be shown now (never starts a new one).
  bool retryPending({required bool foreground, bool interruptible = true}) =>
      _pending && tryShow(foreground: foreground, interruptible: interruptible);

  void finished() => _busy = false;

  bool get pending => _pending;
  bool get busy => _busy;

  /// The consent flow (info update or form) is running.
  bool get active => _updating || _busy;
}

/// Firebase Analytics consent signals (Consent Mode v2). Default: everything denied.
@immutable
class TelemetryConsent {
  final bool analyticsStorage;
  final bool adStorage;
  final bool adUserData;
  final bool adPersonalization;

  const TelemetryConsent({
    this.analyticsStorage = false,
    this.adStorage = false,
    this.adUserData = false,
    this.adPersonalization = false,
  });

  static const TelemetryConsent denied = TelemetryConsent();

  @override
  bool operator ==(Object other) =>
      other is TelemetryConsent &&
      other.analyticsStorage == analyticsStorage &&
      other.adStorage == adStorage &&
      other.adUserData == adUserData &&
      other.adPersonalization == adPersonalization;

  @override
  int get hashCode => Object.hash(analyticsStorage, adStorage, adUserData, adPersonalization);

  @override
  String toString() => 'TelemetryConsent(analytics=$analyticsStorage, adStorage=$adStorage, '
      'adUserData=$adUserData, adPersonalization=$adPersonalization)';
}

/// Derives the Firebase consent signals from the UMP result (pure, unit-tested; same rules as Arrowtile).
///  - [umpStatus]: notRequired | required | obtained | unknown (ConsentStatus.name).
///  - [gdprApplies] / [purposeConsents]: IABTCF_gdprApplies and IABTCF_PurposeConsents written by UMP.
/// Consent not required (outside the EEA/UK/CH): analytics on. Obtained under GDPR: TCF purpose 1
/// (storage) and 7 (ad user data). Pending/unknown: all off. Ad personalization is ALWAYS off.
TelemetryConsent deriveTelemetryConsent({
  required String umpStatus,
  bool gdprApplies = false,
  String? purposeConsents,
}) {
  switch (umpStatus) {
    case 'notRequired':
      return const TelemetryConsent(analyticsStorage: true, adStorage: true, adUserData: true);
    case 'obtained':
      if (!gdprApplies) {
        return const TelemetryConsent(analyticsStorage: true, adStorage: true, adUserData: true);
      }
      final p = purposeConsents ?? '';
      bool purpose(int n) => p.length >= n && p[n - 1] == '1';
      final storage = purpose(1);
      return TelemetryConsent(analyticsStorage: storage, adStorage: storage, adUserData: storage && purpose(7));
    default:
      return TelemetryConsent.denied;
  }
}

/// Reads the IABTCF_* values UMP wrote into the app's default SharedPreferences
/// (MainActivity.kt channel "com.tidynook.game/consent"; Flutter's shared_preferences uses another file).
class ConsentSignals {
  ConsentSignals._();

  static const MethodChannel _channel = MethodChannel('com.tidynook.game/consent');

  static Future<({bool gdprApplies, String? purposeConsents})?> readTcf() async {
    if (!MonetEnv.pluginsEnabled) {
      return null;
    }
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>('tcf');
      if (m == null) {
        return null;
      }
      final g = m['gdprApplies'];
      final p = m['purposeConsents'];
      return (
        gdprApplies: g == 1 || g == '1' || g == true,
        purposeConsents: p is String && p.isNotEmpty ? p : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// UMP status name -> Firebase consent signals. If the TCF values cannot be read, GDPR is assumed
  /// (safe default: analytics stays off).
  static Future<TelemetryConsent> resolve(String umpStatus) async {
    ({bool gdprApplies, String? purposeConsents})? tcf;
    if (umpStatus == 'obtained') {
      tcf = await readTcf();
    }
    return deriveTelemetryConsent(
      umpStatus: umpStatus,
      gdprApplies: tcf?.gdprApplies ?? true,
      purposeConsents: tcf?.purposeConsents,
    );
  }
}

/// The UMP consent flow. Created once (main.dart) and handed to [Ads].
class Consent {
  Consent({this.canInterrupt});

  /// Returns false while the player is in a level (the form is postponed until they leave it).
  bool Function()? canInterrupt;

  /// Called when [privacyOptionsRequired] or [canRequestAds] changes (Settings / banner can refresh).
  VoidCallback? onChanged;

  /// Called with the UMP status name (notRequired | required | obtained | unknown) after every update.
  /// Wire it to Telemetry.applyUmpStatus.
  void Function(String umpStatus)? onStatus;

  final ConsentFormGate _gate = ConsentFormGate();
  final List<VoidCallback> _readyListeners = <VoidCallback>[];
  bool _privacyRequired = false;
  bool _canRequestAds = false;

  bool get privacyOptionsRequired => _privacyRequired;

  /// UMP allows ad requests (known after the first update; a consent from an earlier run counts at once).
  bool get canRequestAds => _canRequestAds;

  /// The flow (update or form) is still running.
  bool get busy => _gate.active;

  static void _log(String m) {
    if (kDebugMode) {
      debugPrint('Consent: $m');
    }
  }

  /// [fn] is called (once per change to true) when ads may be requested.
  void addReadyListener(VoidCallback fn) => _readyListeners.add(fn);

  /// Starts the consent flow once per app run. Returns quickly: it never waits for the form.
  Future<void> gather() async {
    if (!MonetEnv.pluginsEnabled || !_gate.beginSession()) {
      return;
    }
    try {
      ConsentDebugSettings? dbg;
      if (kDebugMode && (AdsConfig.umpDebugGeographyEea || AdsConfig.umpTestDeviceId.isNotEmpty)) {
        dbg = ConsentDebugSettings(
          debugGeography: AdsConfig.umpDebugGeographyEea ? DebugGeography.debugGeographyEea : null,
          testIdentifiers: AdsConfig.umpTestDeviceId.isEmpty ? null : <String>[AdsConfig.umpTestDeviceId],
        );
      }
      final params = ConsentRequestParameters(tagForUnderAgeOfConsent: false, consentDebugSettings: dbg);
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () {
          _log('info updated');
          _showFormIfPossible();
        },
        (FormError error) {
          _log('update failed: ${error.message}');
          _gate.updateFailed();
          unawaited(_afterUpdate());
        },
      );
    } catch (e) {
      _gate.updateFailed();
      _log('gather: $e');
    }
    // A consent given in an earlier run lets ads start right away.
    await _afterUpdate();
  }

  bool get _foreground {
    final st = WidgetsBinding.instance.lifecycleState;
    return st == null || st == AppLifecycleState.resumed;
  }

  bool get _interruptible {
    try {
      return canInterrupt?.call() ?? true;
    } catch (_) {
      return true;
    }
  }

  void _showFormIfPossible() {
    if (!_gate.tryShow(foreground: _foreground, interruptible: _interruptible)) {
      return;
    }
    _loadAndShowForm();
  }

  /// Call when the app returns to the foreground and when the player leaves a level:
  /// shows a postponed form (never starts a new one).
  void retryPending() {
    if (!MonetEnv.pluginsEnabled) {
      return;
    }
    if (_gate.retryPending(foreground: _foreground, interruptible: _interruptible)) {
      _loadAndShowForm();
    } else if (!_canRequestAds && !_gate.active) {
      unawaited(_afterUpdate());
    }
  }

  void _loadAndShowForm() {
    try {
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? formError) {
        _gate.finished();
        if (formError != null) {
          _log('form: ${formError.message}');
        }
        unawaited(_afterUpdate());
      });
    } catch (e) {
      _gate.finished();
      _log('form exception: $e');
      unawaited(_afterUpdate());
    }
  }

  Future<void> _afterUpdate() async {
    if (!MonetEnv.pluginsEnabled) {
      return;
    }
    try {
      final req = (await ConsentInformation.instance.getPrivacyOptionsRequirementStatus()) ==
          PrivacyOptionsRequirementStatus.required;
      final can = await ConsentInformation.instance.canRequestAds();
      final changed = req != _privacyRequired || can != _canRequestAds;
      final becameReady = can && !_canRequestAds;
      _privacyRequired = req;
      _canRequestAds = can;
      unawaited(_reportStatus());
      if (changed) {
        try {
          onChanged?.call();
        } catch (_) {}
      }
      if (becameReady) {
        for (final fn in List<VoidCallback>.of(_readyListeners)) {
          try {
            fn();
          } catch (_) {}
        }
      }
    } catch (e) {
      _log('afterUpdate: $e');
    }
  }

  Future<void> _reportStatus() async {
    try {
      final st = await ConsentInformation.instance.getConsentStatus();
      onStatus?.call(st.name);
    } catch (_) {}
  }

  /// Opens the UMP privacy options form (Settings > Privacy choices). Completes when it closes.
  Future<void> showPrivacyOptions() async {
    if (!MonetEnv.pluginsEnabled || !_privacyRequired) {
      return;
    }
    final c = Completer<void>();
    try {
      ConsentForm.showPrivacyOptionsForm((FormError? e) {
        if (e != null) {
          _log('privacy options: ${e.message}');
        }
        if (!c.isCompleted) {
          c.complete();
        }
      });
      await c.future.timeout(const Duration(minutes: 10), onTimeout: () {});
    } catch (e) {
      _log('privacy options exception: $e');
    }
    await _afterUpdate();
  }
}
