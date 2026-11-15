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

