---
id: T-0051
title: Rebalance the reveal escalation ladder - ordinary, golden, red
priority: medium
status: needs-review
attempts: 1
depends_on: [T-0050]
created: 2026-11-07
completed:
---

# T-0051: Rebalance the reveal escalation ladder — ordinary, golden, red

## Goal
Audit and retune the three reveal animations so the escalation reads clearly at every tier — each opening visibly above the one before it, no tier feeling hollow next to the new red reveal — per the owner's instruction to "revise the current two animations and fix if they need improvements to be balanced according to the new animation".

## Context (evidence, main `6dc4fa5`)
- Current ladder: ordinary 8s (`pack_reveal_timeline.dart:10`), golden 17s (`:14`), red 18-22s per T-0050. Intensity 1.0/1.5/2.0(/≈2.6 premium) at `fcm_style.dart:163-167`; sparks `60 * intensity` (`pack_opening_screen.dart:246`); rays and glow keyed on rarity accent (`:342,:352`).
- Two visible imbalances to audit (measured from the spec, to be confirmed against the running sim/screens by the implementer):
  1. **The golden tier is 2.1× the ordinary duration (17s vs 8s)** — after the red tier lands at 18-22s, golden and red sit nearly on top of each other in length; length alone stops communicating rarity. The golden timeline likely carries dead weight (stretched stages rather than added beats) and should tighten toward ~12-14s, letting red own the long-form slot.
  2. **Epic rides the ordinary timeline** (`pack_opening_screen.dart:164`) with only intensity 1.5 vs 1.0 separating it from rare — acceptable, but the audit must verify the epic pull still feels above rare inside the shared timeline (beat density, glow ramp), since three of the four card classes now share two of the three timelines.
- Method constraint: animation "feel" is not CI-verifiable — the deliverable is a **documented escalation matrix** (per tier: duration, intensity, spark budget, charge/ray behaviour, number of distinct beats) plus machine-checked bands; the human eye test happens in review.

## Requirements
1. Produce the escalation matrix and record it in Developer Notes; every row (ordinary/golden/red) must be strictly increasing on duration, intensity, spark budget and beat count, with **no tier more than ~1.8× the previous one in duration** (keeps the ladder perceptible: 8s → ~12-14s → 18-22s rather than 8 → 17 → 22).
2. Implement the golden-timeline tightening per the matrix (stage durations in `pack_reveal_timeline.dart`), preserving all existing golden beats — tighten pacing, do not delete content; the golden reveal must not get shorter than 12s.
3. Verify the epic-within-ordinary experience: if the audit finds epic indistinguishable from rare in-motion, raise epic's effective intensity toward the top of its band (≤ 1.5 stays, spacing within the shared timeline may adjust) — no new timeline for epic.
4. Re-run the full pack suites: the timeline-selection tests, the particle-budget prints and the T-0049/T-0050 tests must all stay green; ordinary pulls must not get **longer** than 8s (the common case must stay snappy).
5. Determinism: all timelines stay seed-driven; `tool/simulation_report_test.dart` PASS unchanged.

## Out of Scope
- Timeline selection logic (T-0050), the red card identity (T-0049), pack kinds/colours, the OVR curve and rarity thresholds (T-0046/T-0047).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Duration bands asserted by test: ordinary ≤ 8s, golden 12-14s, red 18-22s; intensity ladder strictly increasing with red ≤ 3.0
- [ ] Full `flutter test` suite passes; reveal suites green with only the timing assertions updated
- [ ] EN/AR localization complete and RTL verified where applicable (no new strings expected)
- [ ] No performance or application-size regression; worst-case spark budget printed and bounded
- [ ] Escalation matrix documented in Developer Notes with the before/after table

## How to Verify
```bash
flutter analyze
flutter test test/features/packs/
flutter test tool/simulation_report_test.dart
flutter test
```
Expected: analyzer clean; pack suites green; determinism PASS; the tests print the final ladder (durations, intensities, spark budgets) and pass the bands above.

## Side-effect risk (low-medium)
Pacing changes touch the timeline spec the existing golden tests lock — their timing assertions may need updating in step with the matrix (deliberate, named edits, as in T-0046). The red timeline's band may shift ±2s if the tightened golden tier compresses the perceived gap; keep the red band from T-0050 unless Developer Notes justify otherwise.

## Developer Notes

**Summary** — The reveal escalation ladder is rebalanced: the golden timeline tightened 17s → **13s** (one production constant, `kLegendaryRevealDuration`), every golden beat kept at unchanged fractions — mystery, finale, banner, the 16-mark haptic pattern, the full walkout — so the pacing tightened and nothing was deleted; the red timeline owns the long-form slot unchallenged. Ordinary stays 8s (the common case stays snappy); the red band stays T-0050's 20s.

**Escalation matrix (before → after)** — the printed ladder:
`ordinary 8.0s ×1.0 (sparks 60–90) → golden 13.0s ×2.0 (sparks 120) → red 20.0s ×2.6 (sparks 156, double finale)`

| Axis | ordinary (rare/epic) | golden (legendary 80-89) | red (premium 90+) |
|---|---|---|---|
| Duration | 8s → **8s** (unchanged) | 17s → **13s** | 20s → **20s** (unchanged) |
| Ratio to previous tier | — | 2.13× → **1.63×** ✓ ≤1.8 | 1.18× → **1.54×** ✓ ≤1.8 |
| Intensity | 1.0 (epic 1.5) → unchanged | 2.0 → unchanged | 2.6 → unchanged (≤3.0 ✓) |
| Main sparks (60 × intensity) | 60 / 90 | 120 → unchanged | 156 → unchanged |
| Haptic marks (heavy+medium+tick) | 6 → unchanged | 16 → unchanged | 18 → unchanged |
| Distinct stagecraft beats | 9 → unchanged | 12 → unchanged | 13 → unchanged |

Every axis strictly increasing; every duration step inside the ~1.8× perceptibility rule; test-locked in the new `escalation ladder (T-0051)` group.

**Epic audit verdict (Req 3)** — epic shares the ordinary timeline with only the intensity mechanisms separating it from rare (90 vs 60 main sparks, hotter glow/rays keyed on the rarity accent at `pack_opening_screen.dart:342,:352`) — that separation is real in motion (light density, not beat structure) and 1.5 is already the TOP of epic's band, so no change: raising further is out of scope and a new timeline is forbidden. Locked by test (epic > rare, epic < legendary).

**Files changed** — `lib/features/packs/pack_reveal_timeline.dart` (kLegendaryRevealDuration 17000→13000 + doc); `test/features/packs/pack_reveal_timeline_test.dart` (golden duration lock updated; new escalation-ladder group: bands, ratios, intensity/spark/beat monotonicity, epic audit); `test/features/packs/pack_opening_screen_test.dart` (named timing edits: the >2× assertion became >1× (1.625× is the new shape), and every golden pump re-derived at the SAME timeline fraction: 6100/4300/1500/1600/3700/1550ms — the walkout, flip-spoiler, name-redaction, banner and done assertions all hold their original semantics); `test/features/packs/packs_screen_test.dart` (comment).

**How tested it** — `flutter analyze`: No issues found. `flutter test test/features/packs/`: **71 passed** including the ladder prints and both re-derived golden widget walks. `flutter test`: **798 passed** (2 more than T-0058's 796). `flutter test tool/simulation_report_test.dart`: PASS — determinism holds (timelines are pure constants; no RNG touched).

**Concerns** — (1) The golden 13s master shortens every golden absolute cue (name lands at 11.6s instead of 15.1s) — the fraction-level pacing is untouched, but the human eye test in review should confirm the golden reveal doesn't feel RUSHED (its mystery→finale span compressed from 16.1s to 12.3s of wall time). If it does, 14s is the in-band fallback (ratio 1.75, still ≤1.8). (2) The red-vs-golden gap widened 1.18× → 1.54× — deliberate (length regains its signalling role); if the red now feels like a different LEAGUE of reveal rather than a notch above golden, that is the intended T-0051 shape and T-0050's band stays as shipped.

## Review Log
