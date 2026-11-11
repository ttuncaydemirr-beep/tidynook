# Tidy Nook 1.1: ads, purchases, reminders, analytics

Owner of this file and of `lib/monet/**`, `lib/services/**`, `pubspec.yaml`, `android/**`, `.github/workflows/**`:
team member M. Ported from the owner's Arrowtile game (`/home/claude/Arrowtile/flutter/arrowtile`), keeping its
lessons (Arrowtile docs 13, 16, 18, 19, 21): never wait for an ad to load, never show a spinner for an ad, show
the consent form only outside a level, and never let an ad appear in the middle of a level.

Part 1 is for the UI owner (how to connect everything). Part 2 is the owner's checklist in plain words.
Part 3 lists every place a banner could go, with the risk of losing players.

---

## Part 1. Architecture and wiring guide (UI owner)

### What is where

| File | What it does |
| --- | --- |
| `lib/monet/env.dart` | `MonetEnv.pluginsEnabled`: true only on a real Android device outside `flutter test`. Every plugin call below is behind it, so on the web, in widget tests and on desktop everything is a silent no-op (no platform channel, no pending timer). |
| `lib/monet/ads_config.dart` | Ad unit IDs (Google TEST IDs now, `TODO(owner)` slots for the real ones). Debug/profile builds always use test IDs. |
| `lib/monet/ad_rules.dart` | Pure pacing rules + `AdsState` (the persisted counters, an interface so lib/monet does not import Progress). |
| `lib/monet/consent.dart` | Google UMP consent (EEA/UK/CH), the "when may the form appear" gate, Firebase consent signals. |
| `lib/monet/ads.dart` | `Ads`: interstitial + rewarded, privacy options. `AdMobBackend` is the real SDK side. |
| `lib/monet/house_banner.dart` | `HouseBanner`: adaptive anchored banner widget for the house screen bottom. |
| `lib/monet/billing.dart` | `Billing`: Play Billing for `remove_ads` and `supporter_pack` (non-consumable). |
| `lib/services/haptics.dart` | `Haptics.tick()` on snap, honouring Settings > Vibration. |
| `lib/services/review.dart` | `ReviewPrompt.maybeAsk(...)`: Play in-app review, once. |
| `lib/services/reminder.dart` | `Reminder`: daily 19:00 local notification for the next 7 evenings. |
| `lib/services/telemetry.dart` | `Telemetry`: Firebase Analytics + Crashlytics; no-op without `google-services.json`. |

### Public API (signatures)

```dart
// lib/monet/ad_rules.dart
const int kFirstAdLevelIndex = 3, kInterstitialEvery = 3, kMinFullScreenGapMs = 90000;
const int kBonusBoxLevelIndex;   // pass as completedLevelIndex for a bonus box
bool shouldShowInterstitial({required int completedLevelIndex, required bool isDaily, required int counter,
                             required int lastAdMs, required int nowMs, required bool adsRemoved});
int counterAfterBox({required int counter, required bool isDaily});
abstract class AdsState { bool get adsRemoved; int get interstitialCounter; int get lastFullScreenAdMs;
                          void writeAdState({required int interstitialCounter, required int lastFullScreenAdMs}); }
class CallbackAdsState implements AdsState { CallbackAdsState({required bool Function() adsRemoved,
    required int Function() counter, required int Function() lastAdMs, required void Function(int counter, int lastAdMs) write}); }
class MemoryAdsState implements AdsState { ... }   // tests

// lib/monet/consent.dart
class Consent {
  Consent({bool Function()? canInterrupt});   // false while the player is in a level
  bool Function()? canInterrupt; VoidCallback? onChanged; void Function(String umpStatus)? onStatus;
  bool get privacyOptionsRequired; bool get canRequestAds;
  Future<void> gather(); void retryPending(); Future<void> showPrivacyOptions();
}

// lib/monet/ads.dart
class Ads extends ChangeNotifier {
  Ads({required AdsState state, Consent? consent, void Function(String format, String result)? onEvent, ...});
  Future<void> init();                       // once, after the first frame; never waits for the consent form
  bool get sdkReady; bool get interstitialReady; bool get rewardedReady;
  bool get isShowingFullScreen;              // pause music/sounds while true (listen to Ads)
  bool get bannerAllowed;
  Future<bool> maybeInterstitial({required int completedLevelIndex, required bool isDaily, VoidCallback? onSlow});
  Future<bool> showRewarded(String placement, {VoidCallback? onSlow});   // 'surprise_box' | 'streak_save'
  void preload();                            // optional, e.g. when a level starts
  void entitlementsChanged();                // after a purchase/restore, hides the banner at once
  bool get privacyOptionsRequired; Future<void> showPrivacyOptions();
}

// lib/monet/house_banner.dart
class HouseBanner extends StatefulWidget { const HouseBanner({Key? key, required Ads? ads, bool visible = true, String? label}); }

// lib/monet/billing.dart
enum PurchaseEventKind { success, pending, failed, cancelled, restored }
class PurchaseEvent { final PurchaseEventKind kind; final String productId; }   // productId '' for restore
typedef EntitlementSink = void Function({required bool adsRemoved, required bool supporter});
class Billing {
  static const removeAdsId = 'remove_ads', supporterId = 'supporter_pack';
  Billing({required EntitlementSink onEntitlements, bool adsRemoved = false, bool supporter = false});
  Future<void> init(); bool get available; bool owns(String id); bool get adsRemoved; bool get supporter;
  String? priceOf(String id); double? rawPriceOf(String id); String? currencyOf(String id);
  Future<void> buy(String id); Future<void> restore(); Stream<PurchaseEvent> get events; void dispose();
}

// lib/services/*
class Haptics { Haptics({bool Function()? enabled}); void tick(); void success(); }
class ReviewPrompt { Future<bool> maybeAsk({required bool alreadyAsked, required int completedLevels,
                     required int lastFullScreenAdMs, required VoidCallback markAsked, int? nowMs}); }
class Reminder {
  Future<bool> requestAndEnable({required String title, required String body, required bool dailyDoneToday,
                                 String channelName = 'Daily reminder', DateTime? now});
  Future<void> disable();
  Future<void> reschedule({required bool enabled, required String title, required String body,
                           required bool dailyDoneToday, String channelName = 'Daily reminder', DateTime? now});
}
class Telemetry {
  static final Telemetry instance; Future<bool> init(); bool get ready;
  Future<void> applyUmpStatus(String umpStatus);
  void logLevelStart(int level, {bool mystery}); void logLevelComplete(int level, {int seconds, bool first, bool mystery});
  void logDaily({required int streak, required int total, int seconds}); void logBonus(int n, {int seconds});
  void logPurchase(String productId, {String? currency, double? value}); void logAd(String format, String result);
  void logRewarded(String placement, String result); void setLanguage(String lang);
}
```

### Wiring to Progress (A's members)

lib/monet never imports `lib/game`. Connect them in `main.dart` / the controller (names as in Contract A; if A
made the int fields plain fields, assign them and call `save()`, as below):

```dart
final progress = await Progress.load();
final telemetry = Telemetry.instance;
final consent = Consent();
final ads = Ads(
  state: CallbackAdsState(
    adsRemoved: () => progress.adsRemoved,
    counter: () => progress.interstitialCounter,
    lastAdMs: () => progress.lastFullScreenAdMs,
    write: (counter, lastAdMs) {
      progress.interstitialCounter = counter;
      progress.lastFullScreenAdMs = lastAdMs;
      unawaited(progress.save());           // or A's setter if it saves by itself
    },
  ),
  consent: consent,
  onEvent: telemetry.logAd,
);
consent.onStatus = (s) => unawaited(telemetry.applyUmpStatus(s));
consent.canInterrupt = () => controller.screen != AppScreen.play;   // no consent form over a level
final billing = Billing(
  adsRemoved: progress.adsRemoved,                 // cached: correct offline too
  supporter: progress.supporter,
  onEntitlements: ({required bool adsRemoved, required bool supporter}) {
    progress.setEntitlements(adsRemoved: adsRemoved, supporter: supporter);
    ads.entitlementsChanged();
  },
);
final haptics = Haptics(enabled: () => progress.vibration);
final review = ReviewPrompt();
final reminder = Reminder();
runApp(...);   // pass ads, billing, haptics, review, reminder, telemetry down (e.g. via the GameController)

// After the first frame, in this order (telemetry first, so the consent result reaches Firebase):
WidgetsBinding.instance.addPostFrameCallback((_) async {
  await telemetry.init();     // <= 5 s, false without google-services.json
  await ads.init();           // starts UMP; the SDK starts when consent allows; returns quickly
  await billing.init();       // prices + "what do I own" from Play
});
```

`Ads` observes the app lifecycle by itself (reloads on resume, releases a stuck show, retries a postponed
consent form). Also call `consent.retryPending()` when the player leaves a level (goHome / win card closed).

### Exact call sites

1. **Win card, Next / See house** (the ONLY place an interstitial may appear):
   ```dart
   onTap: () async {
     if (_leaving) return;                    // ignore double taps; NO spinner
     _leaving = true;
     await ads.maybeInterstitial(
       completedLevelIndex: controller.isDaily ? -1 : levelIndex,   // bonus box: kBonusBoxLevelIndex
       isDaily: controller.isDaily,
     );
     controller.playNext();                   // or goHouse()
   }
   ```
   It returns at once when nothing is loaded or the rules say no. Call it exactly once per completed box
   (it also counts the box). If an ad is shown, the Future ends when the ad closes; only then navigate.
   Optional `onSlow`: after 20 s without the ad opening, show a small hint ("Leave the app and come back to
   continue"); the wait itself continues (Arrowtile 1.1.4 lesson).
2. **Sounds**: listen to `ads` and mute while `ads.isShowingFullScreen` is true.
3. **Rewarded (surprise box, streak save)**: always show the "Watch ad" / "No thanks" choice. On "Watch ad":
   ```dart
   if (!ads.rewardedReady) { showToast(t.adNotReady); ads.preload(); return; }
   final ok = await ads.showRewarded('surprise_box');   // or 'streak_save'
   if (ok) { /* grant */ } // not ok: grant nothing, say nothing (they closed it)
   telemetry.logRewarded('surprise_box', ok ? 'rewarded' : 'closed');
   ```
4. **Banner**: only at the bottom of the house screen. Recommended: in `GameShell`, as the last child of the
   outer Column when `screen == AppScreen.house`, OUTSIDE the 16 px side padding so it is full width, with at
   least 8 px between it and the "Continue" button above (AdMob accidental-click policy):
   ```dart
   if (!onPlay) HouseBanner(ads: ads, label: t.adLabel, visible: progress.done.length >= 3),
   ```
   It takes no space until an ad is loaded. Never put it on the play screen, win card, daily box or settings.
5. **Settings**: a "Privacy choices" row only when `ads.privacyOptionsRequired` (rebuild with
   `AnimatedBuilder(animation: ads)`), tap -> `ads.showPrivacyOptions()`. "Restore purchases" ->
   `billing.restore()`. Vibration switch -> Progress. Daily reminder switch: on -> `reminder.requestAndEnable(...)`
   (store the returned bool), off -> `reminder.disable()`.
6. **Shop**: price text `billing.priceOf(id)` (null: show the button disabled, or without a price);
   `owns(id)` / Progress flags show "Owned"; buy -> `billing.buy(id)`. Listen to `billing.events` once
   (e.g. in the app state) and show: success -> `purchaseThanks` (+ `telemetry.logPurchase(id,
   currency: billing.currencyOf(id), value: billing.rawPriceOf(id))`), pending -> `purchasePending`,
   failed -> `purchaseFailed`, cancelled -> nothing, restored -> `purchasesRestored`.
7. **Haptics**: `haptics.tick()` when an item snaps into its slot.
8. **Review**: when the house screen opens after a win (after `maybeInterstitial` returned):
   `review.maybeAsk(alreadyAsked: progress.reviewAsked, completedLevels: progress.done.length,
   lastFullScreenAdMs: progress.lastFullScreenAdMs, markAsked: () => progress.setReviewAsked(true))`.
   The 60 s "not right after an ad" rule is inside.
9. **Reminder**: after the FIRST daily box win, if `!progress.reminderAsked`, ask (`reminderAsk`, buttons
   `reminderYes` / `noThanks`); mark asked either way; on yes `final ok = await reminder.requestAndEnable(
   title: t.notifTitle, body: t.notifBody, dailyDoneToday: true, channelName: t.reminder)` and store `ok` as
   `reminderOn`. On every app start, on resume and after each daily win:
   `reminder.reschedule(enabled: progress.reminderOn, title: t.notifTitle, body: t.notifBody,
   dailyDoneToday: progress.dailyDoneToday(DateTime.now()), channelName: t.reminder)`.
   (Texts in the current language: needs an `AppLocalizations`, so do it from a widget, not before runApp.)
10. **Telemetry**: `logLevelStart(i)` when a level opens, `logLevelComplete(i, seconds:, first:)` on win,
    `logDaily(streak:, total:)`, `logBonus(n)`, `setLanguage(lang)` when the language changes.

### Tests

In `flutter test` nothing touches a plugin: `Ads(state: MemoryAdsState())`, `Billing(...)`, `Reminder()`,
`ReviewPrompt()`, `Telemetry()` can be created in widget tests without mocks. `HouseBanner` is an empty box
there. `test/monet_ads_test.dart` shows a fake `FullScreenAdsBackend` for logic tests.

### Platform setup done in this branch

- `pubspec.yaml`: `google_mobile_ads ^9.1.0`, `in_app_purchase ^3.2.0`, `in_app_purchase_android >=0.4.0 <1.0.0`,
  `in_app_review ^2.0.10`, `flutter_local_notifications ^21.0.0` (21.x: compileSdk 36; 23.x would need compileSdk 37),
  `timezone ^0.11.0`, `firebase_core ^5.1.0`, `firebase_analytics ^13.0.1`, `firebase_crashlytics ^6.0.1`. Version 1.1.0+4.
- Android: AdMob `APPLICATION_ID` from `@string/admob_app_id` (`res/values/ads.xml`; debug always uses the test id
  from `src/debug/res/values/ads.xml`); INTERNET, ACCESS_NETWORK_STATE, AD_ID, POST_NOTIFICATIONS,
  RECEIVE_BOOT_COMPLETED (no exact-alarm permission); notification receivers; Firebase consent defaults (all denied);
  core library desugaring; R8 rules (`proguard-rules.pro`, incl. Arrowtile's WorkManager start-crash fix); release lint
  check off (it crashes inside in_app_purchase_android); Firebase Gradle plugins applied only when
  `android/app/google-services.json` exists; monochrome notification icon `drawable/ic_stat_notify` (kept from shrinking
  by `res/raw/keep.xml`); a `com.tidynook.game/consent` channel in `MainActivity.kt` (reads UMP's TCF strings for the
  Firebase consent signals).
- CI (`.github/workflows/build.yml`): writes `android/app/google-services.json` from the `GOOGLE_SERVICES_JSON` secret
  when it is set (checks it is JSON and contains `com.tidynook.game`); team-branch builds attach their logs
  (`build-aab.txt`, `apk-info.txt` with min/target SDK and native libraries, `zipalign.txt` with the 16 KB check).

---

## Part 2. Owner checklist (plain words)

Do these in order. Until steps 1-3 are done the game runs fine and shows Google's TEST ads (no money).

### 1. AdMob: create the app and 3 ad units

1. Open https://admob.google.com and sign in with the Google account of your Play developer account.
2. **Apps > Add app** > Android > "Is the app listed on a supported app store?" **Yes** > search "Tidy Nook"
   (package `com.tidynook.game`) > Add. Because the game is already on Google Play, AdMob can review it right away.
   Until AdMob approves it ("limited ad serving"), real ads rarely appear; the game simply skips them (no freeze).
3. Copy the **App ID** (looks like `ca-app-pub-1234567890123456~1234567890`). Paste it into
   `android/app/src/main/res/values/ads.xml`, replacing `ca-app-pub-3940256099942544~3347511713`.
4. In the app: **Ad units > Add ad unit**, three times:
   - **Interstitial**, name "Tidy Nook between boxes";
   - **Rewarded**, name "Tidy Nook rewarded" (reward: 1, "style" - the value is not used by the game);
   - **Banner**, name "Tidy Nook house banner".
5. Copy the three **ad unit IDs** (they contain `/`) into `lib/monet/ads_config.dart`:
   `releaseInterstitialId`, `releaseRewardedId`, `releaseBannerId`.
   Leave the `test...` lines as they are (debug builds must keep test ads; never tap your own real ads).
6. **Privacy & messaging > European regulations (GDPR)**: create a message for Tidy Nook and **publish** it
   (languages: Turkish, English, German, Arabic). Without it, players in Europe get no consent form and almost no ads.
   Optional: the "US states" message too. The game shows a "Privacy choices" row in Settings when needed.
7. (Recommended) **app-ads.txt**: AdMob shows a line like `google.com, pub-1234567890123456, DIRECT, f08c47fec0942fa0`.
   It must be reachable at the root of the website you entered in Play Console (Store settings > Website). With
   GitHub Pages: create a public repository named `<your-github-user>.github.io`, add a file `app-ads.txt` with
   that line, enable Pages, and put `https://<your-github-user>.github.io` as the website for BOTH games (Tidy Nook
   and Arrowtile). Missing app-ads.txt does not block ads but can lower earnings.

### 2. Play Console: in-app products

1. **Monetize > Monetization setup**: a payments profile must exist (needed once per developer account).
2. **Monetize > Products > In-app products > Create product**:
   - Product ID **`remove_ads`** (exactly, it can never be changed), name "Remove ads", description
     "One-time purchase. No banners and no ads between levels.", price **₺59.99** (and **$2.99** for the
     US; "update prices in other countries" is fine). **Activate**.
   - Product ID **`supporter_pack`**, name "Supporter Pack", description "No ads, a third style for every piece
     and a puppy for your home.", price **₺119.99** / **$4.99**. **Activate**.
   Translate names/descriptions to tr, de, ar in the product's language section.
3. **Settings > License testing**: add your own Gmail, so you can test purchases on the internal testing track
   without being charged.

### 3. Play Console: declarations for 1.1.0

1. **App content > Ads**: "Yes, my app contains ads".
2. **App content > Target audience and content**: age groups **13-15, 16-17 and 18+** only (not under 13).
   "Could your app unintentionally appeal to children?" answer honestly; the cosy style may make Google ask;
   ad content is limited to PG in code.
3. **App content > Content rating**: re-do the questionnaire: "digital purchases" = yes, "shares location" = no,
   "users interact" = no.
4. **App content > Data safety** (update it):
   - Does the app collect or share user data? **Yes**. Is all data encrypted in transit? **Yes**.
     Can users ask for deletion? **Yes** (by e-mail to nilkaren.tuncay.demir@gmail.com; nothing is tied to an account).
   - **Location > Approximate location**: collected and shared (AdMob uses the IP address); purpose **Advertising**;
     optional: no (ads need it).
   - **Device or other IDs**: collected and shared (advertising ID by AdMob; Firebase app instance ID);
     purposes **Advertising or marketing, Analytics, Fraud prevention/security**.
   - **App activity > App interactions**: collected (AdMob ad interactions, Firebase events such as level
     completed); purposes **Analytics, Advertising**; shared with Google for advertising (AdMob).
   - **App info and performance > Crash logs** and **Diagnostics**: collected (Crashlytics, AdMob), not shared;
     purpose **Analytics / App functionality**. (Only if Firebase is set up; declaring them anyway is safe.)
   - **Financial info > Purchase history**: collected (the purchase record from Google Play, to unlock what was
     bought), not shared; purpose **App functionality**. Payment details are handled by Google Play only.
   - Not collected: name, e-mail, contacts, photos, messages, precise location, health, files.
   - Data is processed "ephemerally"? No. Collection required? Ads data: required; analytics: optional (consent).
5. Store listing: the 1.1 texts from team member B (no "no ads / no purchases" claims any more).
6. Privacy policy URL: keep it pointing to the updated policy page (team member B wrote the text).

### 4. Firebase (optional, for crash reports and statistics)

1. https://console.firebase.google.com > **Add project** "Tidy Nook" (Google Analytics: on; account: default;
   in Analytics settings keep **Google signals off**).
2. **Add app > Android**, package name **`com.tidynook.game`** (exactly), nickname "Tidy Nook". Skip the SHA step.
3. Download **google-services.json**. Do NOT put it in the repository.
4. GitHub: repository **tidynook > Settings > Secrets and variables > Actions > New repository secret**,
   name **`GOOGLE_SERVICES_JSON`**, value: open the file in a text editor, copy EVERYTHING (from `{` to `}`)
   and paste. Save. The next build includes Firebase; the build stops with a clear message if the content is wrong.
5. In Firebase: **Crashlytics > Enable**. The first crash report appears after the first release build runs on a phone.
6. Without this secret everything still works; there are just no statistics or crash reports.

### 5. Test before release

Upload the AAB to **Internal testing**, install from Play on your phone and check: an ad appears only after
leaving the win card of the 4th level, at most every 3 boxes; "Watch ad" works or says "No ad available";
buying with your license-test account removes the banner at once; Restore works after reinstalling; the reminder
arrives at 19:00 (Android 13+ asks for permission first).

---

## Part 3. Banner placement candidates

The owner's rule: the team proposes banner spots, the manager picks only those that do not lose players.
Risk = how likely the spot makes players leave or get annoyed (also counts AdMob policy risk, which can stop all ads).

| # | Place | Impressions | Player-loss risk | Policy risk | Recommendation |
| --- | --- | --- | --- | --- | --- |
| 1 | **House screen, bottom** (adaptive anchored, below the Continue button) | Medium-high: players pass through the house between boxes and admire furniture there | **Low**: the house is a resting screen; the banner does not cover the house (it pushes it up a little) | Low, if 8+ px gap to Continue | **Yes (the plan's choice).** Extra safety: show it only after 3 levels are done (`visible: progress.done.length >= 3`), so the first session stays clean. |
| 2 | House screen, top (under the title) | Medium | Medium: pushes the title and daily card down, competes with the main visual | Low | No: same impressions as #1 with more clutter. |
| 3 | Play screen, under the rug | Very high | **High**: breaks the calm no-fail mood; drags near the bottom edge cause accidental taps | **High** (accidental clicks during play) | No. Also forbidden by the owner's rules ("never during a level"). |
| 4 | Win card (inside or under the card) | High | Medium-high: spoils the reward moment and the style choice | **High**: right next to Next / See house buttons | No. |
| 5 | Daily box screen | Medium | High: it is the retention feature (streaks) | High (gameplay) | No. |
| 6 | Settings sheet bottom | Low (short visits) | Low-medium | Medium (next to switches and links) | No: almost no money, looks cheap. |
| 7 | Shop / "Remove ads" sheet | Low | Medium: an ad inside the place where we sell "no ads" feels pushy | Low | No. |
| 8 | Privacy policy page | Very low | Low | Low | No: no value. |
| 9 | Bonus boxes list (if phase 2 adds a separate bonus menu) | Medium for engaged players | Low-medium | Low | Maybe later, after 1.1 data shows banner revenue and retention on #1. |
| 10 | Collapsible / large banners anywhere | - | High (covers content) | Medium | No. |

Summary: only **#1, house screen bottom**, ideally hidden until 3 levels are done. Everything else either breaks
the owner's "never during a level" rule, risks accidental clicks (an AdMob policy problem that can stop all ads),
or earns too little to justify it. Most of the money in 1.1 should come from the interstitial (every 3rd box),
the optional rewarded ads and the two purchases, not from banners.
