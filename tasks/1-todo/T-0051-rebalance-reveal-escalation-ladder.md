---
id: T-0051
title: Rebalance the reveal escalation ladder - ordinary, golden, red
priority: medium
status: todo
attempts: 0
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

## Review Log
