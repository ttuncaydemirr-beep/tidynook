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

B lists every new ARB key with its English text. Keys for A's content (level names, room names, mechanic hint)
come from A's section; B may start from this plan and add A's keys once A's section exists (re-read it).
Also: `store/release-notes-1.2.0.txt` in 4 languages (max 500 characters each, tagged `<en-US>`, `<tr-TR>`,
`<de-DE>`, `<ar>`), and updated `store/listing-1.2.0.json` mentioning 45 levels, daily tasks and the winter event.
