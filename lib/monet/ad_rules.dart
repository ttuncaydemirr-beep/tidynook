// Pure ad pacing for Tidy Nook (no plugins; unit-tested in test/monet_ad_rules_test.dart).
//
// The owner's rules (docs/V1_1_PLAN.md, "Hard rules"):
//  - an interstitial only when the player LEAVES a win card (Next / See house), never during a level
//    or an animation; the caller guarantees that by calling Ads.maybeInterstitial only there;
//  - never before the 4th level is completed (completed level index >= 3);
//  - at most once every 3 completed boxes;
//  - at least 90 s after the previous full-screen ad (interstitial OR rewarded);
//  - never after a daily box;
//  - never when ads are removed (remove_ads or supporter_pack).

/// The first level index (0-based) whose completion may be followed by an interstitial.
const int kFirstAdLevelIndex = 3;

/// An interstitial at most once every this many completed boxes.
const int kInterstitialEvery = 3;

/// Minimum gap after any full-screen ad (interstitial or rewarded).
const int kMinFullScreenGapMs = 90 * 1000;

/// Pass this as `completedLevelIndex` for a bonus box (bonus boxes unlock after 12 levels,
/// so the "4th level" rule is always met for them).
const int kBonusBoxLevelIndex = 1 << 20;

/// The counter never grows past this (it only has to reach [kInterstitialEvery]).
const int kCounterCap = 99;

/// Should an interstitial be shown now (if one is loaded)?
///
/// [counter] is the number of boxes completed since the last interstitial, INCLUDING the box just
/// completed (see [counterAfterBox]). [lastAdMs] is the epoch ms of the last full-screen ad, 0 if none.
/// A [lastAdMs] in the future (clock set back) does not block ads forever.
bool shouldShowInterstitial({
  required int completedLevelIndex,
  required bool isDaily,
  required int counter,
  required int lastAdMs,
  required int nowMs,
  required bool adsRemoved,
}) {
  if (adsRemoved || isDaily) {
    return false;
  }
  if (completedLevelIndex < kFirstAdLevelIndex) {
    return false;
  }
  if (counter < kInterstitialEvery) {
    return false;
  }
  if (lastAdMs > 0 && nowMs >= lastAdMs && nowMs - lastAdMs < kMinFullScreenGapMs) {
    return false;
  }
  return true;
}

/// The counter after one more completed box. Daily boxes do not count (an ad never follows them,
/// and they must not make the next level's ad come sooner).
int counterAfterBox({required int counter, required bool isDaily}) {
  final c = counter < 0 ? 0 : counter;
  if (isDaily) {
    return c > kCounterCap ? kCounterCap : c;
  }
  return c + 1 > kCounterCap ? kCounterCap : c + 1;
}

/// Read and write access to the persisted ad state (in Tidy Nook: fields of Progress).
/// lib/monet does not import Progress; the UI connects the two (see docs/MONETIZATION.md).
abstract class AdsState {
  bool get adsRemoved;
  int get interstitialCounter;
  int get lastFullScreenAdMs;

  /// Stores both values (and saves).
  void writeAdState({required int interstitialCounter, required int lastFullScreenAdMs});
}

/// [AdsState] built from closures, so Progress can be connected without an adapter class:
///
/// ```dart
/// CallbackAdsState(
///   adsRemoved: () => progress.adsRemoved,
///   counter: () => progress.interstitialCounter,
///   lastAdMs: () => progress.lastFullScreenAdMs,
///   write: (counter, lastAdMs) { ...set both on progress and save... },
/// )
/// ```
class CallbackAdsState implements AdsState {
  CallbackAdsState({
    required bool Function() adsRemoved,
    required int Function() counter,
    required int Function() lastAdMs,
    required void Function(int counter, int lastAdMs) write,
  })  : _adsRemoved = adsRemoved,
        _counter = counter,
        _lastAdMs = lastAdMs,
        _write = write;

  final bool Function() _adsRemoved;
  final int Function() _counter;
  final int Function() _lastAdMs;
  final void Function(int counter, int lastAdMs) _write;

  @override
  bool get adsRemoved => _adsRemoved();

  @override
  int get interstitialCounter => _counter();

  @override
  int get lastFullScreenAdMs => _lastAdMs();

  @override
  void writeAdState({required int interstitialCounter, required int lastFullScreenAdMs}) =>
      _write(interstitialCounter, lastFullScreenAdMs);
}

/// In-memory [AdsState] (tests, or before Progress has the fields).
class MemoryAdsState implements AdsState {
  MemoryAdsState({this.adsRemoved = false, this.interstitialCounter = 0, this.lastFullScreenAdMs = 0});

  @override
  bool adsRemoved;

  @override
  int interstitialCounter;

  @override
  int lastFullScreenAdMs;

  int writes = 0;

  @override
  void writeAdState({required int interstitialCounter, required int lastFullScreenAdMs}) {
    this.interstitialCounter = interstitialCounter;
    this.lastFullScreenAdMs = lastFullScreenAdMs;
    writes++;
  }
}
