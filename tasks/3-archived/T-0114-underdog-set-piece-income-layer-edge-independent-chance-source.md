---
id: T-0114
title: Underdog set-piece income layer — edge-independent chance source (the T-0082 unblocking mechanism)
priority: high
status: done
attempts: 1
depends_on: [T-0073]
created: 2026-11-10
completed: 2026-11-11
---

# T-0114: Underdog set-piece income layer — edge-independent chance source

## Goal
A small chance-income stream for the side OUT of possession that is INDEPENDENT of the attack-minus-defence edge — the mechanism the T-0082 blocked attempt measured as the missing piece (the underdog at +50% is pinned at the 0.05 clamp floor on ~30% of pockets, scoring 0.33 goals/match; the favourite cannot lose 12% of matches without it). It ships OFF by default: config 0 → bit-identical engine output, the snapshot untouched, every existing band green untouched.

## Context
- T-0082's decision record (2026-11-10): the two-direction ≤0.88 ceiling is unreachable within the current mechanism set because the underdog's chance rate collapses with the edge. This layer is the fix — but it must land observable-neutral FIRST so any regression surfaces at the slice that caused it.
- Where it scales from: TERRITORY, not strength — the possession-pocket share already computed each minute from the support-ratio (`homePoss / (homePoss + awayPoss)` in `match_engine_simulation.dart`, the 1.4-exponent support ratio). A side out of possession but holding territory share earns set-piece pressure (corners, long throws, penalty-box pinball); a side that has lost the territory battle earns nothing extra. This is deliberately the OPPOSITE coupling to the attack-minus-defence edge: a +50% favourite compresses the underdog's EDGE but cannot fully compress its territory share (the 1.4 exponent + the minnow-touches-ball design keep the dominated side's possession share well above zero — measured shots at +50%: 4.8–5.6 for the underdog, i.e. the territory floor already exists in the shot counts).
- Real-football grounding: set pieces contribute a roughly stable share of goals (~25–30%) across strength mismatches; a corner is a corner whether the taker is OVR 70 or OVR 105. That stability is exactly the underdog-income property the engine lacks.

## Requirements
1. `lib/features/match/match_event.dart` — new config: `setPieceIncome` (default **0.0** → the layer contributes nothing; every existing default, band and the seeded snapshot unchanged). Follow the file's documented config-comment style: what it is, why it is off, what turning it on is for.
2. `lib/features/match/match_engine_simulation.dart` — the layer itself, in the per-minute attacker-selection phase: with probability `setPieceIncome * (territoryShareOfDefendingSide)`, the DEFENDING side (the side out of possession this minute) gets one low-quality set-piece chance (`ChanceQuality.normal` or a new `setPiece` quality if the quality enum has room — pick what the conversion layer reads most honestly) instead of the possession pocket proceeding as it would. One roll per minute, no stacking with Fast Counter, deterministic stream order preserved (one extra `_random.chance` draw ONLY when the layer is non-zero — at default 0 the draw must be SKIPPED, not drawn-and-ignored, so seeded output stays bit-identical; guard the call behind `config.setPieceIncome > 0`).
3. The quality/conversion wiring: the set-piece chance enters the existing `_shoot` pipeline with the defending side as the shooter — no new event types unless `MatchEventType` already has a set-piece-ish member (check `cross`/`corner` metadata conventions in the pass-move path; reuse what exists, do not invent a new persistence shape).
4. `test/balance/set_piece_income_test.dart` — the probe harness (NEW file, its OWN bands — zero edits to any existing test):
   - **Bit-identical guard:** default config → the seeded match output is identical to pre-layer output for a battery of seeds (the snapshot test already proves this for the battery it covers; here assert at least 3 seeds' full scorelines + shot counts unchanged).
   - **Even-strength neutrality (layer on, `setPieceIncome` at the value T-0116 will use):** home/away win/draw rates and combined goals stay inside the even-strength bands' spirit (win 0.42–0.52, draw 0.22–0.32, goals 1.4–5.2) at n≥600 — the layer must not tilt even matches.
   - **The underdog lift (layer on):** B+50% sweep — the underdog's (A's) goals/match rises from the baseline ~0.33 toward ≥0.7 while the favourite's goals move by ≤0.3 (the favourite's income is untouched by construction; the assertion catches accidental coupling). Win rates WILL move in this test — that is the point — so assert only the DIRECTION (B's win rate at +50% is LOWER with the layer than the baseline 0.957 at matched seeds, n≥300) plus the goal assertions; the numeric lock is T-0116's job, not this slice's.
5. `flutter analyze` zero new warnings; the FULL existing balance suite green with zero edits (`git diff` shows only the new test file).

## Out of Scope
- Turning the layer on in production defaults (T-0116).
- The normalized edge / sigmoid re-anchor (T-0115 — do not touch the edge math here).
- Any band edit anywhere; the T-0073 violation lock stays as-is.
- Economy, pack odds, UI, l10n, save format.

## Acceptance Criteria
- [x] Default config: bit-identical seeded output (probe + snapshot green, REGEN_SNAPSHOT unset).
- [x] Layer on: even-strength bands hold at n≥600; the underdog-goal lift and direction assertions pass at +50%.
- [x] Zero existing-test edits; `flutter analyze` clean; full balance suite green.

## How to Verify
```bash
flutter analyze
flutter test test/balance/            # all green, zero edits
flutter test test/features/match/     # snapshot green, unset REGEN_SNAPSHOT
```

---

## Developer Notes

- **Summary of changes:**
  - `lib/features/match/match_event.dart` — the `setPieceIncome`
    config (default **0.0**, OFF): the constructor comment documents
    what it is, why it is off, and what turning it on is for
    (T-0116's ceiling lock). At 0.0 the random-stream draw is
    SKIPPED, not drawn-and-ignored — seeded output is
    bit-identical.
  - `lib/features/match/match_engine_simulation.dart` — the layer:
    right after the minute's attacker selection, the side OUT of
    possession earns one set-piece chance with probability
    `setPieceIncome × (its support-power territory share)` — the
    SAME 1.4-exponent share that picked the attacker. Territory-
    coupled and edge-independent BY CONSTRUCTION. The chance is a
    DIRECT normal-quality shot through the existing `_shoot`
    pipeline for the out side; the minute's open-play pocket is
    consumed by it (one chance per minute, no stacking).
  - **Measured course-correction within the spec's own latitude**
    ("pick what the conversion layer reads most honestly"): the
    first carrier — the corner flow (`_corner(headerChance: true)`)
    — delivered only +0.05 underdog goals at neutrality-breaking
    income levels (the header conversion + the claimed ~1-in-3
    rotation suppress conversion), while the direct normal-quality
    chance converts ~3× per event, so the same lift needs ~1/3 the
    rate and even-strength neutrality holds. The sweep table that
    forced the switch is below.
  - `test/balance/set_piece_income_test.dart` (NEW, 4 tests, its
    OWN bands — zero edits to any existing test): the bit-identical
    guard (3 seeds' full scorelines + shot counts locked to the
    pre-layer battery), even-strength neutrality (win/draw/goals
    bands + the home-away goal gap staying in home advantage's own
    neighbourhood — the DELTA formulation, not the raw gap, which
    is home advantage itself), the underdog lift (matched seeds
    on/off at B+50%: goals 0.43 → 0.63, favourite move ≤0.3, win
    rate drops, combined <5.2), and the +25% no-overshoot guard.
- **Files changed:** lib/features/match/match_event.dart (+knob),
  lib/features/match/match_engine_simulation.dart (+layer),
  test/balance/set_piece_income_test.dart (new).
- **How I tested it:** `flutter analyze --no-pub` — zero new
  issues. The new gate 4/4. **The FULL balance suite 106/106 green
  with ZERO edits to any existing test** (the T-0073 violation lock
  included — untouched and green, as required). The match suite:
  252 passing with ONLY the 2 pre-existing tactic_slider_row
  failures (documented in earlier sessions' notes; unrelated to the
  engine — a UI slider test); the engine snapshot test GREEN with
  REGEN_SNAPSHOT unset (the default-off path is bit-identical, as
  designed).
- **The value sweep table (n=300/cell, matched seeds, the
  direct-chance carrier):**
  - spi 0.00: even g 2.54 | B+50: uW 0.957, uG 0.433, fG 4.357,
    comb 4.79
  - spi 0.04: even g 2.97 | B+50: uW 0.920, uG 0.523, fG 4.170,
    comb 4.69
  - spi 0.05: even g 2.91 | B+50: uW 0.927, uG 0.533, fG 4.273,
    comb 4.81
  - spi 0.075: even g 2.91 | B+50: uW 0.937, uG 0.567, fG 4.330,
    comb 4.90
  - spi 0.10: even g 3.02 | B+50: uW 0.933, uG 0.633, fG 4.443,
    comb 5.08 ← **the shipped probe value**
  - spi 0.13: even g 3.13 | B+50: uW 0.940, uG 0.703, fG 4.553,
    comb 5.26 (ceiling broken — rejected)
- **Concerns / assumptions:** (1) The direct carrier pays BOTH
  sides' defending shares (direction-symmetric income): the
  favourite gains some goals too (4.36 → 4.44 at 0.10) — the
  underdog's RELATIVE position improves (uG/fG 0.10 → 0.14) and the
  favourite's win rate drops 0.957 → 0.933, but the layer alone
  does NOT reach the 0.88 ceiling (0.933 at +50%). That was NEVER
  this slice's job: T-0115's de-saturated edge is the other half
  (the attempt's table: ~0.05–0.07 underdog goals of additional
  lift) and T-0116 owns the lock. (2) The underdog-lift assertion
  (>0.6, measured 0.63) is deliberately the honest number — 0.70
  required the 0.13 rate that breaks the combined-goals ceiling.
  (3) kProbeIncome (0.10) is a TEST constant; the production
  default stays 0.0 until T-0116 turns it on — the snapshot proves
  the inert path every run.

## Review Log
