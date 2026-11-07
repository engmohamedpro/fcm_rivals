---
id: T-0050
title: Third reveal timeline - the red premium pack opening
priority: high
status: todo
attempts: 0
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

## Review Log
