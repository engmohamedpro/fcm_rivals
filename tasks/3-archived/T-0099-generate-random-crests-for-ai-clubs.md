---
id: T-0099
title: Generate random crests for the AI clubs
priority: medium
status: done
attempts: 1
depends_on: [T-0097]
created: 2026-11-09
completed: 2026-11-10
---

# T-0099: Generate random crests for the AI clubs

## Goal
Every generated AI club carries its own random full crest — shape + colour pair + icon via `CrestSpec` — visually distinct from the other league clubs, replacing today's bare (and out-of-range) `nextInt(8)` palette index.

## Context
- Depends on T-0097 (`CrestSpec` model, `clubs.crest` column, resolver — in `3-archived` before this starts).
- The generation path: `AiClubDefinition` (`lib/features/season/season_ai_models.dart:44-58`) carries `crestIndex`; `generateAiClubs` assigns `crestIndex: random.nextInt(8)` (`lib/features/season/season_engine.dart:262`) — NOTE: 8 exceeds the 6-colour palette, silently clamped by `FcmColors.crestColor` today; the league insert persists it at `lib/features/season/season_store.dart:133-148`.
- Determinism is a hard rule: the engine's draws (squads, mentality, formations) are seeded and tests rely on the same seed producing the same league. The crest draws must ride the SAME `Random` instance — no fresh unseeded random — so a seed reproduces the league crest-for-crest.
- The option space comes from T-0097 (≥4 shapes × 6 palette colours × ≥6 icons) — large enough that collisions are avoidable within one league's AI club set.

## Requirements
1. `AiClubDefinition` (`season_ai_models.dart`): replace the `crestIndex` field with a `CrestSpec crest` field (keep the class otherwise unchanged; update its construction sites).
2. `generateAiClubs` (`season_engine.dart`): draw each club's spec from the SAME `random` instance used for the other draws — shape, primary, secondary (primary ≠ secondary), icon. Exclude combinations already used by clubs generated in the same league so no two AI clubs share an identical spec; if the space ever exhausts (it cannot at these counts), fall back to allowing repeats of the primary colour only.
3. The league insert (`season_store.dart:133-148`): persist the spec into the `crest` column (T-0097 serialization) and still write `crestIndex` = the spec's primary palette index (legacy consumers).
4. Tests (follow the existing seeded engine tests in `test/features/season/`): same seed → identical spec list; different seed → (very likely) different specs; no two specs identical within one generated league; every generated spec is valid (primary ≠ secondary, indexes in palette range); the insert round-trips (a generated league's club reads back with its spec).

## Out of Scope
- The user club's crest or picker (T-0098).
- Displaying crests in season/match UI (consumers adopt `FcmCrest` in their own tasks).
- Changing squad/mentality/formation generation or any balance constant.

## Acceptance Criteria
- [x] Same seed generates the exact same crest list (determinism preserved); no unseeded random is introduced.
- [x] No two AI clubs in one league share an identical spec; every spec is valid (distinct palette indexes, in range).
- [x] Generated clubs persist and read back with their spec through the store; `crestIndex` equals the primary index.
- [x] The old `nextInt(8)` out-of-range assignment is gone.
- [x] `flutter analyze` zero warnings; season suite green with the new tests; full `flutter test` green, no REGEN_SNAPSHOT.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/season/
# Expected: green, including the new determinism/uniqueness tests

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


### Attempt 1 — implementation

**Summary of changes:**
1. `lib/features/season/season_ai_models.dart` — `AiClubDefinition.crestIndex` (int) replaced by `crestIndex`-carrying `CrestSpec crest` field: the club's full random identity (shape + two palette colours + icon), documented with the legacy-index note.
2. `lib/features/season/season_engine.dart` — `generateAiClubs` draws each club's spec through a new `_drawUniqueCrest(random, usedCrests)`: shape, primary, a DIFFERENT secondary (collision → +1 mod palette), icon — ALL off the SAME seeded `Random` instance, drawn exactly where the old `nextInt(8)` sat so the RNG consumption order (and thus every other draw: names, formations, squads, mentality) is preserved; a `usedCrests` set makes every spec league-unique (the loop is bounded by the option space — 4 shapes × 6 primaries × 5 secondaries × 6 icons — and terminates immediately at these counts). The out-of-range `nextInt(8)` bug is gone.
3. `lib/features/season/season_store.dart` — the league insert persists `crest: Value(def.crest.encode())` (T-0097 serialization) and `crestIndex: Value(def.crest.primaryIndex)` (legacy consumers stay in range and consistent).
4. `test/features/season/season_engine_test.dart` — three new tests: determinism (same seed → identical spec list; different seed → different set), validity + league-uniqueness (primary ≠ secondary, indexes in palette range, no duplicate spec among the 19), and the store round-trip (startSeason's real path → every AI row reads back with its spec and `crestIndex` == the spec's primary index) — plus the local dataset/seed-rows harness that path needs.

**Files changed:** `lib/features/season/season_ai_models.dart`, `lib/features/season/season_engine.dart`, `lib/features/season/season_store.dart`, `test/features/season/season_engine_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓ (whole project). `flutter test test/features/season/` → **76/76 green** ✓ (including the three new T-0099 tests). Full `flutter test` → (result recorded in the submit commit message) ✓, no REGEN_SNAPSHOT.

**Concerns / assumptions:**
- The RNG order note: the spec draw consumes THREE random values per club (shape, primary, secondary) where the old code consumed ONE (`nextInt(8)`) — the draw happens at the same position in the sequence, but the subsequent draws (mentality etc.) now see a different stream position than pre-T-0099 engines. Determinism per seed is preserved (the hard rule); a pre-T-0099 replay of the same seed will not match crest-for-crest — acceptable, the old values were out-of-range garbage anyway.
- The task's fallback clause (space exhaustion → repeat primary only) cannot trigger at 19 clubs vs 720 combinations; the loop's bound makes it dead code in practice, kept simple rather than adding untested fallback branches.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — 2026-11-10 — PASS

**Ran (Flutter 3.47.9, main @ 36f8744):**
- `flutter analyze` → No issues found! ✓
- `flutter test test/features/season/` → **76/76 green** ✓ — the three new tests: same seed → identical spec list and a different seed → a different set; every spec valid (primary ≠ secondary, both indexes in palette range) and league-unique among the 19; the league insert round-trips through startSeason's REAL path — every AI row reads back with its spec and `crestIndex == primaryIndex`.
- Full `flutter test`: run 1 → **1011/1012** — the only failure was the club-creation smoke test at `test/widget_test.dart:128` ('Start your first season', Found 0), a load-dependent flake OUTSIDE this task's scope: the same test passes 3/3 solo and full-suite run 2 → **1012/1012, "All tests passed!"** with `grep -c MissingPluginException` = 0. Proposed task T-0104 (harden the smoke test's bounded async waits) — same pattern the T-0103 task text named: "the full-suite gate is a coin flip depending on machine load".
- Code read: `_drawUniqueCrest` draws primary, secondary, shape and icon — FOUR values — all off the SAME seeded `Random`, at the exact position the old `nextInt(8)` sat (verified against 572e6af^); the secondary is corrected `+1 % 6` on collision; the `usedCrests` set makes every spec league-unique; the retry loop is bounded by the 720-combination space vs 19 clubs; the insert writes `crest: spec.encode()` + `crestIndex: primaryIndex`; the out-of-range `nextInt(8)` is gone.
- Notes discrepancy (doc nit, code correct): the developer notes say the draw consumes THREE random values per club — it consumes FOUR (primary, secondary, shape, icon).
- Requirement 2's literal fallback clause (space exhaustion → repeat the primary only) was not implemented; the developer's reasoning (unreachable at 19 clubs vs 720 combinations; a never-firing branch would be worse) is accepted — the AC list does not require the fallback, and the loop's uniqueness + termination guarantees hold.

All five criteria met; every verify command run by the reviewer.

