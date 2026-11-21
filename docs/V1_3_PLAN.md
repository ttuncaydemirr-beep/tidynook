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

Status: implemented on branch `v13-a` (compiles and passes tests with today's UI; nothing renamed or removed; no new
dependency). Everything is exported by `package:tidy_nook/game/content.dart` (it now also exports `winter_pack.dart`);
state in `progress.dart`. The game code uses no text keys itself: C reads the keys below through B's ARB/`l10n_ext`
helpers, exactly like 1.2 (numbered keys get a clamped helper in `l10n_ext`).

### 1. What the pack contains (A's choice)

| # | winter decoration (`winterDecorName0..4`) | where (house space) |
| --- | --- | --- |
| 0 | Pine garland | along the top of the Bedroom wall (above the curtained window) |
| 1 | Holly wreath | Kitchen wall, left of the pendant lamp |
| 2 | Warm roof lights | string lights under both roof slopes (around the chimney) |
| 3 | Wooden sled | greenhouse lawn, left of the greenhouse |
| 4 | Paper star lantern | Reading Nook, above the bookcase |

Winter style (style index 3) for 6 pieces: 1 floor lamp, 2 rug, 5 bed, 7 kitchen table, 8 armchair, 19 rocking chair
(cranberry / pine / snow palette with a small knit or holly touch). Free winter gift: a **little fir tree** with a star
on the greenhouse lawn (`winterGiftName`). None of these overlaps any furniture, pet, chest decor, the snowman, the
chimney, the roof window or each other (tested in `test/game_v13_test.dart`, like the snowman test). Pack and gift show
all year (also without snow). The pack does not remove ads and gives no hints.

### 2. Public API

```dart
// winter_pack.dart (via content.dart)
const String winterPackId = 'winter_pack';      // Play product id (non-consumable)
const int winterStyle = 3;                     // the 4th style
const int maxStyleCount = 4;
const int styleCount = 3;                      // UNCHANGED: every piece has 3; loops over it still show 3
const List<int> winterStylePieces = [1, 2, 5, 7, 8, 19];
bool hasWinterStyle(int level);
const int winterDecorCount = 5;
enum WinterPackItemKind { decor, style }
class WinterPackItem { final WinterPackItemKind kind; final int index; bool get isDecor; }
const List<WinterPackItem> winterPackItems;    // 5 decor (index 0..4) then 6 style pieces (index = level)
String winterDecorSvg(int i);                  // house-space fragment
String winterDecorPreviewSvg(int i);           // tile preview (offer card / shop list / purchase toast)
List<Rect> winterDecorParts(int i); Rect winterDecorBounds(int i); Offset winterDecorSpot(int i); // sparkles/scroll
String winterGiftSvg(); String winterGiftPreviewSvg({bool locked = false});
const Rect winterGiftRect; const Offset winterGiftSpot;
// content.dart
String winterPackPreviewSvg();                 // one picture of the pack, viewBox "0 0 300 200" (5 decor + winter armchair)
String decorSvg(int i, int v);                 // v = 3 draws the winter style for winterStylePieces, else style A
String decorPreviewSvg(int levelIndex, int variant);   // variant 0..3
String houseSvg({..., bool winterPack = false, bool winterGift = false});   // only drawn with extended: true
Rect decorBounds(int levelIndex); Rect petBounds(int pet); Rect chestDecorBounds(int i);  // house space (tests, layout)

// progress.dart
static const int schemaVersion = 5;
bool winterPack; bool winterGift; bool winterGiftShown; String winterOfferDay;   // saved (see 5.)
void setEntitlements({required bool adsRemoved, required bool supporter, bool? winterPack});
                                               // winterPack null (= today's callers) keeps the stored value,
                                               // so an old call can never revoke the pack; pass true/false from billing
bool get winterPackOwned;
bool styleAvailable(int level, int variant);   // variant 3: winterPack && hasWinterStyle(level)
int styleOf(int level);                        // 0..3 (stored 3 without the pack shows as 0, comes back with it)
int styleCountOf(int level);                   // 4 for a winter piece with the pack, else 3
List<int> styleChoices(int level);             // [0,1,2] or [0,1,2,3]
int nextStyleOf(int level);                    // cycles over the available styles of styleChoices
bool canOfferWinterPack(DateTime now);         // !owned && winterActive(now) && not offered on a card today
bool markWinterPackOffered(DateTime now);      // stores today; false if already offered today
bool get winterGiftToReveal;                   // gift earned and reveal not shown yet (saved: survives a restart)
bool markWinterGiftShown();                    // true the first time
bool takeWinterGiftGranted();                  // true once right after completeWinter granted the gift (not saved)
({bool fresh, bool snowman}) completeWinter(int i, DateTime now);  // unchanged signature; the first finished winter
                                               // box (any index) now also sets winterGift = true
```

### 3. What C must wire

- **House**: `houseSvg(..., winterPack: p.winterPackOwned, winterGift: p.winterGift)`.
- **Style pickers** (both use `styleCount` today, which stays 3, so nothing breaks before C changes them):
  - win card / any picker: loop over `p.styleChoices(level)` instead of `0..styleCount-1`; label the tile of
    `winterStyle` with `styleWinter` (others keep `styleN(v + 1)`); the house semantics label likewise
    (`p.styleOf(i) == winterStyle ? t.styleWinter : t.styleN(...)`).
  - house tap-to-change: `ctl.nextStyle(i)` loops `% styleCount`; replace its body with `progress.nextStyleOf(level)`.
  - non-owners never see a 4th tile (no locked winter tile; the pack is offered only at the placements below).
- **Billing**: product `winterPackId` next to `remove_ads` / `supporter_pack`; pass `winterPack: owned.contains(winterPackId)`
  to `setEntitlements` (the `EntitlementSink` typedef can gain `bool? winterPack`; `Progress.setEntitlements` tear-off
  stays assignable). Initial owned set from `progress.winterPack`. After a purchase: toast `winterPackThanks`, sparkles at
  `winterDecorSpot(d)` for d in 0..4.
- **Offer placements** (never a blocking pop-up):
  - winter event card: small pill `winterPackPill` when `!p.winterPackOwned` (the pill is not the "card"); tapping
    it opens the offer card (preview `winterPackPreviewSvg()` or tiles from `winterPackItems`, `winterPackName`,
    `winterPackBlurb`, `winterPackFeature1..3`, `winterPackNote`, buy button `buyFor(price)`).
  - the offer card may open by itself or the 7th-box line may show only when `p.canOfferWinterPack(now)`; call
    `p.markWinterPackOffered(now)` when it is shown and log `winter_pack_offer_shown` (placement). This gives the
    "at most once per day as a card" rule.
  - win card of the 7th winter box (`r.snowman` or `winterDoneCount == 7` fresh): secondary line `winterPackSnowmanLine`
    if `canOfferWinterPack(now)`.
  - shop in settings: always a row (`winterPackName`, `winterPackShopText`), `owned` for owners, else `buyFor(price)`.
  - owners: `owned` and no offer anywhere.
- **Winter gift**: after `completeWinter`, `if (p.takeWinterGiftGranted()) log winter_gift_granted`; whenever the house
  shows and `p.winterGiftToReveal`, show the reveal (`winterGiftTitle`, `winterGiftText`, `winterGiftPreviewSvg()`,
  sparkles/scroll to `winterGiftSpot`), then `p.markWinterGiftShown()`. A short toast alternative: `winterGiftGot`.

### 4. Text keys (English source; B translates, C uses)

Numbered: `winterDecorName0..4` = Pine garland, Holly wreath, Warm roof lights, Wooden sled, Paper star lantern.
Suggested `l10n_ext` helper: `winterDecorName(int i)` (clamped, like `chestDecorName`). Existing keys reused:
`owned` (Owned), `buyFor(price)`, `styleN(n)`, `decorName(i)` (names of the 6 winter-style pieces).

| key | English |
| --- | --- |
| `winterGiftName` | Little fir tree |
| `winterGiftTitle` | A winter gift for you! |
| `winterGiftText` | Thanks for playing the winter boxes. A little fir tree now stands by your greenhouse, yours to keep. |
| `winterGiftGot` | A little fir tree for your garden! |
| `styleWinter` | Winter style |
| `winterPackName` | Winter Cozy Pack |
| `winterPackBlurb` | Make your house cozy for winter. Yours to keep, all year. |
| `winterPackFeature1` | 5 winter decorations for your house |
| `winterPackFeature2` | A winter style for 6 pieces of furniture |
| `winterPackFeature3` | One-time purchase, kept forever |
| `winterPackNote` | Ads and hints stay as they are. |
| `winterPackShopText` | 5 winter decorations and a winter style for 6 pieces. |
| `winterPackPill` | Cozy Pack |
| `winterPackSnowmanLine` | Make it even cozier with the Winter Cozy Pack |
| `winterPackThanks` | Your house is ready for winter! |
| `winterPackPreviewTitle` | What's inside |

### 5. Progress schema 5

New keys: `winterPack` (bool), `winterGift` (bool), `winterGiftShown` (bool, only true together with `winterGift`),
`winterOfferDay` ("YYYY-MM-DD" or ""). Stored styles may now be 3 (values above 3 still fall back to 2, values below 0
to 0). A schema 4 save loads with every value unchanged and the new keys at defaults (tested with a 1.2 fixture).
`reset()` keeps the pack (purchase), the gift and its reveal flag (keepsake) and the offer day.

## Contract B 1.3 (B fills this in before finishing)
B also writes `store/release-notes-1.3.0.txt` (4 languages, each <=500 chars, tags <en-US> <tr-TR> <de-DE> <ar>),
`store/listing-1.3.0.json` (mention the Winter Cozy Pack and free winter gift; keep limits), and the product
texts for `winter_pack` in 4 languages (name <= 55 chars, description <= 200 chars) in `store/products-1.3.0.md`.

Status: implemented on branch `v13-b`. All four ARB files have every key below, using exactly the names from Contract A 1.3
section 4 (nothing renamed or removed; `ver` now says 1.3.0). A's pack content is reflected in the store texts (gift =
little fir tree on the greenhouse lawn, decor = garland, wreath, roof lights, sled, star lantern).

`lib/l10n/l10n_ext.dart`: new `winterDecorNames` (5 entries) and the clamped helper `winterDecorName(int i)`.
Store files: `store/release-notes-1.3.0.txt` (each language <= 500), `store/listing-1.3.0.json` (versionCode 6, counts
recomputed, full_description <= 4000), `store/products-1.3.0.md` (`winter_pack` name and description, 4 languages).

### New keys (English)
| key | English |
| --- | --- |
| `winterDecorName0..4` | Pine garland, Holly wreath, Warm roof lights, Wooden sled, Paper star lantern |
| `winterGiftName` | Little fir tree |
| `winterGiftTitle` | A winter gift for you! |
| `winterGiftText` | Thanks for playing the winter boxes. A little fir tree now stands by your greenhouse, yours to keep. |
| `winterGiftGot` | A little fir tree for your garden! |
| `styleWinter` | Winter style |
| `winterPackName` | Winter Cozy Pack |
| `winterPackBlurb` | Make your house cozy for winter. Yours to keep, all year. |
| `winterPackFeature1` | 5 winter decorations for your house |
| `winterPackFeature2` | A winter style for 6 pieces of furniture |
| `winterPackFeature3` | One-time purchase, kept forever |
| `winterPackNote` | Ads and hints stay as they are. |
| `winterPackShopText` | 5 winter decorations and a winter style for 6 pieces. |
| `winterPackPill` | Cozy Pack |
| `winterPackSnowmanLine` | Make it even cozier with the Winter Cozy Pack |
| `winterPackThanks` | Your house is ready for winter! |
| `winterPackPreviewTitle` | What's inside |

No plural keys were needed (all counts are fixed). Existing keys reused by C: `owned`, `buyFor(price)`, `styleN(n)`.
