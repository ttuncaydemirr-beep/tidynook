import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:tidy_nook/monet/ad_rules.dart';
import 'package:tidy_nook/monet/ads.dart';
import 'package:tidy_nook/monet/env.dart';

class FakeBackend implements FullScreenAdsBackend {
  bool iReady = false;
  bool rReady = false;
  int preloads = 0;
  int interstitialShows = 0;
  int rewardedShows = 0;
  int releases = 0;
  Completer<bool>? iShow;
  Completer<void>? rShow;
  VoidCallback? onReward;
  VoidCallback? onScreen;

  @override
  bool get sdkReady => true;
  @override
  bool get interstitialReady => iReady;
  @override
  bool get rewardedReady => rReady;
  @override
  Future<void> start() async {}
  @override
  void preload() => preloads++;
  @override
  Future<bool> showInterstitial({VoidCallback? onScreen}) {
    interstitialShows++;
    iReady = false;
    this.onScreen = onScreen;
    iShow = Completer<bool>();
    return iShow!.future;
  }

  @override
  Future<void> showRewarded({required VoidCallback onReward, VoidCallback? onScreen}) {
    rewardedShows++;
    rReady = false;
    this.onReward = onReward;
    this.onScreen = onScreen;
    rShow = Completer<void>();
    return rShow!.future;
  }

  @override
  void releaseShowing() {
    releases++;
    if (iShow != null && !iShow!.isCompleted) {
      iShow!.complete(true);
    }
    if (rShow != null && !rShow!.isCompleted) {
      rShow!.complete();
    }
  }

  @override
  void dispose() {}
}

void main() {
  late FakeBackend backend;
  late MemoryAdsState state;
  late int clock;
  late List<String> events;

  Ads make({bool enabled = true}) => Ads(
        state: state,
        backend: backend,
        enabled: enabled,
        clock: () => clock,
        returnGrace: const Duration(milliseconds: 10),
        onEvent: (f, r) => events.add('$f:$r'),
      );

  setUp(() {
    backend = FakeBackend();
    state = MemoryAdsState();
    clock = 1000 * 1000 * 1000;
    events = <String>[];
  });

  test('plugins are off in flutter test', () {
    expect(MonetEnv.pluginsEnabled, isFalse);
    expect(MonetEnv.inTest, isTrue);
  });

  test('a disabled Ads (web/tests) never shows and still counts boxes', () async {
    final ads = make(enabled: false);
    state.interstitialCounter = 5;
    expect(await ads.maybeInterstitial(completedLevelIndex: 8, isDaily: false), isFalse);
    expect(state.interstitialCounter, 6);
    expect(await ads.showRewarded('surprise_box'), isFalse);
    expect(ads.bannerAllowed, isFalse);
    expect(ads.privacyOptionsRequired, isFalse);
    await ads.init(); // no-op, no throw
    ads.dispose();
  });

  test('maybeInterstitial returns false at once when nothing is loaded', () async {
    final ads = make();
    state.interstitialCounter = 2; // this box makes it 3: an ad is due
    final sw = Stopwatch()..start();
    final shown = await ads.maybeInterstitial(completedLevelIndex: 4, isDaily: false);
    expect(shown, isFalse);
    expect(sw.elapsedMilliseconds, lessThan(200));
    expect(backend.interstitialShows, 0);
    expect(backend.preloads, 1);
    expect(state.interstitialCounter, 3, reason: 'the counter keeps the box, so the next exit can show');
    expect(events, <String>['interstitial:skipped']);
    ads.dispose();
  });

  test('a loaded interstitial is shown when due and the Future waits for it to close', () async {
    final ads = make();
    backend.iReady = true;
    state.interstitialCounter = 2;
    var done = false;
    final f = ads.maybeInterstitial(completedLevelIndex: 4, isDaily: false).then((v) {
      done = true;
      return v;
    });
    await Future<void>.delayed(Duration.zero);
    expect(backend.interstitialShows, 1);
    expect(ads.isShowingFullScreen, isTrue);
    expect(state.interstitialCounter, 0);
    expect(state.lastFullScreenAdMs, clock);
    expect(done, isFalse);
    backend.iShow!.complete(true);
    expect(await f, isTrue);
    expect(ads.isShowingFullScreen, isFalse);
    expect(events, <String>['interstitial:shown']);
    ads.dispose();
  });

  test('not due: before level index 3, daily, too soon, ads removed', () async {
    final ads = make();
    backend.iReady = true;

    state.interstitialCounter = 9;
    expect(await ads.maybeInterstitial(completedLevelIndex: 2, isDaily: false), isFalse);

    state.interstitialCounter = 9;
    expect(await ads.maybeInterstitial(completedLevelIndex: 9, isDaily: true), isFalse);
    expect(state.interstitialCounter, 9, reason: 'daily boxes do not count');

    state.lastFullScreenAdMs = clock - 30 * 1000;
    expect(await ads.maybeInterstitial(completedLevelIndex: 9, isDaily: false), isFalse);

    state.lastFullScreenAdMs = 0;
    state.adsRemoved = true;
    expect(await ads.maybeInterstitial(completedLevelIndex: 9, isDaily: false), isFalse);

    expect(backend.interstitialShows, 0);
    ads.dispose();
  });

  test('returning from the ad without an SDK event releases the wait', () async {
    final ads = make();
    backend.iReady = true;
    state.interstitialCounter = 3;
    final f = ads.maybeInterstitial(completedLevelIndex: 5, isDaily: false);
    await Future<void>.delayed(Duration.zero);
    backend.onScreen?.call();
    ads.debugLifecycle(AppLifecycleState.inactive);
    ads.debugLifecycle(AppLifecycleState.resumed);
    expect(await f.timeout(const Duration(seconds: 2)), isTrue);
    expect(backend.releases, 1);
    ads.dispose();
  });

  test('showRewarded is false at once when no rewarded ad is ready', () async {
    final ads = make();
    final sw = Stopwatch()..start();
    expect(await ads.showRewarded('streak_save'), isFalse);
    expect(sw.elapsedMilliseconds, lessThan(200));
    expect(backend.rewardedShows, 0);
    expect(backend.preloads, 1);
    expect(events, <String>['rewarded:unavailable']);
    ads.dispose();
  });

  test('showRewarded is true only when the reward was earned, and sets the ad gap', () async {
    final ads = make();
    backend.rReady = true;
    final f = ads.showRewarded('surprise_box');
    await Future<void>.delayed(Duration.zero);
    backend.onScreen?.call();
    backend.onReward?.call();
    backend.rShow!.complete();
    expect(await f, isTrue);
    expect(state.lastFullScreenAdMs, clock);

    backend.rReady = true;
    final g = ads.showRewarded('surprise_box');
    await Future<void>.delayed(Duration.zero);
    backend.onScreen?.call();
    backend.rShow!.complete(); // closed early, no reward
    expect(await g, isFalse);
    expect(events, <String>['rewarded:rewarded', 'rewarded:closed']);
    ads.dispose();
  });

  test('a rewarded ad right before blocks the interstitial for 90 s', () async {
    final ads = make();
    backend.rReady = true;
    final f = ads.showRewarded('surprise_box');
    await Future<void>.delayed(Duration.zero);
    backend.onScreen?.call();
    backend.onReward?.call();
    backend.rShow!.complete();
    await f;

    backend.iReady = true;
    state.interstitialCounter = 5;
    clock += 30 * 1000;
    expect(await ads.maybeInterstitial(completedLevelIndex: 7, isDaily: false), isFalse);
    clock += 61 * 1000;
    final g = ads.maybeInterstitial(completedLevelIndex: 8, isDaily: false);
    await Future<void>.delayed(Duration.zero);
    expect(backend.interstitialShows, 1);
    backend.iShow!.complete(true);
    expect(await g, isTrue);
    ads.dispose();
  });

  test('only one full-screen ad at a time', () async {
    final ads = make();
    backend.iReady = true;
    backend.rReady = true;
    state.interstitialCounter = 3;
    final f = ads.maybeInterstitial(completedLevelIndex: 5, isDaily: false);
    await Future<void>.delayed(Duration.zero);
    expect(await ads.showRewarded('surprise_box'), isFalse);
    backend.iShow!.complete(false);
    expect(await f, isFalse);
    expect(events.last, 'interstitial:failed');
    ads.dispose();
  });
}
