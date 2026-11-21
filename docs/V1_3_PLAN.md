# Tidy Nook 1.3.0: plan and team contract

Goal: revenue. Add one new paid product that fits the winter event (1 Dec - 15 Jan), plus a small free winter
gift so every player sees the new decor. Version `1.3.0+6`. Ship before 1 December, as an update to the running
closed test (later production).

Read first: `docs/V1_2_PLAN.md` (contracts A/B 1.2), `docs/V1_1_PLAN.md` (hard rules, ad rules, "Build and check"),
`docs/MONETIZATION.md`, then the code. All hard rules still hold: 4 languages (tr, en, de, ar RTL), no banner,
no timers or fail state, no paywalled levels, never wait for an ad, offline works, Butter & Sage theme only,
Progress loads old saves losslessly (schema 4 -> 5 with migration).

## What 1.3 contains

1. **Winter Cozy Pack** (new one-time product, id `winter_pack`, suggested price TRY 49.99 / USD 1.99):
   - 5 winter decor pieces for the house, painted in the existing style and placed where they read well:
     a garland over the living room fireplace or window, a wreath on the front door, warm string lights along
     the roof, a knit rug in the bedroom, a sled by the snowman in the garden (A decides the exact set and spots;
     none may overlap existing furniture).
   - A 4th "winter" style for 6 chosen furniture pieces (e.g. armchair, bed, lamp, table, sofa, rug), switchable
     like the other styles.
   - Kept forever, visible all year (the snow itself stays event-only).
   - Does NOT remove ads and does not include hints (keeps remove_ads / supporter_pack valuable).
2. **Free winter gift**: during the event window, finishing the first winter box gives one free decor piece
   (e.g. a mug of cocoa on the patio table), so every player sees what winter decor looks like next to the pack.
3. **Where the pack is offered** (calm, never a pop-up that blocks play, at most once per day as a card):
   - on the winter event card (a small "Cozy Pack" pill),
   - in the shop in settings, next to the two existing products,
   - once on the win card of the 7th winter box (snowman reveal), as a secondary line, not a modal.
   - Owners see "Owned" and no offer.
4. **Analytics**: winter_pack_offer_shown (placement), winter_pack_purchase, winter_gift_granted.

Monetisation note: no change to interstitial or rewarded rules. No banner.

## Team and file ownership

| Owner | Files |
| --- | --- |
| A: decor, styles, entitlement, gift logic, art (Opus) | `lib/game/**`, `test/game_*_test.dart` |
| B: translations and store texts (Sonnet) | `lib/l10n/*.arb`, `lib/l10n/l10n_ext.dart`, `store/**` |
| C: UI, billing, offer placements (Opus, phase 2) | `lib/main.dart`, `lib/ui/**`, `lib/monet/**`, `lib/services/**`, `test/widget_test.dart`, `pubspec.yaml` (version only) |
| QA (Sonnet, phase 3) | report only |

Phase 1: A and B in parallel on `v13-a`, `v13-b` from `main`. Phase 2: manager merges, C on `v13-c`.
Phase 3: QA on the web build. Release: manager merges and pushes `[play]`. Build and check as in
`docs/V1_1_PLAN.md`, branch names `v13-*`. Never push to `main`, never create tags.

## Contract A 1.3 (A fills this in before finishing)

## Contract B 1.3 (B fills this in before finishing)
B also writes `store/release-notes-1.3.0.txt` (4 languages, each <=500 chars, tags <en-US> <tr-TR> <de-DE> <ar>),
`store/listing-1.3.0.json` (mention the Winter Cozy Pack and free winter gift; keep limits), and the product
texts for `winter_pack` in 4 languages (name <= 55 chars, description <= 200 chars) in `store/products-1.3.0.md`.
