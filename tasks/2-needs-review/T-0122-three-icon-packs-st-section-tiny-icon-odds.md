---
id: T-0122
title: Three icon packs in the store — ST section, tiny icon odds
priority: high
status: needs-review
attempts: 1
depends_on: [T-0121]
created: 2026-11-12
completed:
---

# T-0122: Three icon packs in the store — ST section, tiny icon odds

## Goal
The store's ST (Centre-Forward) section shows THREE new packs above the existing ST tier cells, with a very tiny chance of pulling an icon player card:
1. **Icon Pack I** — Epic players + Icons
2. **Icon Pack II** — Epic + Legendary players + Icons
3. **Icon Pack III** — Epic + Legendary + Premium players + Icons

## Context
**Owner request 2026-11-12 (verbatim structure):** "add 3 icons packs on top of ST packs in the store … very very very tiny chance to win icon player card. first pack contain epic players + icons players; second pack contain epic players + legendary players + icons players; third pack contain epic players + legendary players + premium players + icons players."

**Existing machinery (studied):**
- Store shelf: `lib/features/packs/packs_store_widgets.dart` — `StoreGrid` groups offers into sections by `category:scopeValue` keeping catalog order (`pack_catalog.dart` loops `Position.values` = enum order: ST, LW, RW, CAM, LM, RM, CM, CDM, CB, RB, LB, GK — **ST is already the first section**), then orders cells by `PackTier.values` (rare, epic, legendary). The ST section is the first `_ScopeSection` on the shelf.
- Draw: `lib/features/packs/pack_engine.dart` — two-stage: stage 1 rolls a rarity from the tier's `PackRarityOdds` table (rare/epic/legendary/premium), stage 2 value-weighted draw inside the band (`weightFor`, `(poolMinMv/mv)^1.5`). `PackTier` enum currently has rare/epic/legendary and maps 1:1 onto `PackOddsConfig` tables; `PackTier.fromName` parses persisted values with legacy fallbacks.
- Catalog: `lib/features/collection/pack_catalog.dart` — `storeOffersFor(registry, economy)` builds `StorePackOffer`s (title, price via `packPriceFor`, eligibleCount); position packs are scoped by `Position` and tier.
- Price: `expectedPackValue` (two-stage EV through the `EconomyEngine`) × margin, floored to thousands. Legendary margin is higher (`legendaryPackMarginMultiplier`).
- Persistence: `Packs` table (`category`, `scopeValue`, `tier`, `price`, `source`); buy path `collection_store.buyPack` → `openPack` → reveal (`packs_screen._buy/_open/_reveal`, chain OPEN ANOTHER).
- `PackScope.matches` filters the pool; the T-0121 requirement already excludes icons from the normal pools.
- Reveal visuals: `pack_tier_colors.dart` (accent + stars per tier), `pack_opening_screen.dart`/`pack_opening_widgets.dart`.

**Pool facts (measured on the new dataset, T-0120/T-0121):** ST survivors 5,074 (rare 4,634 / epic 347 / legendary 83 / premium 10) + 27 ST icons (OVR 90–99 after mapping). The icon packs draw ONLY from ST-scope pools.

**Design decision (this task):** icon packs are a new `PackTier.icon1/icon2/icon3`? NO — implement them as a new **pack kind**, not three new tiers bolted onto `PackTier`: add ONE new `PackTier.icon` value (or a separate category, implementer's choice per the house pattern) with THREE odds tables on `PackOddsConfig` (`iconPack1/2/3`), so the existing two-stage engine, EV pricing and reveal flow all work unchanged. Rarity roll stays 4-band; the icon flag is a **fifth, separate roll** (see R3).

## Requirements
1. Three icon odds tables in `PackOddsConfig` (owner's "very very very tiny" icon chance — defaults 0.2% / 0.5% / 1.0%, owner-tunable constants, each table sums to exactly 1.0):
   - Icon I: rare 0, epic 0.998, legendary 0, premium 0, icon 0.002 (Epic + Icons only)
   - Icon II: rare 0, epic 0.700, legendary 0.295, premium 0, icon 0.005 (Epic + Legendary + Icons)
   - Icon III: rare 0, epic 0.550, legendary 0.350, premium 0.090, icon 0.010 (Epic + Legendary + Premium + Icons)
   Bands with 0 weight are NEVER rolled (no fallback into them — `PackScope` for icon packs must exclude rare players entirely, not rely on band odds alone, so the empty-band fallback can never "borrow" a rare ST).
2. The icon roll is explicit and separate: with the configured icon probability the draw is an icon (uniform-ish value-weighted across the 27 ST icons); otherwise the normal band roll runs among the pack's allowed bands. The reported draw tier keeps distinguishing icon pulls (reveal shows the icon badge moment).
3. `pack_catalog.dart`: three new offers in the ST section, ordered ABOVE the ST tier cells (Icon I, II, III — ascending price). Titles: "Icon Pack I/II/III" (l10n keys for EN/AR, following the existing arb pattern). `eligibleCount` reflects the pack's real pool.
4. `packs_store_widgets.dart`: the ST section renders the three icon cells first, with a distinct accent (house gold family is reserved for golden chemistry links and legendary tier — pick a distinct icon treatment, e.g. the T-0121 badge motif) and a "tiny icon chance" caption on the cell (l10n EN/AR).
5. Buy/open/persist: `buyPack`/`openPack` accept the icon packs (persisted `tier` string parses back via `PackTier.fromName` — extend it), the reveal flow and OPEN ANOTHER chain work, coins ledger reasons unchanged.
6. Pricing: `expectedPackValue` extended to include the icon EV (icon MVs are 78M–306M — the icon probability must be priced in or the packs are free money). Icon packs use the legendary margin multiplier at minimum; if the EV makes them the most expensive shelf items, that is CORRECT (they are the top products).
7. Odds transparency: the contents/odds sheet (`oddsFor` display path, `pack_contents_screen.dart`) shows the icon line "Icons: 0.2%" style rows for the icon packs.
8. Tests: odds tables validate (sum to 1, weights in [0,1] — `PackOddsConfig.validate` pattern); 100k-seeded probe over each icon pack: empirical icon rate within tolerance of configured, zero rare pulls, band composition matches the table; EV/price monotonicity (Icon I < Icon II < Icon III price); catalog test: exactly 3 icon offers, ST section only, ordered above tier cells; store widget test: cells render with caption and distinct accent.

## Out of Scope
- Icon wildcard chemistry (T-0123).
- Non-ST icon packs (owner said "on top of ST packs" — ST scope only; globalizing is a later decision).
- Pity/guaranteed-icon rules; real-money pricing; daily limits.
- Balance re-lock of the normal pack economy (T-0124 re-locks after the dataset change; icon packs get their own calibration test here).

## Acceptance Criteria
- [ ] The store's ST section shows 3 icon pack cells above the Rare/Epic/Legendary ST cells, with EN+AR titles and the icon-chance caption; no other section changes.
- [ ] Seeded 100k draws per pack: icon rate ≈ configured (0.2%/0.5%/1.0% ± statistical tolerance), zero rare-band pulls, band shares match the tables, every icon pull is one of the 27 ST icons.
- [ ] Icon Pack prices are strictly ascending I < II < III and above the ST Legendary pack price.
- [ ] Buying and opening each icon pack works end-to-end (coins charged, card owned, reveal shows, icon badge on icon pulls); OPEN ANOTHER chains.
- [ ] `PackTier.fromName` round-trips the persisted icon pack tier strings.
- [ ] `flutter analyze` clean; new tests pass; no new failures in the packs test family.

## How to Verify
```bash
flutter analyze
flutter test test/features/packs/ test/balance/pack_probability_calibration_test.dart
flutter run -d <device>   # Store tab: ST section shows the 3 icon packs on top
```
Expected: analyze clean; probability probe matches configured odds; manual store check shows the three cells.

---

## Developer Notes

## Review Log

**Review 2026-11-12 (QA, commit 5925017 implemented before reading):** PARTIAL — 4 deviations, owner decision needed.
Built as `PackCategory.icon` + tiers iconEpic/iconLegendary/iconSupreme in a separate
"Icon Pack" section ABOVE the ST section (shelf order test-locked). Icon chances 0.5/1.0/1.5%.
Deviations from this spec: (D1/F1, HIGH) pack I carries rare 30% — spec said epic+icons only;
(D2/F2, MED) pool is ALL positions, spec assumed ST-scope — owner's "on top of ST packs"
reading unresolved; (D3/F3, MED) contents-screen odds strip shows no icon line and icon
labels are hardcoded EN (no ARB keys); (D4/F4, MED) price ladder flat: 11,000/24,000/24,000 —
Icon Legendary = Icon Supreme = ST Legendary (spec required strictly ascending, above ST
Legendary). 100k-draw calibration ±4σ passes for the shipped values. Verdict: needs owner
ruling on D2, then fix F1/F3/F4; block release on F1.
