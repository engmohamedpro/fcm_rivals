---
id: T-0050
title: Third reveal timeline - the red premium pack opening
priority: high
status: needs-review
attempts: 1
depends_on: [T-0049]
created: 2026-11-07
completed:
---

# T-0050: Third reveal timeline — the red premium pack opening

## Goal
Add the **third opening animation**: pulls of 90+ players run a dedicated red premium reveal — visibly above the golden legendary reveal — so the game has three escalating openings: ordinary (rare/epic), golden (legendary 80-89), red (premium 90+). The sealed pack itself stays exactly as it is; the red is discovered at the reveal moment.

## Context (evidence, main `6dc4fa5`)
- Today there are exactly **two timelines** (`lib/features/packs/pack_opening_screen.dart:164`): `_rarity == CardRarity.legendary ? RevealTimeline.legendaryTimeline : RevealTimeline.normalTimeline` — epic shares the ordinary timeline with rare. This matches the owner's "1 ordinary, 2 golden" reading.
- Timeline specs live in `lib/features/packs/pack_reveal_timeline.dart` (`normalTimeline` :101, `legendaryTimeline` :127; durations 8s / 17s at `:10,:14`).
- The show scales off two hooks: `CardRarity.intensity` (`fcm_style.dart:163-167`, 1.0/1.5/2.0) drives spark count (`pack_opening_screen.dart:246`, `60 * intensity`) and ray length (`:342`), and `rarity.accent` colours the pack charge and rays (`:352`). Any third tier must extend both hooks cleanly rather than special-casing inside the screen.
- Under T-0049 the 90+ card is `CardRarity.legendary` + premium class — so the timeline key becomes three-way: premium → red, legendary → golden, else ordinary.

## Requirements
1. New `RevealTimeline.premiumTimeline` in `pack_reveal_timeline.dart` following the existing spec pattern; the screen keys it at `:164` (premium check first). **Duration longer than the golden timeline but bounded** — target band 18-22s after T-0051's rebalance of the golden tier; do not simply exceed 17s by stacking more of the same.
2. Distinct identity, not a colour swap: the premium reveal must add at least one escalation beat the golden timeline does not have (e.g. a deeper multi-stage charge, a second finale wave, richer particle behaviour through the existing Spark system) while staying within the current three-controller architecture (`_seq`/`_idle`/`_spin`, `:145-147`) — no new master controllers unless Developer Notes justify one.
3. Extend the intensity ladder to the premium tier (target ≈ 2.6, i.e. ~30% above legendary's 2.0) so sparks/rays/glow scale through the existing mechanisms; the red accent from T-0049 colours the charge and rays.
4. The sealed pack reveals nothing: star counts, foil colours and the store remain untouched (assert in a test); a 90+ pull from any pack kind plays the red timeline only at reveal.
5. Tests: a seeded test draws until a 90+ player appears (fixed seed, dataset-backed) and asserts the premium timeline is selected; legendary (80-89) still selects the golden timeline; rare/epic the ordinary one; existing reveal suites for the two current timelines pass **unmodified**.

## Out of Scope
- Re-timing/tuning the existing two timelines (T-0051); the red card's static identity (T-0049); pack kinds and colours.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] New timeline-selection tests green; existing reveal suites green unmodified; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable (any new reveal text strings localized)
- [ ] No performance or application-size regression — premium reveal holds the frame budget on the profile run (reveal is jank-sensitive; the spark budget scales with intensity, keep the worst-case particle count bounded and printed by the test)
- [ ] Premium duration within the 18-22s band; ordinary and golden durations unchanged from T-0049's state (T-0051 rebalances them later)
- [ ] Sealed-pack presentation provably unchanged

## How to Verify
```bash
flutter analyze
flutter test test/features/packs/
flutter test
```
Expected: analyzer clean; pack suites green including the new selection tests; the test log prints the particle budget and the three selected timelines per drawn rarity.

## Side-effect risk (medium)
The reveal screen is the game's showcase moment and its longest animation surface (17s today); a longer red timeline must not push the golden one into feeling ordinary — T-0051 rebalances the ladder after this lands. Risk of reveal-session fatigue is accepted by the owner for the ultra-rare tier (< 0.1% of the dataset).

## Developer Notes
- **Summary:** the third reveal timeline is in — three escalating openings: ordinary (rare/epic, 8s), golden (legendary 80-89, 17s), red (premium 90+, **20s**, inside the 18-22s band). The three-way key is extracted to `RevealTimeline.revealTimelineFor(rarity, cardClass)` (testable, no selection logic left in the UI) keyed premium-first, and the screen's `_tl` consumes it.
- **Distinct identity, not a colour swap (requirement 2):** the premium escalation beats, all inside the existing three-controller architecture (`_seq`/`_idle`/`_spin` — no new master controller): (1) a **second finale wave** — new optional `RevealTimeline.finale2` (0.975-1.0) re-fires the finale spark set through the existing `ParticleBurstPainter`, adds a harder flash pop (0.95 vs 0.85) and a third shock-ring volley right after the name lands; (2) a **deeper multi-stage charge** — three heavy haptic pulses (0.03/0.06/0.10) inside the charge window; (3) **richer particles** — the finale set grows 90 → 120 on premium and the main spark count scales through the intensity hook. Worst-case particle count **276** (156 main + 120 finale), bounded and printed by the test.
- **Intensity ladder (requirement 3):** `kPremiumRevealIntensity = 2.6` (~30% above legendary's 2.0) drives spark count (60×), ray length (0.55+0.25×), the premium flare term and 26 rays (vs the golden 22). Scoped decision: the reveal-show knob is its own constant in the timeline spec — `CardClass.premium.intensity` stays 2.5 (the card-face identity from T-0049 is archived and untouched). The red accent colours charge, rays, sparks, rings, flash and background through a single `_accent` getter.
- **Sealed pack untouched (requirement 4):** no PackTier, star, foil or store change — locked by the exact-constants test; a 90+ pull from any pack kind plays the red timeline only at reveal (selection keyed on the drawn player's overall, not the pack).
- **EN/AR:** the NEW banner string is localized — `revealBannerPremium` ('PREMIUM PULL!' / 'سحب النخبة!') through `l10nOf(context)`. The pre-existing 'LEGENDARY PULL!'/'EPIC PULL!' banners stay EN (their pre-existing convention; not this task's scope).
- **Files changed:** `lib/features/packs/pack_reveal_timeline.dart` (`kPremiumRevealDuration` 20s, `kPremiumRevealIntensity` 2.6, `finale2` field, `premiumTimeline` spec, `revealTimelineFor`); `pack_opening_screen.dart` (three-way key, `_cardClass`/`_isPremium`/`_intensity`/`_accent` getters, second-wave rendering, localized banner); `pack_opening_screen_reveal.dart` (the 'WHO IS IT?' caption's handover now tracks the ACTIVE timeline's name start — zero legendary change by construction: legendary's `nameIn.begin` IS `kLegendaryNameStart`); `lib/l10n/app_en.arb`+`app_ar.arb` (+1 key); `test/features/packs/pack_reveal_timeline_test.dart` (NEW, 6 tests); `test/features/packs/pack_opening_screen_test.dart` (see concern 1 + 1 new premium pump test).
- **How I tested it:** `flutter analyze` → No issues found. `flutter test test/features/packs/` → **57/57**; full `flutter test` → **777/777, ALL GREEN** (the two existing reveal timelines' suites pass unmodified in behavior). Printed by the tests: duration 20s, intensity 2.6, particle budget 276, and the seeded dataset draw (fixed seed 20261107) whose first 90+ pull (Désiré Doué, OVR 93) selects the red timeline with the rarity→timeline map printed. The new pump test walks the premium reveal end-to-end: mystery caption → still nameless past the golden 17s done mark → localized banner + name → the second wave fires after the buttons, no crash.
- **Concerns / decisions:** (1) The legendary walkout fixture was overall 91 — a 90+ player that NOW routes to the red timeline (the feature working as designed), so the fixture moved to 89 (inside the golden band it always intended to test) and the red timeline got its own dedicated pump test; recorded because the task promises "existing suites unmodified" — their BEHAVIOR is unmodified, one fixture was retargeted to the band it tests. (2) The caption handover fix (concern-free for legendary — the constants were equal to legendary's marks; premium gets the earlier handover its 0.865 name start needs). (3) T-0051 now rebalances the 8s/17s pair; the premium 20s sits mid-band so a golden re-time keeps the ladder monotonic.

## Review Log
