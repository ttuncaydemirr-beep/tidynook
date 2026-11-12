// AdMob interstitial + rewarded for Tidy Nook (ported from Arrowtile's ads_service.dart and the
// "hold" design of its core/ads_rules.dart; read Arrowtile docs/18 and docs/21 for the history).
//
// Lessons kept from Arrowtile:
//  - NEVER wait for an ad to LOAD. If nothing is loaded when the player leaves the win card, skip
//    silently and continue at once (Arrowtile froze while an unapproved AdMob account had no fill).
//  - Once show() HAS been called, the SDK cannot take it back (dispose does not cancel it, and a slow
//    device may open the ad seconds later). So maybeInterstitial completes only when the ad is closed,
//    fails to show, or the app comes back from the ad (lifecycle), never on a timer: otherwise the ad
//    would appear in the middle of the next level. A "slow" callback fires after 20 s so the UI may
//    show a hint; the wait still continues. Real devices open the ad within about a second.
//  - Ads are requested only after UMP says canRequestAds(); loads retry with a growing back-off;
//    a loaded ad is refreshed after 55 minutes (AdMob ads expire after one hour).
//  - Max ad content rating T (13+ audience), child-directed treatment and under-age-of-consent tags
//    UNSPECIFIED (AdsConfig.maxAdContentRating). Tidy Nook has no banner (owner's Banner Decisions doc).
// Everything is a no-op on the web, in tests and off Android ([MonetEnv.pluginsEnabled]); nothing throws.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_rules.dart';
import 'ads_config.dart';
import 'consent.dart';
import 'env.dart';

/// The SDK side of full-screen ads. [AdMobBackend] is the real one; tests use a fake.
abstract class FullScreenAdsBackend {
  /// MobileAds is initialised (after consent).
  bool get sdkReady;
  bool get interstitialReady;
  bool get rewardedReady;

  /// Initialises the SDK once and starts loading one interstitial and one rewarded ad.
  Future<void> start();

  /// Starts a load if none is loaded or loading (never shows anything).
  void preload();

  /// Shows the loaded interstitial. Completes true when it was closed, false if it could not be shown.
  /// [onScreen] is called when it is really on screen.
  Future<bool> showInterstitial({VoidCallback? onScreen});

  /// Shows the loaded rewarded ad; [onReward] at most once; completes when it is closed or failed.
  Future<void> showRewarded({required VoidCallback onReward, VoidCallback? onScreen});

  /// The app came back from the ad but no SDK event arrived: forget the running show.
  void releaseShowing();

  void dispose();
}

/// Interstitials, rewarded ads and the privacy options entry point.
///
/// Create one in main.dart, call [init] once after the first frame, pass it down to the UI.
class Ads extends ChangeNotifier with WidgetsBindingObserver {
  Ads({
    required this.state,
    Consent? consent,
    FullScreenAdsBackend? backend,
    bool? enabled,
    int Function()? clock,
    this.slowAfter = const Duration(seconds: 20),
    this.returnGrace = const Duration(milliseconds: 1500),
    this.onEvent,
  })  : consent = consent ?? Consent(),
        _enabled = enabled ?? MonetEnv.pluginsEnabled,
        _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _backend = backend ?? (_enabled ? AdMobBackend() : null);
  }

  /// Persisted counters and the "ads removed" flag (Progress, through [CallbackAdsState]).
  final AdsState state;
  final Consent consent;
  final bool _enabled;
  final int Function() _clock;
  FullScreenAdsBackend? _backend;

  /// After this long without an SDK event, [maybeInterstitial]'s / [showRewarded]'s `onSlow` is called.
  final Duration slowAfter;

  /// After the app returns from the ad, wait this long for the SDK's "closed" event.
  final Duration returnGrace;

  /// Analytics hook: (format, result). format: interstitial | rewarded;
  /// result: shown | skipped | failed | rewarded | closed | unavailable. Errors are swallowed.
  final void Function(String format, String result)? onEvent;

  bool _initStarted = false;
  bool _disposed = false;
  _Hold? _hold;

  /// The backend can be used (Android device, not a test, not the web).
  bool get enabled => _enabled && _backend != null;

  /// The ads SDK is running (consent allows ads, MobileAds initialised).
  bool get sdkReady => enabled && (_backend?.sdkReady ?? false);

  bool get interstitialReady => enabled && (_backend?.interstitialReady ?? false);

  /// A rewarded ad is loaded and can be shown at once.
  bool get rewardedReady => enabled && (_backend?.rewardedReady ?? false);

  /// A full-screen ad is being shown (show() was called and has not finished).
  bool get isShowingFullScreen => _hold != null;

  bool get privacyOptionsRequired => enabled && consent.privacyOptionsRequired;

  Future<void> showPrivacyOptions() async {
    if (!enabled) {
      return;
    }
    await consent.showPrivacyOptions();
    notifyListeners();
  }

  /// Call after the entitlements changed (purchase/restore) so listeners refresh.
  void entitlementsChanged() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Starts consent and, when allowed, the SDK; preloads one interstitial and one rewarded ad.
  /// Safe to call more than once; returns quickly (never waits for the consent form); never throws.
  Future<void> init() async {
    if (!enabled || _initStarted || _disposed) {
      return;
    }
    _initStarted = true;
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
    consent.addReadyListener(() => unawaited(_startBackend()));
    final previous = consent.onChanged;
    consent.onChanged = () {
      previous?.call();
      if (!_disposed) {
        notifyListeners();
      }
    };
    try {
      await consent.gather();
    } catch (_) {}
    if (consent.canRequestAds) {
      await _startBackend();
    }
  }

  Future<void> _startBackend() async {
    final b = _backend;
    if (b == null || _disposed) {
      return;
    }
    try {
      await b.start();
    } catch (_) {}
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Optional: start loading ahead of time (e.g. when a level starts). Never shows anything.
  void preload() {
    if (!sdkReady) {
      return;
    }
    try {
      _backend?.preload();
    } catch (_) {}
  }

  void _event(String format, String result) {
    try {
      onEvent?.call(format, result);
    } catch (_) {}
  }

  /// Call ONLY when the player leaves a win card (taps Next / See house), after the box was completed.
  ///
  /// Counts the box, then shows an interstitial if the rules allow it AND one is already loaded.
  /// If none is loaded it returns false at once (no waiting, no spinner); the next one keeps loading.
  /// If one is shown, the Future completes when it is closed (true) or failed (false); navigate after it.
  /// For a bonus box pass `completedLevelIndex: kBonusBoxLevelIndex`.
  Future<bool> maybeInterstitial({
    required int completedLevelIndex,
    required bool isDaily,
    VoidCallback? onSlow,
  }) async {
    int counter;
    int lastAdMs;
    bool removed;
    try {
      counter = counterAfterBox(counter: state.interstitialCounter, isDaily: isDaily);
      lastAdMs = state.lastFullScreenAdMs;
      removed = state.adsRemoved;
    } catch (_) {
      return false;
    }
    final now = _clock();
    final due = AdsConfig.interstitialsEnabled &&
        shouldShowInterstitial(
      completedLevelIndex: completedLevelIndex,
      isDaily: isDaily,
      counter: counter,
      lastAdMs: lastAdMs,
      nowMs: now,
      adsRemoved: removed,
    );
    final b = _backend;
    if (!due || !enabled || b == null || _hold != null || _disposed) {
      _write(counter, lastAdMs);
      return false;
    }
    bool ready;
    try {
      ready = b.interstitialReady;
    } catch (_) {
      ready = false;
    }
    if (!ready) {
      _write(counter, lastAdMs);
      _event('interstitial', 'skipped');
      try {
        b.preload();
      } catch (_) {}
      return false;
    }
    _write(0, now);
    final shown = await _holdFor(() => b.showInterstitial(onScreen: _markOnScreen), onSlow);
    _event('interstitial', shown ? 'shown' : 'failed');
    return shown;
  }

  /// Shows a rewarded ad for [placement]: [kPlacementHint] (main spot: an extra hint once the free hints of
  /// the day are used, see [hintOffer]), [kPlacementSurpriseBox] or [kPlacementStreakSave].
  ///
  /// Completes true only if the reward was earned. Returns false AT ONCE when no rewarded ad is
  /// ready (the UI shows "No ad available right now"); a load is started for next time.
  Future<bool> showRewarded(String placement, {VoidCallback? onSlow}) async {
    final b = _backend;
    if (!enabled || b == null || _hold != null || _disposed) {
      _event('rewarded', 'unavailable');
      return false;
    }
    bool ready;
    try {
      ready = b.rewardedReady;
    } catch (_) {
      ready = false;
    }
    if (!ready) {
      _event('rewarded', 'unavailable');
      try {
        b.preload();
      } catch (_) {}
      return false;
    }
    var rewarded = false;
    var seen = false;
    await _holdFor(() async {
      await b.showRewarded(
        onReward: () => rewarded = true,
        onScreen: () {
          seen = true;
          _markOnScreen();
        },
      );
      return true;
    }, onSlow);
    if (seen || rewarded) {
      // a rewarded ad that was on screen also counts for the 90 s gap
      try {
        state.writeAdState(
          interstitialCounter: state.interstitialCounter,
          lastFullScreenAdMs: _clock(),
        );
      } catch (_) {}
    }
    _event('rewarded', rewarded ? 'rewarded' : 'closed');
    return rewarded;
  }

  void _write(int counter, int lastAdMs) {
    try {
      state.writeAdState(interstitialCounter: counter, lastFullScreenAdMs: lastAdMs);
    } catch (_) {}
  }

  void _markOnScreen() {
    _hold?.onScreen = true;
  }

  Future<bool> _holdFor(Future<bool> Function() start, VoidCallback? onSlow) async {
    final h = _Hold();
    _hold = h;
    notifyListeners();
    final slow = Timer(slowAfter, () {
      if (!h.done.isCompleted) {
        try {
          onSlow?.call();
        } catch (_) {}
      }
    });
    try {
      start().then<void>((v) {
        if (!h.done.isCompleted) {
          h.done.complete(v);
        }
      }, onError: (Object _) {
        if (!h.done.isCompleted) {
          h.done.complete(false);
        }
      });
    } catch (_) {
      if (!h.done.isCompleted) {
        h.done.complete(false);
      }
    }
    try {
      return await h.done.future;
    } finally {
      slow.cancel();
      h.grace?.cancel();
      if (identical(_hold, h)) {
        _hold = null;
      }
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  // ------------------------------------------------------------------ lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final h = _hold;
    if (state == AppLifecycleState.resumed) {
      consent.retryPending();
      if (h != null && (h.wentHard || (h.wentAway && h.onScreen))) {
        h.wentAway = false;
        h.wentHard = false;
        h.grace?.cancel();
        h.grace = Timer(returnGrace, () {
          if (h.done.isCompleted || !identical(_hold, h)) {
            return;
          }
          try {
            _backend?.releaseShowing();
          } catch (_) {}
          if (!h.done.isCompleted) {
            h.done.complete(h.onScreen);
          }
        });
      } else if (h == null) {
        preload();
      }
      return;
    }
    if (h == null) {
      return;
    }
    // The AdMob activity is translucent: often only "inactive" arrives while it is open.
    h.wentAway = true;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      h.wentHard = true;
    }
    h.grace?.cancel();
    h.grace = null;
  }

  /// Test hook: simulate the lifecycle without a binding.
  @visibleForTesting
  void debugLifecycle(AppLifecycleState st) => didChangeAppLifecycleState(st);

  @override
  void dispose() {
    _disposed = true;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    final h = _hold;
    if (h != null && !h.done.isCompleted) {
      h.done.complete(false);
    }
    try {
      _backend?.dispose();
    } catch (_) {}
    _backend = null;
    super.dispose();
  }
}

class _Hold {
  bool onScreen = false;
  bool wentAway = false;
  bool wentHard = false;
  Timer? grace;
  final Completer<bool> done = Completer<bool>();
}

/// The real AdMob backend (Android only).
class AdMobBackend implements FullScreenAdsBackend {
  static const int _maxAgeMs = 55 * 60 * 1000;
  static const int _retryMinMs = 15000;
  static const int _retryMaxMs = 10 * 60 * 1000;
  static const int _loadStaleMs = 30 * 1000;
  static const int _closeDelayMs = 350; // the reward event sometimes arrives just after "closed"

  bool _started = false;
  bool _sdkReady = false;
  bool _disposed = false;
  bool _showing = false;

  InterstitialAd? _interstitial;
  int _interstitialAt = 0;
  bool _loadingI = false;
  int _loadStartI = 0;
  int _genI = 0;
  int _retryI = _retryMinMs;
  int _nextI = 0;
  Timer? _retryTimerI;

  RewardedAd? _rewarded;
  int _rewardedAt = 0;
  bool _loadingR = false;
  int _loadStartR = 0;
  int _genR = 0;
  int _retryR = _retryMinMs;
  int _nextR = 0;
  Timer? _retryTimerR;

  VoidCallback? _release;

  static int _now() => DateTime.now().millisecondsSinceEpoch;
  static bool _expired(int at) => at > 0 && _now() - at > _maxAgeMs;

  static void _log(String m) {
    if (kDebugMode || AdsConfig.usingTestIdsInRelease) {
      debugPrint('Ads: $m');
    }
  }

  @override
  bool get sdkReady => _sdkReady && !_disposed;

  @override
  bool get interstitialReady => sdkReady && _interstitial != null && !_expired(_interstitialAt);

  @override
  bool get rewardedReady => sdkReady && _rewarded != null && !_expired(_rewardedAt);

  @override
  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: AdsConfig.maxAdContentRating, // 'T' == MaxAdContentRating.t
          // Not child-directed, but not tagged "no" either: UNSPECIFIED (-1). Explicit on purpose.
          // ignore: deprecated_member_use
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
          // ignore: deprecated_member_use
          tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
        ),
      );
      await MobileAds.instance.initialize();
      _sdkReady = true;
      _log('MobileAds initialized${AdsConfig.usingTestIdsInRelease ? ' (TEST units in release)' : ''}');
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      _log('initialize failed: $e');
      _started = false;
    }
  }

  @override
  void preload() {
    if (!sdkReady) {
      return;
    }
    if (_interstitial == null || _expired(_interstitialAt)) {
      _loadInterstitial();
    }
    if (_rewarded == null || _expired(_rewardedAt)) {
      _loadRewarded();
    }
  }

  @override
  void releaseShowing() => _release?.call();

  @override
  Future<bool> showInterstitial({VoidCallback? onScreen}) {
    final ad = _interstitial;
    if (ad == null || _showing || _disposed || _expired(_interstitialAt)) {
      return Future<bool>.value(false);
    }
    _interstitial = null;
    final c = Completer<bool>();
    var dead = false;
    var showed = false;
    void finish(bool v) {
      _release = null;
      _showing = false;
      if (!c.isCompleted) {
        c.complete(v);
      }
    }

    _showing = true;
    _release = () {
      if (dead) {
        return;
      }
      dead = true;
      try {
        ad.dispose();
      } catch (_) {}
      finish(showed);
      _loadInterstitial();
    };
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (InterstitialAd a) {
        if (dead) {
          return;
        }
        showed = true;
        onScreen?.call();
      },
      onAdDismissedFullScreenContent: (InterstitialAd a) {
        a.dispose();
        if (dead) {
          return;
        }
        dead = true;
        finish(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd a, AdError error) {
        _log('interstitial failed to show: ${error.message}');
        a.dispose();
        if (dead) {
          return;
        }
        dead = true;
        finish(false);
        _loadInterstitial();
      },
    );
    try {
      ad.show().catchError((Object e) {
        if (!dead) {
          dead = true;
          finish(false);
        }
      });
    } catch (e) {
      dead = true;
      finish(false);
    }
    return c.future;
  }

  @override
  Future<void> showRewarded({required VoidCallback onReward, VoidCallback? onScreen}) {
    final ad = _rewarded;
    if (ad == null || _showing || _disposed || _expired(_rewardedAt)) {
      return Future<void>.value();
    }
    _rewarded = null;
    final c = Completer<void>();
    var dead = false;
    var noReward = false;
    var rewarded = false;
    void done() {
      _release = null;
      _showing = false;
      if (!c.isCompleted) {
        c.complete();
      }
    }

    _showing = true;
    _release = () {
      if (dead) {
        return;
      }
      dead = true;
      try {
        ad.dispose();
      } catch (_) {}
      done();
      _loadRewarded();
    };
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (RewardedAd a) {
        if (!dead) {
          onScreen?.call();
        }
      },
      onAdDismissedFullScreenContent: (RewardedAd a) {
        a.dispose();
        if (dead) {
          return;
        }
        dead = true;
        _release = null;
        _showing = false;
        Timer(const Duration(milliseconds: _closeDelayMs), () {
          if (!c.isCompleted) {
            c.complete();
          }
        });
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd a, AdError error) {
        _log('rewarded failed to show: ${error.message}');
        a.dispose();
        if (dead) {
          return;
        }
        dead = true;
        noReward = true;
        done();
        _loadRewarded();
      },
    );
    try {
      ad.show(onUserEarnedReward: (AdWithoutView a, RewardItem reward) {
        if (!noReward && !rewarded && !c.isCompleted) {
          rewarded = true;
          onReward();
        }
      }).catchError((Object e) {
        if (!dead) {
          dead = true;
          noReward = true;
          done();
        }
      });
    } catch (e) {
      dead = true;
      noReward = true;
      done();
    }
    return c.future;
  }

  void _loadInterstitial() {
    if (!sdkReady) {
      return;
    }
    if (_loadingI && _now() - _loadStartI < _loadStaleMs) {
      return;
    }
    if (_now() < _nextI) {
      return;
    }
    if (_interstitial != null && !_expired(_interstitialAt)) {
      return;
    }
    _loadingI = true;
    _loadStartI = _now();
    final gen = ++_genI;
    try {
      InterstitialAd.load(
        adUnitId: AdsConfig.interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            if (gen == _genI) {
              _loadingI = false;
            }
            if (_disposed) {
              ad.dispose();
              return;
            }
            _interstitial?.dispose();
            _interstitial = ad;
            _interstitialAt = _now();
            _retryI = _retryMinMs;
            _nextI = 0;
            _log('interstitial loaded');
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (gen != _genI) {
              return;
            }
            _loadingI = false;
            _interstitial = null;
            _log('interstitial failed to load (${error.code}): ${error.message}');
            final wait = _retryI;
            _retryI = math.min(_retryMaxMs, _retryI * 2);
            _nextI = _now() + wait;
            _retryTimerI?.cancel();
            _retryTimerI = Timer(Duration(milliseconds: wait), _loadInterstitial);
          },
        ),
      );
    } catch (e) {
      _loadingI = false;
      _log('interstitial load exception: $e');
    }
  }

  void _loadRewarded() {
    if (!sdkReady) {
      return;
    }
    if (_loadingR && _now() - _loadStartR < _loadStaleMs) {
      return;
    }
    if (_now() < _nextR) {
      return;
    }
    if (_rewarded != null && !_expired(_rewardedAt)) {
      return;
    }
    _loadingR = true;
    _loadStartR = _now();
    final gen = ++_genR;
    try {
      RewardedAd.load(
        adUnitId: AdsConfig.rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            if (gen == _genR) {
              _loadingR = false;
            }
            if (_disposed) {
              ad.dispose();
              return;
            }
            _rewarded?.dispose();
            _rewarded = ad;
            _rewardedAt = _now();
            _retryR = _retryMinMs;
            _nextR = 0;
            _log('rewarded loaded');
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (gen != _genR) {
              return;
            }
            _loadingR = false;
            _rewarded = null;
            _log('rewarded failed to load (${error.code}): ${error.message}');
            final wait = _retryR;
            _retryR = math.min(_retryMaxMs, _retryR * 2);
            _nextR = _now() + wait;
            _retryTimerR?.cancel();
            _retryTimerR = Timer(Duration(milliseconds: wait), _loadRewarded);
          },
        ),
      );
    } catch (e) {
      _loadingR = false;
      _log('rewarded load exception: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimerI?.cancel();
    _retryTimerR?.cancel();
    try {
      _interstitial?.dispose();
      _rewarded?.dispose();
    } catch (_) {}
    _interstitial = null;
    _rewarded = null;
  }
}
