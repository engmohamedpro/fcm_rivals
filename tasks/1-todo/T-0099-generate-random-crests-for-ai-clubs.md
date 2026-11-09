---
id: T-0099
title: Generate random crests for the AI clubs
priority: medium
status: todo
attempts: 0
depends_on: [T-0097]
created: 2026-11-09
completed:
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
- [ ] Same seed generates the exact same crest list (determinism preserved); no unseeded random is introduced.
- [ ] No two AI clubs in one league share an identical spec; every spec is valid (distinct palette indexes, in range).
- [ ] Generated clubs persist and read back with their spec through the store; `crestIndex` equals the primary index.
- [ ] The old `nextInt(8)` out-of-range assignment is gone.
- [ ] `flutter analyze` zero warnings; season suite green with the new tests; full `flutter test` green, no REGEN_SNAPSHOT.

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

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
