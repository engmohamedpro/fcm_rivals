---
id: T-0072
title: Scale AI squads past the dataset ceiling with upgrade levels
priority: high
status: needs-review
attempts: 2
depends_on: [T-0070]
created: 2026-11-09
completed:
---

# T-0072: Scale AI squads past the dataset ceiling with upgrade levels

## Goal
The division ladder never flattens: when a division's target overall exceeds what the player pool can supply, AI squads are lifted to the target with the same +N% upgrade math the user's cards use — so divisions stay harder forever (top players, then players with +).

## Context
- Owner spec (2026-11-09): "the divisions ladder up keeps being more difficult... teams get top players then teams get players with + so that it is infinite divisions". GDD 9.1 already declares "no predefined final division".
- Today the ladder stalls: `targetAverageOverall(division) = 54 + (division − 1) × 3` (`lib/features/season/season_engine.dart:73`, unbounded), but the real-player pool bands ±3 and widens until it can only take each position's best available (`_PoolTracker.take`), and the synthetic fallback clamps at `(target + spread).clamp(35, 94)` (`_generatePlayer`). Division 16 targets 99; beyond it every squad is just "the elite leftovers" and stops growing.
- The fix uses T-0070's shared `upgradedValue(base, level)` — AI players get the same percentage lift as user cards, keeping one progression curve for both sides.
- Persistence is unchanged: `loadOpponent` (`season_store_opponent.dart`) reads the four attribute columns from `aiPlayers`; effective (lifted) values are written there directly — no schema change, no upgrade-level column.
- Determinism: the lift derives from the already-seeded squad (same seed → same squad → same lift); no new RNG draws.

## Requirements
1. In `generateAiClubs` (`season_engine.dart:214-262`): after each club's squad is built (real or synthetic), compute the squad's average base overall; when it is below the division `target`, give the whole club a uniform upgrade level `N = ceil((target / avg − 1) × 100)` (0 when avg ≥ target, guard avg > 0) and set every player's four attributes to `upgradedValue(attr, N)`. Per-club N: clubs with weaker bases get a bigger lift, every club lands on the target — consistent with today's band-around-target intent.
2. `AiPlayerDefinition` (`lib/features/season/season_ai_models.dart`) may carry the club's `upgradeLevel` as an optional debug field (not persisted, no UI).
3. Low divisions are byte-identical to today: at `target ≤ achievable base` the lift is 0 and generation is untouched (division 1 stays 54-band).
4. Update GDD 9.6 (`docs/fcm_rivals_GDD_SRS.md` "Difficulty Scaling"): beyond the dataset ceiling, difficulty scales through AI upgrade levels using the shared player-upgrade math — dated owner decision 2026-11-09.
5. Tests (extend the season engine/generation tests): division 1 squads unchanged (zero drift — the existing seeded generation tests pass untouched); division 20 (target 111) — every generated club's average effective overall is ≥ target − 1 with attributes > 99 present; the synthetic fallback path also lifts (a 94-clamped squad reaches the target); same seed twice → identical squads and lifts; a thin/test dataset (no pool) still produces a full legal XI at high targets.

## Out of Scope
- Showing +N badges on opponent players (pre-match screens show ratings only today; a display task can follow if wanted).
- Changing the division target curve (stays 54 + 3×(division−1)) or promotion/relegation.
- Match-engine behavior with >99 values — measured in T-0073.
- Persisting AI upgrade levels or lifting already-persisted historical squads (only newly generated divisions lift; existing saves keep their squads as generated).

## Acceptance Criteria
- [x] At high divisions every AI club's average effective overall meets the division target (±1), via the shared `upgradedValue` helper — attributes above 99 flow into matches.
- [ ] Division 1 (and every division whose target the pool supplies) generates exactly today's squads — seeded generation tests and the engine snapshot pass with no `REGEN_SNAPSHOT`.
- [x] Generation stays deterministic per seed, works with no dataset (synthetic path), and never crashes on empty/deg pools.
- [x] GDD 9.6 documents the upgrade-level scaling with the dated owner decision.
- [x] `flutter analyze` zero warnings; `flutter test` full suite green.

## How to Verify
```bash
flutter analyze
flutter test test/features/season/                    # generation + lift tests green
flutter test test/features/match/engine_snapshot_test.dart   # zero drift, no REGEN
flutter test
dart run   # optional: headless season sim at division 20 -> opponents average ~111
```
Expected: analyze clean, suites green; high-division opponents carry lifted (>99) attributes and low divisions are unchanged.

---

## Developer Notes

### Attempt 2 (review fixes)

Both attempt-1 failures fixed; no production behavior beyond the intended lift changed, proven with the reviewer's own probe.

- **Fix 1 — RNG draw order (failure 1):** the parent had a HYBRID consumption order I broke by hoisting the squad into one local: the pool-path squad (`realSquad`) was drawn BEFORE the crest/mentality draws, while the synthetic fallback ran INSIDE the constructor's argument list AFTER them. Both are now reproduced verbatim — `realSquad` stays a local before `clubs.add(...)`, the synthetic fallback stays in the `players:` argument, and the lift wraps whichever squad that argument resolves to. The probe proves player names/ids are identical to 76319ef everywhere (div 1–16, seeds {5, 42, 77, 1234}, both paths); only lifted attributes differ, and only where the lift engages.
- **Fix 2 — structural gate (failure 2):** the dead zone is gone. The lift engages per DIVISION, not per club, judged from pristine capacity computed once before generation: synthetic path supplies while `target ≤ 94` (the `_generatePlayer` clamp — `_syntheticCeiling`); pool path supplies when every position has ANY player within ±3 of the target in the full (pre-consumption) pool (`_PoolTracker.pristinePoolSupplies`). Mid-generation band exhaustion is normal banding-widening for a 19-club division, NOT a ceiling — my first gate attempt (per-club `hasInBand` on the remaining pool) still lifted 5/19 div-1 clubs at seed 42 and was discarded. Variance shortfalls (the 1.6–3.0-point gaps the reviewer measured at div 1) never lift now.
- **Probe result (the reviewer's re-verification recipe, executed):** `git worktree` at 76319ef + `tool/review_lift_probe.dart` on both trees, lockstep-diffed: **div 1–14 byte-identical on BOTH paths (0 changed lines); div 15 lifts on the synthetic path only (target 96 > 94); div 16 lifts on both (target 99; the 94-capped pool has no in-band player for a 96–99 band — wait, ±3 of 99 includes 96..94? 99−3=96 > 94, so genuinely out of band).** Every changed line is a pure attribute lift of the SAME player (same name/id), never a different draw.
- **Tests:** `season_engine_test` → **31/31**: the div-1 zero-drift test is kept, plus two new review-fix locks — pool-path divisions {1,2,8,12,13,14} × seeds {5,42,77,1234} all level 0 (the reviewer's seed-42 counterexample now asserted), and synthetic divisions {1,7,14} × the same seeds all level 0. Div-20 tests unchanged and green (every club ≥ target−1 with >99 attributes; real-pool path lifts; same-seed determinism; thin/no-pool full XIs). Season suite → **66/66**. Engine snapshot → 1/1, `REGEN_SNAPSHOT` unset. `flutter analyze` → zero warnings. Full `flutter test` → **911/911 green** (includes the T-0069 injury-test viewport fix that landed in this same working tree).
- **Files changed (attempt 2):** `lib/features/season/season_engine.dart` (hybrid RNG order + structural gate + `_syntheticCeiling` + `pristinePoolSupplies`; dead `hasInBand` removed), `test/features/season/season_engine_test.dart` (+2 tests, comment updates), `tasks/…T-0072….md`.
- **Concerns:** (1) A division whose pool genuinely supplies the target via a WIDE band (e.g. div 15 pool: target 96, band 93–99 — 93/94 exist) does not lift even though the average may fall short; the wide-band draws are the parent's own banding behavior, preserved byte-identically as required. (2) The gate is division-level, so within a lifting division every club lifts (per-club variance no longer matters) — this matches the task's "every club lands on the target" intent and keeps determinism simple.

## Review Log

### Review 2026-11-09, attempt 1: FAIL
Ran: `flutter analyze` (clean), `flutter test test/features/season/` (64/64), `flutter test test/features/match/engine_snapshot_test.dart` (1/1, `REGEN_SNAPSHOT` unset), `flutter test` (893/893) — plus an independent cross-version byte-identity probe (`tool/review_lift_probe.dart`, committed with this review): `generateAiClubs` for divisions 1–16 × seeds {5, 42, 77, 1234} × both paths (no-pool synthetic and the tests' `buildPool` shape), dumped from this HEAD (af94ddd) and from the pre-lift parent (76319ef, via `git worktree`) and diffed. Both dumps are deterministic across repeated runs, so every difference below is a real behavior change.

**Failures:**

1. Criterion "Division 1 (and every division whose target the pool supplies) generates exactly today's squads" — FALSE on the synthetic path at every division, including division 1.
   - Evidence: parent vs HEAD at div 1, seed 5, first club `Pharaoh FC`: parent GK `SAMridra 0 47 49 67` vs HEAD GK `FARfasam 0 51 53 71` — every player, name and attributes, differs. 75/75 div-1 synthetic clubs differ across the four seeds (76/76 at div 2+).
   - Root cause: RNG draw-order flip. In the parent, `players: realSquad ?? _generateSquad(target, formation, random)` was a constructor argument evaluated AFTER `mentality: _pickMentality(random)` (argument-list order, season_engine.dart parent lines 253–256). HEAD hoists `final squad = realSquad ?? _generateSquad(...)` (season_engine.dart:247) ABOVE the constructor, so the shared `random` stream now feeds squad generation before the mentality draw. The synthetic path consumes that stream, so every club from the first onward draws differently.
   - The in-repo tests cannot see this: the div-1 test asserts `upgradeLevel == 0` and the near-target band (both still true), the "same seed twice" test compares two HEAD runs (same order → identical), and the engine snapshot covers the match engine, not season generation. Only a cross-version comparison exposes it.
   - Fix: preserve the parent's RNG consumption order — e.g. hoist `final mentality = _pickMentality(random);` to a local BEFORE `final squad = ...` and pass `mentality: mentality` in the constructor (or keep squad generation inside the argument list after `mentality:`). Then re-run the probe: synthetic div 1–16 must diff clean against 76319ef for all unlifted clubs.

2. Same criterion — FALSE on the pool path at low divisions: the 1.0-point dead zone does not cover the generation spread, so clubs at pool-supplied divisions get lifted.
   - Evidence: pool path div 1 (target 54) — seed 42: 3 clubs lifted, seed 77: 2 clubs (seeds 5 and 1234: none). Example (seed 42, `Al Legends`, `Pyramid Giants`): every attribute +2 (56→58, i.e. lift level ≈ 3–4, a true gap of ~1.6–2.1 points); another club's first player 52→55 (level ≈ 5–6, gap ≈ 2.5–3 points). The same 5/76 pattern repeats at div 2–8 and 6/76 at div 12.
   - The Developer Notes' assumption "the spread variance leaves clubs 0.3–0.7 under target" is empirically wrong: gaps of 1.6–3.0 points occur at division 1 itself. The div-1 test passed only because seed 5 happens to have no club ≥ 1.0 under target.
   - This violates Requirement 3 ("at target ≤ achievable base the lift is 0 and generation is untouched — division 1 stays 54-band") and the criterion's "exactly today's squads".
   - Fix direction (pick one, do NOT just widen the dead zone — a wide dead zone would also suppress the intended lifting at div 15/16 where the pool caps at 94 against targets 96/99): (a) make the lift pool-aware — engage only when the pool genuinely cannot supply the target (e.g. the tracker reports it widened past the natural band for this club, or the pool's best available at the needed positions is below the target band), so variance shortfalls at div 1–12 never lift while the div 13+ ceiling keeps lifting; or (b) an explicit owner decision amending Requirement 3 to accept small variance lifts at pool-supplied divisions — if the owner chooses this, update the task text, GDD 9.6 and the div-1 test (assert the lift band, not level 0) in the same change. As written today, the spec demands byte-identity and the code does not deliver it.

**Passed:** criteria 1 (div 20 every club > 110 with >99 attributes and level > 0; real-pool path also lifts), 3 (per-version determinism verified by running the probe twice per tree — identical; synthetic and 30-player degenerate pools produce full 18-man XIs), 4 (GDD 9.6 dated owner decision present), 5 (analyze clean, 893/893). No out-of-scope files changed (GDD + models + engine + tests only).

**How to re-verify after the fix:**
```bash
git worktree add ../wt-parent 640c6be^   # pre-lift parent (76319ef)
cp tool/review_lift_probe.dart ../wt-parent/tool/
(cd ../wt-parent && dart pub get && dart run tool/review_lift_probe.dart > parent.txt)
dart run tool/review_lift_probe.dart > head.txt
diff parent.txt head.txt   # div 1-12: identical; div 13+: only the intended lifts
flutter test test/features/season/ && flutter test
```

**What to do:** fix failure 1 (one-line ordering fix) and resolve failure 2 via (a) or an owner decision on (b), then resubmit.
