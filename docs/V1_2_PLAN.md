# Tidy Nook 1.2.0: plan and team contract

Goal: give the players in the closed test (and later everyone) reasons to come back every day, and more to
play, without breaking the calm, no-fail feel. Version `1.2.0+5` (versionCode 5). Package stays `com.tidynook.game`.
Ship target: about 7 days, uploaded to the running closed test as an update.

Read first: `docs/V1_1_PLAN.md` (hard rules, team set-up, build and check, ad rules: all still hold),
`docs/FLUTTER_PORT.md`, `docs/MONETIZATION.md`, then the code.

## Hard rules (unchanged from 1.1, repeated because they matter)

- Four languages always: tr, en, de, ar (RTL). Every visible text through the ARB files.
- No banner anywhere. Interstitial and rewarded rules exactly as in `docs/V1_1_PLAN.md`. Never wait for an ad.
- No timers, no fail state, no energy, no paywalled levels, no new currency to buy. Offline works.
- Progress from 1.1 (schema 3) must load without loss; bump the schema to 4 with a migration.
- No default colours or fonts: reuse the Butter & Sage theme and the existing fonts; new art follows the
  existing painted style in `lib/game/art.dart`.

## What 1.2 contains

1. **Chapter 3: 15 new levels (31-45)** and **3 new rooms** for the house, for example a greenhouse, a laundry
   room and a balcony (A decides names, where they sit in the house and what each level brings home).
   Difficulty keeps rising gently. New box themes, no reused level layouts.
2. **One new gentle mechanic**, introduced at level 31 with a one-line hint, used in about a third of the new
   levels. It must stay no-fail and timer-free (ideas: a nested inner box/drawer that opens after its first
   items are placed; items that come in matching pairs; a fragile item that must go on a padded slot).
   A picks one and documents it.
3. **Daily tasks**: 3 small tasks per day, generated from the date (same for everyone offline), for example
   "finish 2 boxes", "change a style in your house", "open the daily box", "use a hint", "finish a mystery box".
   Each finished task gives 1 hint. Finishing all 3 fills one step of a 7-step "task chest"; a full chest unlocks
   a third style the player does not own yet (or a small decor if all are owned). After finishing a task the
   player may watch an optional rewarded ad to double that task's hint (placement id `task_double`).
4. **Winter event** (local date 1 December to 15 January, every year): 7 winter boxes reachable from a card on
   the house screen, light snow on the house roof and garden while the event runs, and a snowman for the garden
   when all 7 are done (kept forever). Event boxes count for tasks and for the interstitial counter like normal boxes.
5. **Analytics events** for the new features (task_complete, task_chest_open, event_box_complete, mechanic_tutorial_seen,
   rewarded placement `task_double`), through the existing telemetry service.

Monetisation note: no new products. The new rewarded placement and more daily sessions are the revenue lever.
The Supporter Pack keeps giving unlimited hints (task hint rewards then do nothing visible except the chest step).

## Team and file ownership (one owner per file)

| Owner | Files |
| --- | --- |
| A: content, mechanic, tasks and event logic, art (Opus) | `lib/game/**`, `test/game_*_test.dart` |
| B: translations and store texts (Sonnet) | `lib/l10n/*.arb`, `lib/l10n/l10n_ext.dart`, `store/**` |
| C: user interface and wiring (Opus, phase 2) | `lib/main.dart`, `lib/ui/**`, `lib/monet/**`, `lib/services/**`, `test/widget_test.dart`, `pubspec.yaml` (version only) |
| QA (Sonnet, phase 3) | report only, no code |

Phase 1: A and B in parallel, own git worktrees and branches `v12-a`, `v12-b`, both from `main`.
Phase 2: the manager merges them; C builds the UI on `v12-c`. Phase 3: QA plays the web build and reports;
fixes go back to the owner. Each phase-1 branch must compile on its own against today's UI: add, never rename or
remove public APIs; `lib/ui/**` is not edited in phase 1.

Build and check: exactly as in `docs/V1_1_PLAN.md` ("Build and check"), with branch names `v12-*`
(CI already builds them). Never push to `main`, never force-push someone else's branch, never create tags.

## Contract A 1.2 (A fills this section in before finishing)

A writes here the public API C will use: level list and room additions, the mechanic's data and board rules,
`Progress` additions (schema 4 fields, migration), task generation and completion calls, chest state, event
window check, event levels, snowman decor, and every text key A needs (name + English text) so B and C agree.

Status: implemented on branch `v12-a` (compiles and passes tests with the 1.1 UI; nothing was renamed or removed).
Everything below is exported by `package:tidy_nook/game/content.dart` (it now also exports `tasks.dart` and
`winter.dart`); board rules are in `board_logic.dart`, state in `progress.dart`.

### 1. Levels, rooms, furniture

```dart
final List<Level> levels;              // 45 (0..29 as before, 30..44 = chapter 3)
const List<int> levelRoom;             // 45 entries; 30..34 -> room 10, 35..39 -> 11, 40..44 -> 12
const List<Room> rooms;                // 13 rooms
const List<int> topFloorRooms = [10, 11];   // 10 Laundry Room, 11 Balcony (new top floor, under the roof)
const int greenhouseRoom = 12;              // Greenhouse, below the garden strip
const List<int> openAirRooms = [8, 9, 11];  // no warm glow when complete
const int chapter3Start = 30;
const int mechanicIntroLevel = 30;     // level 31 introduces the drawer
const int decorCount = 45;             // furniture 30..44, 3 styles each (decorSvg(i, 0..2))
const int styleCount = 3;              // unchanged
```

Levels (index: name / furniture it brings home / room). Items per box: 10, 11, 12, 12, 12, 12, 12, 13, 12, 13, 13, 13,
13, 14, 14. Drawer levels: 30 (intro), 33, 37, 40, 43. Mystery levels: 35, 41 (no box has both).

| # | level (`levelNameN`) | furniture (`decorNameN`) | room |
| --- | --- | --- | --- |
| 30 | Laundry Basket | Washing machine | 10 Laundry Room |
| 31 | Ironing Kit | Ironing board | 10 |
| 32 | Peg Bag | Drying rack | 10 |
| 33 | Cleaning Caddy | Cleaning shelf | 10 |
| 34 | Linen Cupboard | Clothesline | 10 |
| 35 | Candle Box | Hanging lantern | 11 Balcony |
| 36 | Game Night | Bistro set | 11 |
| 37 | Lantern Shelf | Potted palm | 11 |
| 38 | Bird Feeder Kit | Bird feeder | 11 |
| 39 | Stargazing Box | Telescope | 11 |
| 40 | Seedling Tray | Seedling shelf | 12 Greenhouse |
| 41 | Herb Box | Herb planter | 12 |
| 42 | Mushroom Basket | Wheelbarrow | 12 |
| 43 | Flower Crate | Flower buckets | 12 |
| 44 | Harvest Basket | Hanging fern | 12 |

**House layout and what C must change.** `houseSvg(extended: true)` now draws the 1.2 house: a new top floor
(rooms 10, 11 at y = -380) under the raised roof, the attic, the three 1.0 storeys, the garden strip and the
greenhouse (room 12 at x = 105, y = 640) with its own glass roof and lawn. The constants the house screen already
uses were updated in place, so **the current house screen shows the new rooms with no UI change**:
`houseViewBox = '10 -466 340 1276'`, `houseOrigin = Offset(10, -466)`, `houseSize = Size(340, 1276)`
(the old value is kept as `houseViewBoxV11`). `decorHitRect(i)` and `roomLabelCenter(room)` cover all 45 / 13.
Until B adds the keys, the labels of rooms 10-12 and the names of levels/furniture 30-44 fall back to the last
entry of the `l10n_ext` lists (that is how the clamped helpers behave), so B must extend
`levelNames`/`decorNames` to 45 and `roomNames` to 13. C only needs to pass the new optional house parameters:

```dart
String houseSvg({..., bool extended = false,
    bool snow = false,                      // pass snowOnHouse(DateTime.now())
    bool snowman = false,                   // pass progress.snowman
    Set<int> chestDecors = const <int>{}}); // pass progress.chestDecors
const Offset snowmanSpot;                   // house space, for sparkles / scrolling after the 7th winter box
Offset chestDecorSpot(int i);               // house space, after a chest gave decor i
const int chestDecorCount = 4;              // 0 garden gnome, 1 birdbath, 2 window flower box, 3 lantern post
String chestDecorPreviewSvg(int i);         // for the chest reward card
String snowmanPreviewSvg({bool locked = false}); // for the winter card / win card
```

### 2. The mechanic: little inner drawers

Rules (no fail, no timer): some boxes have a small drawer inside. Its slots stay closed until every slot outside
the drawer is filled; then it opens by itself and its slots take items like any other. An item whose only free
slots are in a closed drawer simply cannot snap yet (a drop above the rug springs back home as usual, a drop on
the rug stays there). Hints never point into a closed drawer. Every box can always be finished (tested).

```dart
class InnerDrawer { final Rect area; final List<int> slots; final List<int>? opensAfter; final String front; }
Level.drawers (List<InnerDrawer>, default empty); bool get Level.hasDrawers;
List<int> drawerKeys(Level level, int d);       // slots that must be filled first (default: all outside slots)
// board_logic.dart
SlotState.waitFor (List<int>, set by makeSlots)  // findSnap and pickHint skip slots whose waitFor is not all filled,
bool slotOpen(List<SlotState> slots, SlotState s);  //   so today's board already enforces the rule
bool drawerOpen(Level level, int d, List<SlotState> slots);
int drawerRemaining(Level level, int d, List<SlotState> slots);   // empty key slots, 0 = open
List<int> drawersOpenedBy(Level level, List<SlotState> slots, int slotId); // call right after slot.filled = true
// art (content.dart)
String drawerFrontSvg(Level level, int d);      // full <svg> viewBox "0 40 360 594", like lidSvg
Offset drawerKnobCenter(Level level, int d);    // board space
```

How the board should show it (C): `boardSvg` already draws the open tray (dark rim) under the ghosts. Draw
`drawerFrontSvg(level, d)` as a full-board layer above the ghosts and placed items and below the free items while
`!drawerOpen(...)`. After each snap call `drawersOpenedBy(level, slots, slot.id)`; for each returned drawer slide
the front down about 20 units and fade it out (~300 ms; instantly with reduced motion) and play `lid_open`.
Optionally draw `drawerLeft(n)` (n = `drawerRemaining`) under the knob. Eyebrow for a level with
`hasDrawers`: `drawerTip`; the first time (`progress.markMechanicTipSeen()` returns true) log
`mechanic_tutorial_seen`. Drawers are never used in daily, bonus or winter boxes.

### 3. Daily tasks and the task chest

Three tasks per local day, made on first use from the date (`seeded("tidynook:tasks:<day>")`, same order for
everyone) skipping types the player cannot do yet, then fixed for the day. Types (stable `TaskType` order):
`boxes` (finish 2-3 boxes of any kind, including replays, daily, bonus and winter boxes), `newLevel`, `daily`,
`bonus`, `style` (change a furniture style), `hint` (use a hint), `mystery`, `replay`, `drawer`, `winter`.
**Detection is automatic** inside the existing `Progress` calls the UI already makes (`completeLevel`,
`completeDaily`, `completeBonus`, `completeWinter`, `setStyle` with a different style, `useFreeHint` returning
true), so C adds no counting code. A finished task's hint (`taskHintReward` = 1) is given when the player claims
it (`claimTask`), or twice when they watch the optional `task_double` ad (`doubleTask`, before or after claiming);
hints left unclaimed are added automatically when the next day's tasks are made, so nothing is lost. (Claiming is
explicit so a "use a hint" task never changes the hint count in the middle of using a hint.) When all three are
done, one chest step fills (once per day, max 7). With Remove ads / Supporter Pack the hints are invisible
(unlimited anyway), the chest still fills.

```dart
const int tasksPerDay = 3, taskHintReward = 1, taskChestSteps = 7, chestBonusHints = 3;
enum TaskType { boxes, newLevel, daily, bonus, style, hint, mystery, replay, drawer, winter }
class DailyTask { TaskType type; int target; int progress; bool claimed; bool doubled; bool get done; }
List<DailyTask> Progress.tasksFor(DateTime now);   // read-only, safe in build()
bool Progress.tasksAllDone(DateTime now);
List<int> Progress.takeCompletedTasks();  // indexes finished since last call: toast taskDone, log task_complete
bool Progress.takeChestStepEarned();      // true once after a chest step filled
bool Progress.canClaimTask(int i, DateTime now);
bool Progress.claimTask(int i, DateTime now);    // +1 hint, once
bool Progress.canDoubleTask(int i, DateTime now);
bool Progress.doubleTask(int i, DateTime now);   // after the rewarded ad (placement 'task_double'): the task gives
                                                 //   2 hints in total (2 now if unclaimed, else 1 more), once
int Progress.chestSteps; bool get Progress.taskChestReady;
ChestReward? Progress.openTaskChest();    // log task_chest_open; null when not full
class ChestReward { ChestRewardKind kind; int value; } // style -> level index (show newStyleFor(decorName(value))),
                                          // decor -> chestDecorName(value), hints -> value hints
```

### 4. Winter event

```dart
bool winterActive(DateTime now);       // local date 1 Dec .. 15 Jan inclusive, every year (year wrap handled)
bool snowOnHouse(DateTime now);        // = winterActive; pass to houseSvg(snow: ...)
int winterSeasonOf(DateTime now);      // 2026 for 2026-12-xx and 2027-01-xx
int winterDaysLeft(DateTime now);      // 46 on 1 Dec, 1 on 15 Jan, 0 outside
const int winterLevelCount = 7;
final List<Level> winterLevels; Level winterLevel(int i);   // 9-12 items, no drawers, no mystery
bool Progress.winterAvailable(DateTime now);   // event runs and at least one level is done: show the card
int Progress.winterDoneCount(DateTime now); bool Progress.winterBoxDone(int i, DateTime now);
int Progress.winterNext(DateTime now);          // first box not done this season, -1 = all done
({bool fresh, bool snowman}) Progress.completeWinter(int i, DateTime now);  // log event_box_complete;
                                                // snowman = earned by this box -> celebrate at snowmanSpot
bool Progress.snowman;                          // kept forever (also after a reset)
```

Winter boxes are per season: next December they can be played again (the snowman stays). C: capture the box
index when it is opened and call `completeWinter` on win; count it for the interstitial like a bonus box (use the
same "not a numbered level" index as bonus boxes) and never after the daily box. No level dots for winter boxes.

### 5. Progress schema 4

`Progress.schemaVersion = 4`. New keys: `tasks` (`{"day","list":[{"t","n","p","x"}]}`), `chestSteps`,
`chestDay`, `chestsOpened`, `chestDecors`, `winter` (`{"season","done"}`), `snowman`, `mechanicTipSeen`. A schema 3
save loads with every value unchanged and the new keys at defaults (tested with a 1.1 fixture). `reset()` also
clears tasks, chest and this season's winter boxes; it keeps the snowman and `mechanicTipSeen`. New
`Progress.clock` (default `DateTime.now`) is for tests only.

### 6. Text keys (English source; B translates, C uses)

Numbered keys (extend the `l10n_ext` lists): `levelName30..44` and `decorName30..44` as in the table above;
`roomName10` Laundry Room, `roomName11` Balcony, `roomName12` Greenhouse; `winterLevelName0..6` Mitten Basket,
Ornament Box, Cookie Tin, Cocoa Tray, Gift Wrap Box, Pinecone Basket, Snow Globe Shelf; `chestDecorName0..3`
Garden gnome, Birdbath, Window flower box, Lantern post. Suggested helpers in `l10n_ext`:
`winterLevelName(int)`, `chestDecorName(int)`, `taskText(int typeIndex, int target)` (index = `TaskType.index`).

| key | English |
| --- | --- |
| `drawerTip` | Little drawer: fill the other spots first and it opens |
| `drawerLeft(n)` | {n} more to open |
| `tasksTitle` | Daily tasks |
| `taskTextBoxes(n)` | Finish {n} boxes |
| `taskTextNewLevel` | Finish a new level |
| `taskTextDaily` | Finish the daily box |
| `taskTextBonus` | Finish a bonus box |
| `taskTextStyle` | Change a style in your house |
| `taskTextHint` | Use a hint |
| `taskTextMystery` | Finish a mystery box |
| `taskTextReplay` | Play a finished level again |
| `taskTextDrawer` | Finish a box with a drawer |
| `taskTextWinter` | Finish a winter box |
| `taskProgress(a, b)` | {a}/{b} |
| `taskReward` | +1 hint |
| `taskClaim` | Claim |
| `taskDoubleOffer` | Watch ad: 2 hints |
| `taskDone` | Task done! |
| `tasksAllDone` | All tasks done. See you tomorrow! |
| `taskDoubleTitle` | Double your hint |
| `taskDoubleText` | Watch a short ad to get one more hint for this task. |
| `taskDoubled` | Hint doubled! |
| `chestTitle` | Task chest |
| `chestProgress(a, b)` | {a}/{b} days |
| `chestHint` | Finish all three tasks on a day to fill one step. |
| `chestReady` | Your task chest is full! |
| `chestOpen` | Open |
| `chestGotDecor(item)` | New decoration: {item}! |
| `chestGotHints(n)` | {n} hints for you! (ICU plural) |
| `winterTitle` | Winter boxes |
| `winterTip` | Winter box: a little gift for the season |
| `winterProgress(a, b)` | {a}/{b} done |
| `winterDaysLeft(n)` | {n} days left (ICU plural) |
| `winterAllDone` | All winter boxes done! |
| `winterBack` | Back next winter |
| `snowmanName` | Snowman |
| `snowmanGot` | A snowman for your garden! |

The chest's style reward reuses the existing `newStyleFor(item)` with `decorName(value)`.

## Contract B 1.2 (B fills this section in before finishing)

Status: implemented on branch `v12-b` (all four ARB files have every key; the plain keys of Contract A 1.2, section 6, are
included with A's exact names; the 1.1 UI still compiles: nothing was renamed or removed).

`lib/l10n/l10n_ext.dart`: `levelNames` now has 45 entries, `decorNames` 45, `roomNames` 13 (the clamped helpers
`levelName(i)`, `decorName(i)`, `roomName(i)` cover the new ranges). New helpers: `winterLevelName(int)`,
`chestDecorName(int)` and `taskText(int typeIndex, [int target = 2])` (index = `TaskType.index`; `target` only matters
for the "finish N boxes" task). `ver` is "Version 1.2.0".

Keys B added beyond A's list (C may use them): `chapter3` ("Chapter 3", level map chapter name), `tasksSubtitle`,
`tasksProgress(a, b)` (summary on the house card), `taskLabelDone` (small "Done" badge on a finished task row),
`winterCardText`, `winterUntil`, `winterReward` (event card lines). Dropped because A's design covers them:
claim/claimed buttons (a finished task adds its hint at once), a separate "watch ad to double" label (use `watchAd`),
chest reward texts (use `newStyleFor`, `chestGotDecor`, `chestGotHints`).

### New plain keys
| key | English |
| --- | --- |
| `chapter3` | Chapter 3 |
| `drawerTip` | Little drawer: fill the other spots first and it opens |
| `drawerLeft(n)` | {n} more to open |
| `tasksTitle` | Daily tasks |
| `tasksSubtitle` | Three small things for today |
| `tasksProgress(a, b)` | {a}/{b} done today |
| `taskLabelDone` | Done |
| `taskTextBoxes(n)` | {n, plural, =1{Finish 1 box} other{Finish {n} boxes}} |
| `taskTextNewLevel` | Finish a new level |
| `taskTextDaily` | Finish the daily box |
| `taskTextBonus` | Finish a bonus box |
| `taskTextStyle` | Change a style in your house |
| `taskTextHint` | Use a hint |
| `taskTextMystery` | Finish a mystery box |
| `taskTextReplay` | Play a finished level again |
| `taskTextDrawer` | Finish a box with a drawer |
| `taskTextWinter` | Finish a winter box |
| `taskProgress(a, b)` | {a}/{b} |
| `taskReward` | +1 hint |
| `taskDone` | Task done! +1 hint |
| `tasksAllDone` | All tasks done. See you tomorrow! |
| `taskDoubleTitle` | Double your hint |
| `taskDoubleText` | Watch a short ad to get one more hint for this task. |
| `taskDoubled` | Hint doubled! |
| `chestTitle` | Task chest |
| `chestProgress(a, b)` | {a}/{b} days |
| `chestHint` | Finish all three tasks on a day to fill one step. |
| `chestReady` | Your task chest is full! |
| `chestOpen` | Open |
| `chestGotDecor(item)` | New decoration: {item}! |
| `chestGotHints(n)` | {n, plural, =1{1 hint for you!} other{{n} hints for you!}} |
| `winterTitle` | Winter boxes |
| `winterCardText` | 7 winter boxes |
| `winterUntil` | Available until 15 January |
| `winterReward` | Finish all 7 for a snowman in your garden |
| `winterTip` | Winter box: a little gift for the season |
| `winterProgress(a, b)` | {a}/{b} done |
| `winterDaysLeft(n)` | {n, plural, =1{1 day left} other{{n} days left}} |
| `winterAllDone` | All winter boxes done! |
| `winterBack` | Back next winter |
| `snowmanName` | Snowman |
| `snowmanGot` | A snowman for your garden! |

### Numbered keys (English)
| keys | English |
| --- | --- |
| `levelName30..44` | Laundry Basket, Ironing Kit, Peg Bag, Cleaning Caddy, Linen Cupboard, Candle Box, Game Night, Lantern Shelf, Bird Feeder Kit, Stargazing Box, Seedling Tray, Herb Box, Mushroom Basket, Flower Crate, Harvest Basket |
| `decorName30..44` | Washing machine, Ironing board, Drying rack, Cleaning shelf, Clothesline, Hanging lantern, Bistro set, Potted palm, Bird feeder, Telescope, Seedling shelf, Herb planter, Wheelbarrow, Flower buckets, Hanging fern |
| `roomName10..12` | Laundry Room, Balcony, Greenhouse |
| `winterLevelName0..6` | Mitten Basket, Ornament Box, Cookie Tin, Cocoa Tray, Gift Wrap Box, Pinecone Basket, Snow Globe Shelf |
| `chestDecorName0..3` | Garden gnome, Birdbath, Window flower box, Lantern post |

### Store texts
- `store/release-notes-1.2.0.txt`: 4 languages (`<tr-TR>`, `<en-US>`, `<de-DE>`, `<ar>`), each under 500 characters
  (tr 397, en 385, de 438, ar 336).
- `store/listing-1.2.0.json`: version 1.2.0, versionCode 5; 45 levels, 13 rooms, little drawers, daily tasks with the task
  chest, the yearly winter event. Counts (title / short / full): tr 29/63/3423, en 30/71/3349, de 30/76/3860, ar 28/58/2901.

