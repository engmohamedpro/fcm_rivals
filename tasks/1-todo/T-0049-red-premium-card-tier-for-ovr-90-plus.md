---
id: T-0049
title: Red premium card tier for players rated 90 and over
priority: high
status: needs-review
attempts: 1
depends_on: [T-0047]
created: 2026-11-07
completed:
---

# T-0049: Red premium card tier for players rated 90 and over

## Goal
Introduce a **red premium player-card treatment for OVR ≥ 90**, visually above the golden legendary tier, shown everywhere cards are shown. **The three pack kinds and their three colours stay exactly as they are** — this is a card-tier change, not a pack change: no red pack, no new `PackTier`, no new `CardRarity` enum value.

## Context (evidence, main `6dc4fa5`)
- Card identity today keys on `CardRarity` (`lib/core/ui/fcm_style.dart:99-167`): rare/epic/legendary with amethyst/sapphire/gold accents, `intensity` 1.0/1.5/2.0, used by the card painters (`player_card_painters.dart:97-173,438` — gradients, glow, rarity row) and every surface (reveal, contents, collection, detail sheet, pre-match, squad pitch).
- Dataset reality: under the current curve only ~5 dataset rows reach 90+ (Haaland and Yamal top out at 92); after T-0046's retune the 90+ population grows but stays **ultra-rare relative to the whole dataset — measured 2026-11-07 against the proposed two-segment curve: 52 rows ≥ €72.1M → OVR ≥ 90, i.e. 0.249% of the dataset (~52 of 20,876), with quality-noise spillover bounded well under 0.5%**. Note this band supersedes the earlier "< 0.1%" guess: that number is mathematically incompatible with T-0046's "top-5 ≥ 96" contract (€150M ⇒ 96+ forces the OVR-90 boundary down to ≈ €72M, which pulls ~50 rows above it). 0.25% of the dataset — and roughly 1-in-10 of the gold (80+) pool — is still decisively the "few elite" shape, and the tier was empty enough until now that it was invisible.
- Owner requirement: the sealed pack must never advertise the red tier (the three packs keep their 3/4/5 stars and foil colours — `pack_engine.dart:59-72`); red is **discovered at reveal** as the escalation above gold.
- Design recommendation (record the decision in Developer Notes): add a presentation-level class — `isPremium` bool or a small `CardClass { standard, premium }` — computed as `overall >= 90` at the same call sites that already use `CardRarity.fromOverall` (`pack_contents_screen.dart:155`, `pack_opening_screen.dart:221`, `pre_match_analysis.dart:537`, `player_detail_sheet.dart:20`, `pack_catalog.dart:47`). Underneath, a 90+ player is still `CardRarity.legendary`, so pack pools, shelves and save compatibility are untouched. A 4th enum value was considered and rejected: it would force every exhaustive switch (painters, intensity, labels, pool filters) to grow a pack-facing "premium" case the store does not have.

## Requirements
1. Red premium identity: a red accent/palette (crimson-to-dark-red face gradient family, red glow and frame treatment) defined next to the jewel palette in `fcm_style.dart`, plus a `PREMIUM` label where `LEGENDARY` prints (rarity row on the card back).
2. Consistency rule (same as the rarity stability rule): premium is derived from the same deterministic `overall` everywhere — the same player shows red in every surface, always; 80-89 stays gold, 70-79 sapphire, <70 amethyst.
3. Apply across all card surfaces: reveal card, pack contents screen, collection grid + player detail sheet, pre-match opponent highlight, squad pitch mini cards. No surface may render a 90+ player gold.
4. A dataset test prints the 90+ population from `players_v1.json` and asserts `count ≥ 20` and `count / total` within **0.001–0.005** (measured expectation ≈ 52 rows / 0.249% under the T-0046 curve; the window absorbs quality-noise spillover and small dataset updates).
5. The three pack kinds, their colours, foil star counts and price ladder are byte-for-byte unchanged — a test asserts `PackTier.values.length == 3` and the existing accent colour constants are unchanged.

## Out of Scope
- The reveal/opening animation for the red tier (T-0050 owns the third animation).
- Rebalancing the existing animations (T-0051).
- The OVR curve (T-0046) and rarity thresholds (T-0047).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] New tests green (premium detection, surface consistency, dataset population, pack-unchanged assertion); full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified — the `PREMIUM` label localized in both languages
- [ ] No performance or application-size regression
- [ ] A 90+ player renders red in every card surface; an 89 player renders gold (test-locked)
- [ ] Pack kinds/colours provably unchanged

## How to Verify
```bash
flutter analyze
flutter test test/core/ui/ test/features/packs/ test/features/collection/ test/core/domain/
flutter test
```
Expected: analyzer clean; new premium tests green; full suite green; the dataset test prints the 90+ population and share.

## Side-effect risk (low)
Pure presentation over an existing determinstic key. Risks: a missed surface still showing gold (mitigated by the consistency test enumerating the surfaces), and AR localization of the new label. Painter switches stay exhaustive — the class rides on top of `CardRarity`, so no switch grows a case.

## Developer Notes
- **Design decision (as the task recommended):** a presentation-level `CardClass { standard, premium }` in `fcm_style.dart`, computed `overall >= premiumOverallThreshold (90)` — the same deterministic input `CardRarity.fromOverall` reads, at the same call sites. A 4th `CardRarity` value was rejected per the task's analysis: no pack-facing switch grows a case, and the painters' rarity motif/star switches stay untouched (premium rides the legendary sunburst and its 5 stars).
- **Red identity:** the premium palette lives on `CardClass` — face gradient crimson sheen `0xFFFFD9CF` → champion crimson `0xFFDC2436` → deep oxblood `0xFF4A0409`, crimson accent `0xFFF43F5E` (glow/rays/pills), near-black maroon ink `0xFF2B0206`, intensity 2.5 (one notch above the legendary 2.0 show). Both painters take `cardClass` (default `standard`) and branch the palette inline — no switch grew a case; `shouldRepaint` covers the new axis.
- **Surfaces (requirement 3, all rendering 90+ red):** pack reveal (front via `FcmPlayerCard`'s internal derivation + pre-flip back via the new `FcmPlayerCardBack.cardClass`), pack contents rows + the localized rarity-tag pill, collection player detail sheet + pill, pre-match opponent key men, squad pitch mini cards (bench, XI, drag feedback) and the collection reveal — `FcmMiniCard` and `FcmPlayerCard` derive the class internally from the same `overall` their callers used for the rarity, so those call sites needed zero churn. `pack_catalog` shelf counts stay rarity-keyed BY DESIGN: premium players are inside the legendary pool, so the shelf math is untouched.
- **PREMIUM label:** the canvas/front label prints `PREMIUM` where `LEGENDARY` did — EN brand mark by the existing rarity-label convention (`RARE/EPIC/LEGENDARY` are EN on canvas too). The user-facing pill surfaces localize through the new ARB key `cardClassPremium` ('PREMIUM' / AR 'نخبة') via `lib/l10n/card_class_l10n.dart` — RTL-safe (no positional interpolation).
- **Measured dataset population (requirement 4):** **31 of 20,876 rows (0.148%)** reach OVR 90+ — the task's ≈52/0.249% estimate came from the noise-free curve boundary; the live seeded dataset (quality/style noise as shipped) lands at 31, inside the required [0.001, 0.005] share window and above the ≥ 20 floor. The test prints and asserts the window, so small dataset updates stay covered.
- **Files changed:** `lib/core/ui/fcm_style.dart` (`CardClass` + palette); `lib/core/ui/player_card_painters.dart` (both painters); `lib/core/ui/player_card.dart` (`FcmPlayerCard` derivation, `FcmPlayerCardBack.cardClass`); `lib/core/ui/mini_card.dart`; `lib/features/packs/pack_opening_screen_reveal.dart`; `lib/features/packs/pack_contents_screen.dart` (class + localized tag); `lib/features/collection/player_detail_sheet.dart` (localized pill); `lib/l10n/app_en.arb` + `app_ar.arb` (+`cardClassPremium`); `lib/l10n/card_class_l10n.dart` (new); `test/core/ui/card_class_test.dart` (new, 9 tests).
- **How I tested it:** `flutter analyze` → No issues found. Full `flutter test` → **767 passed / 0 failed, ALL GREEN** (targeted core/ui + packs + collection + domain: 141/141). Locked by test: the exact 90/89 boundary; `CardRarity.values.length == 3` with 80-89 still gold (the "no 4th value" invariant); the red palette distinct from every jewel accent; surface consistency by pumping the real widgets and asserting the painter's class axis (FcmMiniCard 92→premium / 89→standard, FcmPlayerCard 90→premium / 80→standard, back 95→premium); the dataset window; and the packs provably unchanged — `PackTier.values.length == 3` plus the three accent colour constants and star counts asserted at their exact shipped values.
- **Concerns / assumptions:** (1) The measured 90+ population is 31, not the task's ≈52 estimate — the task's own window absorbs it; recorded so the reviewer does not read it as a regression. (2) The card-canvas labels stay EN (existing convention); the localized surface is the pill tag in pack contents and the detail sheet. (3) No reveal/opening animation change for red — T-0050 owns the third animation; today the reveal shows the red treatment through the existing legendary choreography.

## Review Log
