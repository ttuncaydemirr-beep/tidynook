# Tidy Nook 1.1.0: plan and team contract

Goal: turn the finished 1.0.2 game into something that earns money and keeps players coming back, without
breaking its calm, no-fail feel. Version `1.1.0+4` (versionCode 4). Package stays `com.tidynook.game`.

Read first: `docs/FLUTTER_PORT.md` (architecture, art approach, rules that still hold) and the code itself.
The evaluation reports that led to this plan are summarised in the sections below; follow this file.

## Hard rules (the owner's)

- Four languages always: Turkish, English, German, Arabic (RTL). Every new visible text goes through the ARB files.
- Ads (owner's house style, same as the Arrowtile game):
  - never during a level, never during the lid/drag/win animation;
  - interstitial at most once every 3 completed boxes, never before the 4th level is completed
    (completed level index >= 3), at least 90 s after the previous full-screen ad, never after a daily box;
  - shown only when the player leaves the win card (taps Next / See house); if no ad is loaded at that
    moment, skip silently and continue at once. **Never wait for an ad, never show a spinner for an ad.**
    (Arrowtile froze when AdMob had no fill; that must not happen here.)
  - rewarded ads are always optional, offered with a clear "Watch ad" / "No thanks" choice;
    if no rewarded ad is ready, show a short "no ad right now" message and grant nothing.
  - **no banner anywhere** (owner's Banner Decisions doc, 2026-11-11: the game's calm is the product).
  - rewarded ads use max ad content rating T (13+ audience); no ad request before the consent form is answered.
  - hints: 3 free hints per day (reset at local midnight); after that the hint button offers an optional
    rewarded ad for one more hint (owner decision 2026-11-12). Interstitials stay, capped as above (owner decision 2026-11-12).
- No timers, no fail state, no energy, no paywalled levels. Levels stay free; we sell "no ads" and cosmetics.
- Works offline. With no network every screen works; ads/IAP/analytics just do nothing.

## What 1.1 contains

1. **12 new levels (19-30)** in 4 new rooms: an attic floor (Attic Studio, Reading Nook) above the current
   top floor, and a garden strip (Patio, Garden) at ground level. New item kinds as needed (the "no two
   kinds differ by colour only" rule still holds). 9-12 items per level, a gentle step up.
2. **Mystery boxes**: a `Level.mystery` flag. In a mystery level the slot silhouettes are drawn as neutral
   grey shapes (no colours, no patterns), so you match by shape. Levels 22, 25, 28 and 30 are mystery levels.
   The level eyebrow shows the `mysteryTip` text.
3. **Bonus boxes (endless)**: unlocked when 12 levels are done. Generated from a seed like the daily box
   (`"tidynook:bonus:<n>"`), difficulty ramps with n (kinds 4 -> 7, items 8 -> 12, every 3rd box from n >= 6
   is a mystery box). Every 5 bonus boxes unlock the **3rd style** of one furniture piece the player owns.
4. **3rd furniture style** for all 30 pieces (style index 2). Earned from bonus boxes, from the rewarded
   "surprise box", or all at once with the Supporter Pack. Styles 0 and 1 stay free as now.
5. **More daily rewards**: milestones become `[3, 7, 14, 21, 30]` (cat, fishbowl, flower garden, bunny,
   songbird). The puppy (pet 5) comes with the Supporter Pack.
6. **Streak save** (rewarded): when exactly one day was missed and the streak was >= 2, the daily card offers
   "Keep your streak" for a rewarded ad. One save per missed day.
7. **Ads**: AdMob interstitial + rewarded (surprise box, streak save, extra hint), no banner, with Google UMP consent (EEA/UK) and a
   "Privacy choices" row in settings when UMP says it is required.
8. **In-app purchases** (Google Play Billing, non-consumable):
   - `remove_ads`: no interstitials and unlimited free hints (rewarded stays available as an optional choice elsewhere).
   - `supporter_pack`: everything in remove_ads + 3rd style for every piece + the puppy.
   - "Restore purchases" in settings. Prices are set by the owner in Play Console
     (suggested ₺59.99 / $2.99 and ₺119.99 / $4.99).
9. **Retention polish**: haptic tick on snap (Settings > Vibration, default on); idle hint hand on level 1
   after 5 s without a drag; Play in-app review prompt once, when the player returns to the house after
   completing level 6 (never right after an ad); optional daily reminder notification at 19:00 local time
   (asked once, after the first daily box win; Settings > Daily reminder).
10. **Analytics** (Firebase Analytics + Crashlytics), ported from Arrowtile: fully optional. The app must
    build and run with no `google-services.json`; CI writes it from the `GOOGLE_SERVICES_JSON` secret when present.
11. **Store/privacy**: privacy policy text updated for ads, purchases and analytics (in-app and web page);
    store listing no longer says "no ads / no purchases"; new ASO titles; 1.1.0 release notes; Data safety answers.

## Reference implementation: Arrowtile

The owner's other game already ships working, reviewed Flutter code for AdMob, UMP consent, Play Billing,
Firebase telemetry and haptics. Port it, do not reinvent it:
`/home/claude/Arrowtile/flutter/arrowtile` (read only; never commit or push there). Useful files:
`lib/config/ads_config.dart`, `lib/services/ads_service.dart`, `lib/core/ads_rules.dart`,
`lib/core/consent_gate.dart`, `lib/services/consent_signals.dart`, `lib/services/billing_service.dart`,
`lib/services/firebase_telemetry.dart`, `lib/core/telemetry.dart`, `lib/services/haptics_service.dart`,
`lib/ui/ad_banner.dart`, `lib/ui/rewarded_flow.dart`, `android/app/build.gradle.kts`,
`android/app/src/main/res/values/ads.xml`, `android/app/proguard-rules.pro`, its `.github/workflows/*.yml`
(google-services secret handling) and its `docs/` (decisions and lessons). Adapt names and remove what Tidy
Nook does not need (coins, hints shop, levels map...).

AdMob IDs: Tidy Nook has no AdMob app yet. Use Google's public **test** IDs everywhere, in one place
(`lib/monet/ads_config.dart` + `android/app/src/main/res/values/ads.xml`), with clearly marked
`TODO(owner)` slots for the real app ID and unit IDs. Like Arrowtile, a release build that still has test
unit IDs must not request ads from real users in a way that breaks policy: follow Arrowtile's approach.

## Team and file ownership (one owner per file)

| Owner | Files |
| --- | --- |
| A: content, logic, art (Opus) | `lib/game/**`, `test/game_*_test.dart` |
| M: monetization, platform, CI (Opus) | `lib/monet/**` (new), `lib/services/**` (new), `pubspec.yaml`, `android/**`, `.github/workflows/**`, `test/monet_*_test.dart`, `docs/MONETIZATION.md` (new) |
| B: translations and store texts (Sonnet) | `lib/l10n/*.arb`, `lib/l10n/l10n_ext.dart`, `store/**` (new: listing, release notes, privacy page text) |
| C: user interface (Opus, phase 2) | `lib/main.dart`, `lib/ui/**`, `test/widget_test.dart` |

Phase 1: A, M and B work in parallel, each in its own git worktree and branch (`v11-a`, `v11-m`, `v11-b`),
all based on `main`. Phase 2: the manager merges them into `main`; then C wires everything into the UI on `v11-c`.
Each branch must compile on its own against today's `main` UI, so keep every existing public API working
(add, do not rename or remove). `lib/ui/**` must not be edited in phase 1; if a phase-1 change would break
the current UI, keep a compatible shim and note it in your report.

## Build and check (nobody can run flutter locally)

Push your branch: GitHub Actions runs pub get, analyze, test and the Android + web builds for branches
named `v11-*`. Wait for the result with
`/tmp/claude-0/-home-claude/282dead1-5d8b-5eec-9269-1a48b3d185f4/scratchpad/waitsha.sh <your worktree>`.
On failure read the logs from the `ci-logs-<branch>` release, e.g.
`curl -sL https://github.com/ttuncaydemirr-beep/tidynook/releases/download/ci-logs-v11-a/analyze.txt`
(also `pub-get.txt`, `test.txt`, `build-aab.txt`). A green run publishes `build-<branch>` with `web.zip`.
Repeat until green. Analyzer infos/warnings do not fail the build, but keep new code free of them.
Never push to `main`, never force-push someone else's branch, never create tags.

## Contract A: `lib/game/*`

```dart
// content.dart
class Level { ...existing...; final bool mystery; }          // default false
const int decorCount = 30;                                   // levels.length == 30, decorCount == 30
const List<int> levelRoom;                                    // 30 entries; rooms 6,7 = attic, 8,9 = garden
const List<Room> rooms;                                       // 10 rooms
const List<int> milestones = [3, 7, 14, 21, 30];              // pets 0..4 from daily boxes
const int supporterPet = 5;                                   // puppy, only with the Supporter Pack
const int styleCount = 3;                                     // styles 0, 1 (free) and 2 (earned/bought)
String decorSvg(int i, int v);                                // v = 0..2
String decorPreviewSvg(int levelIndex, int variant);          // variant 0..2
String petPreviewSvg(int petIndex, {required bool locked});   // petIndex 0..5
/// House now has the attic floor and the garden strip. New named params have defaults so the
/// current UI call still compiles; the viewBox grows (expose it):
const String houseViewBox;                                    // e.g. "10 -306 340 860"
String houseSvg({required Set<int> done, required Map<int, int> styles, required int dailyTotal,
                 required List<String> roomNames, required String houseLine, bool puppy = false});
Rect decorHitRect(int levelIndex);                            // all 30
Offset roomLabelCenter(int room);                             // all 10
/// Bonus boxes.
const int bonusUnlockLevels = 12;                             // done.length needed
const int bonusStyleEvery = 5;
Level bonusLevel(int n);                                      // n = 0,1,2,... deterministic, ramped
// art.dart
String ghostSvg(String kindId, {bool mystery = false});       // mystery = neutral grey silhouette

// progress.dart (schemaVersion 3; old saves load unchanged)
int styleOf(int level);                                       // 0..2
void setStyle(int level, int variant);                        // ignored if the style is not available
bool styleAvailable(int level, int variant);                  // 0/1 always; 2 if extraStyles or supporter
Set<int> extraStyles;                                         // levels whose 3rd style is unlocked
int unlockExtraStyle(int level);                              // returns level if newly unlocked else -1
int? nextExtraStyleCandidate(int seed);                       // a done level without its 3rd style, or null
bool adsRemoved; bool supporter;                              // cached entitlements (set by billing)
void setEntitlements({required bool adsRemoved, required bool supporter});
int bonusDone;                                                // completed bonus boxes
bool get bonusUnlocked;
int completeBonus();      // bonusDone++; every bonusStyleEvery-th box unlocks a 3rd style via
                          // nextExtraStyleCandidate(bonusDone); returns that level index or -1
int streakAtRisk(DateTime now);   // streak value that a save would keep, or 0 if no save is possible
bool saveStreak(DateTime now);    // after a rewarded ad: makes the streak continue as if yesterday was played
bool vibration; bool reminderOn; bool reminderAsked; bool reviewAsked;   // simple prefs with setters
int interstitialCounter;          // boxes completed since the last interstitial (persisted)
int lastFullScreenAdMs;           // epoch ms of the last interstitial or rewarded ad (persisted)
```
Unit tests: 30 levels / 10 rooms / 30 decor; all slot kinds exist; no colour-only kind pairs (including new
kinds); mystery flags on 22, 25, 28, 30 (indexes 21, 24, 27, 29); bonusLevel deterministic, ramped, items
inside the box and not overlapping; every-5th bonus unlock; streak save rules (only exactly one missed day,
streak >= 2, once); JSON round-trip of every new field; an old v2 save loads with sensible defaults.

## Contract M: `lib/monet/*`, `lib/services/*`

No widgets except one banner widget. Everything degrades to a no-op on web, in tests and with no network.

```dart
// lib/monet/ads_config.dart     test IDs + TODO(owner) slots, like Arrowtile
// lib/monet/ad_rules.dart       pure, unit-tested pacing: shouldShowInterstitial({completedLevelIndex,
//                               isDaily, counter, lastAdMs, nowMs, adsRemoved}) -> bool, with the owner rules
// lib/monet/consent.dart        UMP flow (gather on start, privacyOptionsRequired, showPrivacyOptions())
class Ads {                      // lib/monet/ads.dart, singleton or created in main and passed down
  Future<void> init();           // after consent; preloads one interstitial and one rewarded
  bool get rewardedReady;
  /// Call when the player leaves a win card. Never waits: shows a loaded interstitial if the rules allow,
  /// updates Progress counters, preloads the next. Returns true if an ad was shown.
  Future<bool> maybeInterstitial({required int completedLevelIndex, required bool isDaily});
  /// Shows a rewarded ad; completes true only if the reward was earned. false at once if none is ready.
  Future<bool> showRewarded(String placement);   // 'surprise_box' | 'streak_save'
  bool get privacyOptionsRequired; Future<void> showPrivacyOptions();
}
class HouseBanner extends StatelessWidget/StatefulWidget { }   // lib/monet/house_banner.dart; SizedBox.shrink
                                                                // when ads removed / not loaded / web
class Billing {                  // lib/monet/billing.dart
  static const removeAdsId = 'remove_ads', supporterId = 'supporter_pack';
  Future<void> init();           // listens to purchase stream, restores, writes Progress.setEntitlements
  String? priceOf(String id);    // localized price from Play, null if unknown
  Future<void> buy(String id); Future<void> restore();
  Stream<PurchaseEvent> get events;   // success / pending / failed / restored, for UI messages
}
// lib/services/haptics.dart     tick() honouring Progress.vibration (Flutter HapticFeedback; no permission)
// lib/services/review.dart      maybeAskReview(progress)  (in_app_review, once, guarded)
// lib/services/reminder.dart    requestAndEnable(progress) / disable() / reschedule(progress, now):
//                               19:00 local, next 7 days, skip today when the daily box is done;
//                               inexact alarms only (no exact-alarm permission); Android 13+ permission
// lib/services/telemetry.dart   Telemetry.init() no-op without Firebase config; logLevelStart/Complete,
//                               logDaily, logBonus, logPurchase; Crashlytics only when configured
```
Also: `pubspec.yaml` deps (google_mobile_ads, in_app_purchase(+_android), in_app_review,
flutter_local_notifications (+ timezone helpers as needed), firebase_core/analytics/crashlytics) with
versions that resolve on Flutter 3.47.9 (copy Arrowtile's where possible); Android manifest
(AdMob APPLICATION_ID from ads.xml, notification permission/receivers, AD_ID is added by the SDK),
desugaring if the notifications plugin needs it, proguard rules, conditional google-services plugin;
workflow step writing `GOOGLE_SERVICES_JSON`. `docs/MONETIZATION.md`: what the owner must create in AdMob,
Play Console (products, Data safety, Ads declaration) and Firebase, step by step, plus the list of
**banner placement candidates** you considered with your risk assessment (the owner's standing rule:
the team proposes banner spots, the manager picks only ones that do not lose players).
Version: set `version: 1.1.0+4` in pubspec.

## Contract B: texts

New ARB keys (all four languages; ICU plurals where a number is shown; Arabic plural forms done properly).
English source (change the wording only if it reads badly; keep it short, warm, simple):

| key | English |
| --- | --- |
| `bonusTitle` | Bonus boxes |
| `bonusLocked` | Finish 12 levels to unlock bonus boxes |
| `bonusBoxN(n)` | Bonus box {n} |
| `bonusProgress(a, b)` | {a}/{b} to a new style |
| `bonusPlay` | Play |
| `newStyleFor(item)` | New style for the {item}! |
| `mysteryTip` | Mystery box: only the shapes are shown |
| `surpriseTitle` | Surprise box |
| `surpriseText` | Watch a short ad to unlock a third style for this piece. |
| `surpriseGot` | Third style unlocked! |
| `watchAd` | Watch ad |
| `noThanks` | No thanks |
| `adNotReady` | No ad available right now. Please try again later. |
| `streakSaveTitle` | Keep your streak |
| `streakSaveText(n)` | You missed a day. Watch a short ad to keep your {n}-day streak. |
| `streakSaved` | Streak saved! |
| `shop` | Shop |
| `removeAds` | Remove ads |
| `removeAdsText` | One-time purchase. No banners and no ads between levels. |
| `supporterPack` | Supporter Pack |
| `supporterText` | No ads, a third style for every piece and a puppy for your home. |
| `restorePurchases` | Restore purchases |
| `purchaseThanks` | Thank you for your support! |
| `purchasePending` | Your purchase is pending. |
| `purchaseFailed` | The purchase did not go through. |
| `purchasesRestored` | Purchases restored. |
| `owned` | Owned |
| `buyFor(price)` | Buy for {price} |
| `privacyChoices` | Privacy choices |
| `vibration` | Vibration |
| `reminder` | Daily reminder |
| `reminderText` | Remind me about the daily box at 7 pm |
| `reminderAsk` | Want a reminder when a new daily box is ready? |
| `reminderYes` | Remind me |
| `notifTitle` | Your daily box is ready |
| `notifBody` | A new box is waiting to be tidied. |
| `adLabel` | Advertisement |

Plus the numbered arrays: `levelName18..29`, `decorName18..29`, `roomName6..9`, `petName3..5`:

| # | level name | furniture it adds | room |
| --- | --- | --- | --- |
| 18 | Sewing Box | Sewing table | 6 Attic Studio |
| 19 | Yarn Basket | Rocking chair | 6 |
| 20 | Button Tin | Easel | 6 |
| 21 | Record Crate | Record player | 7 Reading Nook |
| 22 | Tea Caddy | Beanbag | 7 |
| 23 | Desk Organizer | Bookcase | 7 |
| 24 | Picnic Basket | Garden table | 8 Patio |
| 25 | Grill Tray | String lights | 8 |
| 26 | Beach Bag | Hammock | 8 |
| 27 | Seed Box | Raised flower bed | 9 Garden |
| 28 | Potting Bench | Birdhouse | 9 |
| 29 | Fruit Crate | Apple tree | 9 |

Pets: 3 Bunny, 4 Songbird, 5 Puppy. `l10n_ext.dart`: the helpers must cover the new index ranges
(`roomNames` returns 10). Update `ver` to 1.1.0. Rewrite `privacyText` for ads (AdMob: advertising ID,
approximate location from IP, consent via Google UMP), purchases (handled by Google Play, we never see
payment details), optional analytics/crash reports (Firebase), notifications (local only), the developer
line and the support e-mail nilkaren.tuncay.demir@gmail.com; plain words, all four languages.

`store/` (new folder, JSON or Markdown): 1.1.0 store listing in 4 languages (title <= 30 chars, short
description <= 80, long description <= 4000; remove every "no ads / no in-app purchases" claim; mention
"ads never interrupt a level" and offline play; ASO titles from the market review: EN "Tidy Nook: Organize &
Decorate", DE "Tidy Nook: Aufräumspiel & Deko", TR "Tidy Nook: Ev Düzenleme Oyunu", AR "Tidy Nook: لعبة ترتيب وديكور"
-- count characters), release notes 1.1.0 (each language < 500 chars, Play tag format `<tr-TR>...</tr-TR>`),
and the privacy policy web page text (same content as `privacyText`, longer form, 4 languages).

## Contract C (phase 2): user interface

Written after phase 1 is merged; C gets its own brief then.

## Owner-approved team decisions applied in 1.1 (2026-11-12)

- Banner Decisions doc: Tidy Nook has no banner. Revenue = rewarded ads + purchases (+ capped interstitials, owner OK).
- Visual Identity Decisions doc: direction A "Butter & Sage" (light theme: cream #FFF6E5 page, terracotta #B5452B
  primary/accent, sage #2A8363 secondary); font stays Baloo Bhaijaan 2, shipped with its OFL license file (no
  runtime font download, no Google Fonts link in the web build); fix the 5 room floor colours whose labels/furniture
  do not read; never uppercase Turkish text with toUpperCase(); colour never carries meaning alone.
  Dark theme: derive matching values and measure every text/background pair (WCAG AA 4.5:1 for text, 3:1 for large text/icons).
- Developer/studio name everywhere (privacy texts, store listing): "Demir Games Studio".
