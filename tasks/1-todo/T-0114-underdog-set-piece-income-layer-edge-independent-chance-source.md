---
id: T-0114
title: Underdog set-piece income layer — edge-independent chance source (the T-0082 unblocking mechanism)
priority: high
status: todo
attempts: 0
depends_on: [T-0073]
created: 2026-11-10
completed:
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
- [ ] Default config: bit-identical seeded output (probe + snapshot green, REGEN_SNAPSHOT unset).
- [ ] Layer on: even-strength bands hold at n≥600; the underdog-goal lift and direction assertions pass at +50%.
- [ ] Zero existing-test edits; `flutter analyze` clean; full balance suite green.

## How to Verify
```bash
flutter analyze
flutter test test/balance/            # all green, zero edits
flutter test test/features/match/     # snapshot green, unset REGEN_SNAPSHOT
```

---

## Developer Notes

## Review Log
