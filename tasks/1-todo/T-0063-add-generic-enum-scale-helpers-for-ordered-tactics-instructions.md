---
id: T-0063
title: Add generic enum-scale helpers for ordered tactics instructions
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-08
completed:
---

# T-0063: Add generic enum-scale helpers for ordered tactics instructions

## Goal
One tested pair of generic helpers converts any ordered instruction enum to and from its 0-100 scale position, ready for the slider UI (T-0064), with the mentality mapping behaviour unchanged.

## Context
- `mentalityFromScale` / `mentalityToScale` (`lib/features/match/team_tactics.dart`, lines 200-209) are mentality-specific: `round(value * (n - 1) / 100)` and `round(index * 100 / (n - 1))`.
- The nine ordered axes (GDD 10.2): `BuildUpStyle`, `AttackTempo`, `AttackWidth` (`lib/features/match/in_possession_tactics.dart`); `DefensiveLine`, `PressingIntensity`, `TacklingAggression` (`lib/features/match/out_of_possession_tactics.dart`); `CounterPress`, `AttackOnRecovery`, `RestDefence` (`lib/features/match/transition_tactics.dart`). Each has exactly 3 values with the default at the middle index, so every default maps to scale 50 — the slider's centre tick.
- `FinalThirdApproach` (4 categorical styles, not a spectrum) and the offside-trap bool are deliberately NOT ordered scales and must not be forced through these helpers.

## Requirements
1. Add generic helpers next to the mentality pair in `lib/features/match/team_tactics.dart`: `T enumFromScale<T extends Enum>(List<T> values, int value)` and `int enumToScale<T extends Enum>(List<T> values, T value)` — same round-half-up math, input clamped to 0-100.
2. Refactor `mentalityFromScale` / `mentalityToScale` to delegate to them so there is a single code path with identical behaviour.
3. Unit tests: round-trip every one of the nine enums (each value against each of its scale positions); every default lands at 50; out-of-range scales (-5, 105) clamp to the first / last value.

## Out of Scope
- Any UI change, new instruction steps or values, engine or balance changes.
- `FinalThirdApproach` and the offside trap.

## Acceptance Criteria
- [ ] The generic helpers exist with the exact math above; the mentality mapping is unchanged (existing mentality tests green, untouched).
- [ ] Round-trip tests cover all nine ordered enums and prove every default maps to 50.
- [ ] `flutter analyze` reports zero warnings; `flutter test test/features/match/` green.

## How to Verify
```bash
flutter analyze
flutter test test/features/match/
```
Expected: analyze clean; the match feature suite including the new helper tests is green.

---

## Developer Notes

## Review Log
