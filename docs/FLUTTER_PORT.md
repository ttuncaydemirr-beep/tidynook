# Tidy Nook: Flutter port plan and team contract

Source of truth for behaviour, art, numbers and texts: `web-preview/index.html` (the shipped HTML game).
The Flutter app must look and play the same. When this file and the HTML disagree on a detail, the HTML wins,
unless this file says otherwise on purpose.

- Package / applicationId: `com.tidynook.game` (already on Google Play; must not change)
- Dart package name: `tidy_nook`
- Version: `1.0.1+2` (versionCode 2)
- Languages (all mandatory): Turkish `tr` (default), English `en`, German `de`, Arabic `ar` (right-to-left)
- Platforms: Android (release target) and web (used only for quick visual checks in CI)
- Dependencies (fixed; ask in your report if you need another): `flutter_localizations`, `intl`,
  `flutter_svg`, `shared_preferences`, `audioplayers`
- No network, no ads, no analytics, no permissions.

CI uses Flutter 3.47.9 stable (Dart 3.x). Nobody can run `flutter` in the editing environment. Code is compiled, analysed and tested only in GitHub
Actions. So write plain, conservative, null-safe Dart 3 that compiles on current Flutter stable, avoid
experimental APIs, and double-check every import, constructor and named parameter.

## Rendering approach

All art is produced as **SVG strings** (a direct port of the JS functions that build SVG markup) and drawn
with `SvgPicture.string` from `flutter_svg`. This keeps the look identical to the web game.

- Board space: the web board uses `viewBox="0 40 360 594"`. Flutter uses the same logical coordinates.
  The play area is a widget that scales this 360 x 594 box to fit (preserve aspect ratio, centred).
- Items are positioned in board space by their centre (x, y) with rotation (degrees) and scale.
- House space: `viewBox="10 -146 340 574"`.

## File ownership (one owner per file; do not edit files you do not own)

| Owner | Files |
| --- | --- |
| A: data and logic | `lib/game/art.dart`, `lib/game/content.dart`, `lib/game/daily.dart`, `lib/game/progress.dart`, `lib/game/board_logic.dart`, `test/game_*_test.dart` |
| B: translations | `l10n.yaml`, `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/l10n_ext.dart` |
| C: user interface | `lib/main.dart`, `lib/ui/**`, `test/widget_test.dart` |
| D: Android, web shell, sounds, CI | `android/**`, `web/**`, `assets/sounds/**`, `tool/**`, `.github/workflows/**`, `pubspec.yaml`, `analysis_options.yaml` |

## Contract A: `lib/game/*` (pure Dart + `dart:ui` geometry types only; no widgets)

```dart
// lib/game/art.dart
class Prim { /* rect | circle | ellipse | polygon, with a fill colour string like "#F6E7D3" or "rgba(...)" */ }
class ItemKind { final String id; final String main; final List<Prim> prims; }
final Map<String, ItemKind> kinds;                 // every kind id exactly as in the HTML (egg, pencil-sun, ...)

/// Sticker-style item art: dark outline (#2E2638, width 7), white rim (width 3), then the fills,
/// exactly like art() in the HTML. Returns a complete <svg> document whose viewBox is
/// itemBox(kindId) so that the item centre (0,0) maps to the box's own coordinates.
String itemSvg(String kindId);
/// Ghost (empty slot) art, like ghost() in the HTML, with the same viewBox as itemSvg.
String ghostSvg(String kindId);
/// Item-local bounding box (origin = item centre) INCLUDING the 3.5 px outline. Use for layout and hit testing.
Rect itemBox(String kindId);

// lib/game/content.dart
class Slot { final String kind; final double x; final double y; }
class Level { final String outer; final String inner; final List<Prim> dividers; final List<Slot> slots; final int theme; }
final List<Level> levels;                          // 18 levels, same order and numbers as LEVELS in the HTML
const List<int> levelRoom;                         // LROOM: room index for each level
class Room { final double x; final double y; final String wall; final String floor; }
final List<Room> rooms;                            // 6 rooms, as ROOMS in the HTML
const List<int> milestones = [3, 7, 14];           // daily boxes needed for cat, fishbowl, flower garden

/// Full board background as an <svg> with viewBox "0 40 360 594": box shadow, frame (outer), inside (inner),
/// dividers, then the rug (mat) and its stitched border. matColor/stitchColor come from the UI theme.
String boardSvg(Level level, {required String matColor, required String stitchColor});
/// The closed lid as an <svg> with viewBox "0 40 360 594" (transparent outside the box). tapText is
/// drawn as in drawLid() of the HTML; pass null to leave the text out (used when the lid closes on a win).
String lidSvg(Level level, {String? tapText});
/// The whole two-storey house as an <svg> with viewBox "10 -146 340 574", like renderHouse() in the HTML:
/// rooms, furniture for done levels in the chosen style, moving boxes for levels not done, room labels
/// "<room name> · n/m", the room-complete check marks, pets/garden from daily milestones.
/// houseLine is the outline colour from the theme. Room names come in already translated.
String houseSvg({required Set<int> done, required Map<int, int> styles, required int dailyTotal,
                 required List<String> roomNames, required String houseLine});
/// Tap areas for furniture in house space, one per level index, for toggling styles.
Rect decorHitRect(int levelIndex);
/// Furniture preview for the win card (variant 0 or 1), zoomed onto the piece like zoomPreviews() does.
String decorPreviewSvg(int levelIndex, int variant);
/// Pet/garden preview for the daily win card; locked = greyed out at 35% opacity.
String petPreviewSvg(int petIndex, {required bool locked});

// lib/game/daily.dart
String dayString(DateTime d);                      // local date "YYYY-MM-DD"
/// Same algorithm and seed ("tidynook:" + day) as dailyLevel() in the HTML, so a given date gives the
/// same puzzle on web and Android. Port seeded() with exact 32-bit integer maths.
Level dailyLevel(String day);

// lib/game/progress.dart  (ChangeNotifier from package:flutter/foundation.dart is allowed)
class DailyState { String last; int streak; int total; List<String> days; }
class Progress extends ChangeNotifier {
  String? lang;            // null = follow the device (tr if the device language is not one of the four)
  bool sound;
  int level;               // last opened level
  Set<int> done;
  Map<int, int> styles;    // level index -> 0/1
  DailyState daily;
  static Future<Progress> load();   // shared_preferences, key "tidynook-v1", same JSON shape as the HTML
  Future<void> save();
  int get unlocked;                 // as unlocked() in the HTML
  int get nextOpen;                 // first level not done, -1 if all done
  int styleOf(int level);
  void setStyle(int level, int variant);
  bool roomComplete(int room);
  int completeLevel(int level);           // marks done; returns the level index if newly earned, else -1
  int completeDaily(DateTime now);        // as dailyWin(); returns pet index newly earned, else -1
  bool dailyDoneToday(DateTime now);
  int liveStreak(DateTime now);
  void reset();                           // as the settings reset in the HTML
}

// lib/game/board_logic.dart
class ItemState { final int id; final String kind; double x, y, rotation, scale; bool placed; Offset home; }
class SlotState { final int id; final Slot slot; bool filled; }
/// Initial scatter of a level's items on the rug: same grid/jitter/rotation rules as build() in the HTML.
List<ItemState> scatter(Level level, math.Random random);
/// Nearest free slot of the same kind within 54 board units of (x, y), or null. As drop() in the HTML.
SlotState? findSnap(List<SlotState> slots, String kind, double x, double y);
/// True when (x, y) is above the rug (the y < 352 rule): a wrong drop there springs back home.
bool isAboveRug(double y);
/// Keep a dropped item on the rug (the clamp in drop()).
Offset clampToRug(double x, double y);
/// Free item + its nearest matching free slot for the hint button, or null.
({ItemState item, SlotState slot})? pickHint(List<ItemState> items, List<SlotState> slots, math.Random r);
```

Tests (A): data counts (18 levels, 6 rooms, 18 decor), every slot kind exists in `kinds`, no two kinds differ
by colour only, `dailyLevel` is deterministic and has 10 slots with no overlapping boxes inside the box,
streak rules (consecutive day +1, gap resets to 1, same day no change), milestone pets at 3/7/14, JSON
round-trip with the web shape.

## Contract B: translations

- `l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-localization-file:
  app_localizations.dart`, class `AppLocalizations`, `nullable-getter: false`, generated code under
  `lib/l10n/gen` (check the current Flutter docs for the right keys; imports elsewhere will be
  `package:tidy_nook/l10n/gen/app_localizations.dart`).
- One key per text in the HTML `T` object, all four languages, same wording as the HTML. Function texts
  become ICU placeholders (e.g. `hTitle(d, n)`, `cont(n)`, `streak(n)` with the Arabic singular/dual rules
  the HTML uses, `roomDone(room)`, `nextReward(item, a, b)`, `newFriend(item)`, `dailyTotal(n)`, `styleN(n)`).
- Arrays become numbered keys (`levelName0`..`levelName17`, `decorName0`.., `roomName0`..`roomName5`,
  `winTitle0`..`winTitle2`, `petName0`..`petName2`, `dailyTheme0`..`dailyTheme4`).
- `lib/l10n/l10n_ext.dart`: `extension TidyL10n on AppLocalizations` with `levelName(int)`,
  `decorName(int)`, `roomName(int)`, `winTitle(int)`, `petName(int)`, `dailyTheme(int)`, and
  `List<String> get roomNames`.
- Also add `appTitle` = "Tidy Nook" and `webViewMissing` is not needed in Flutter.

## Contract C: user interface (`lib/main.dart`, `lib/ui/**`)

Rebuild every screen and interaction of the HTML game with the A and B APIs: top bar (brand, sound,
settings), house screen (daily box card, tappable furniture with pop animation, room-complete toast,
continue button, tip line), play screen (home, level eyebrow + title, hint, board with lid tap-to-open,
drag with lift, snap, spring-back, sparkles, lid closes on win, win card with style picker or daily reward
and the 7-day week row, level dots, footer note), settings bottom sheet (language, sound switch, support
e-mail nilkaren.tuncay.demir@gmail.com with copy button, reset with in-sheet confirm, version
"1.0.1"), light/dark theme with the HTML colour tokens, RTL for Arabic via the locale,
`PopScope` back handling (sheet closes itself, play -> house, house -> leave app), font family `Baloo`
(a variable font: set weight with `fontVariations: [FontVariation('wght', 800)]` as well as `fontWeight`),
sounds via `audioplayers` from `assets/sounds/<name>.wav` with names: `pick`, `place`, `miss`, `win`,
`deco`, `lid_open`, `lid_close`, `room`, `hint`, `toggle`. Respect reduced motion
(`MediaQuery.disableAnimations`). Start screen: first level if nothing is done, else the house.

## Contract D: Android, web shell, sounds, CI

- `android/app/build.gradle(.kts)`: applicationId `com.tidynook.game`, minSdk 26, targetSdk 36,
  compileSdk 36, version from pubspec; release signing from env vars `TIDY_KEYSTORE_FILE`,
  `TIDY_KEYSTORE_PASSWORD`, `TIDY_KEY_ALIAS`, `TIDY_KEY_PASSWORD`; with no key the release build must be
  UNSIGNED (never debug-signed).
- Manifest: label "Tidy Nook", `android:appCategory="game"`, portrait, no permissions in release, the
  adaptive icon from the 1.0.0 build (branch `release-1.0.0-webview`, `app/src/main/res/`), launch
  background in the page colours (#F4EFF7 light, #1F1A26 dark).
- `tool/make_sounds.py` generates the ten WAV files (short synthesized tones matching the `sfx` table and
  `tone()` in the HTML) into `assets/sounds/`; commit the WAVs.
- `.github/workflows/build.yml`: on push to main and manual run; Flutter stable with cache;
  `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build appbundle --release`,
  `flutter build apk --release`, `flutter build web --release`; check 16 KB page alignment of the APK's
  native libraries; publish `app-release.aab`, `app-release.apk` and `web.zip` on the `latest-build`
  release (replace the old one), with the Flutter version and whether it was signed in the notes.
