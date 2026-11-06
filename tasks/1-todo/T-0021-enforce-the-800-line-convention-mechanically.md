---
id: T-0021
title: Enforce the ~800-line convention mechanically
priority: medium
status: todo
attempts: 1
depends_on: [T-0025, T-0026, T-0027, T-0030, T-0028, T-0022, T-0024, T-0029, T-0023, T-0039, T-0040, T-0041, T-0042, T-0043, T-0044, T-0045]
created: 2026-11-05
completed:
# migrated from: reviews/tasks/2026-11-05_app-structure_enforce-line-budget.md
---

# T-0021: Enforce the ~800-line convention mechanically

## Goal
Make the README's ~800-line convention mechanically checkable: after the nine splits land and are archived, the over-800-lines check returns only documented exceptions and the README architecture table matches the tree.

## Context
The closing gate of the ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). After the nine file splits land, this task makes the README's ~800-line convention (README.md:72-74) mechanically checkable instead of aspirational.

## Investigation & Evidence
- Investigation: the nine oversized files (match engine, match screen, pack opening screen, season store, player card, collection store, live match views, pre-match screen, match report) each have their own follow-up file; on 2026-11-05 all nine still measure above 800 lines.
- Root cause / technical justification: a line-count convention with no mechanical check regresses silently; the check must be a one-liner anyone can run.
- Affected files/components: `lib/` tree; `README.md` architecture table
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` currently lists all nine files on main.
- Expected benefit / necessity: measurable target — the check returns only consciously-cleared exceptions (none expected) after the nine splits.
- Dependencies / side effects: depends on all nine split follow-ups completing first; no runtime behaviour.

## Requirements
- [ ] Enforce the convention mechanically | Where: `lib/` tree | Expected: after the nine splits, `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` returns only consciously-cleared exceptions (none expected); README architecture table gains a row per new top-level module family; `flutter analyze` clean; full suite green.

## Out of Scope
- Splitting the six files listed as uncovered by the 2026-11-06 amendment (tactics.dart, pack_effects.dart, packs_screen.dart, squad_view.dart, season_engine.dart, season_screen.dart): each needs its own investigated task file first, per README §4 of the old board.
- Lowering any band or threshold to make the check pass.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] The `wc -l` check returns only consciously-cleared exceptions (none expected)
- [ ] `README.md` architecture table matches the post-split tree

## How to Verify
```bash
find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'
flutter analyze
flutter test
```
Expected: the `find`/`wc` check lists only consciously-cleared exceptions (none expected); README architecture table matches the tree; analyzer clean; full suite green.

---

## Developer Notes
- **Summary of changes:** No code changes. Picked T-0021 per the board rules (all nine `depends_on` splits T-0022..T-0030 are in `tasks/3-archived/`; T-0002 was skipped because it depends on this task). Re-ran the enforcement check on current main (`7c4846c`) and the gate still lists seven files over 800 lines with no documented exceptions, so the task was blocked instead of expanding scope.
- **Files changed:** `tasks/1-todo/T-0021-enforce-the-800-line-convention-mechanically.md` (front matter + this section only)
- **How I tested it:**
  - Dependencies: T-0022, T-0023, T-0024, T-0025, T-0026, T-0027, T-0028, T-0029, T-0030 all confirmed present in `tasks/3-archived/`.
  - `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` on HEAD `7c4846c` returns 7 files: `lib/features/match/tactics.dart` 1201, `lib/features/packs/pack_effects.dart` 980, `lib/features/packs/packs_screen.dart` 901, `lib/features/squad/squad_view.dart` 890, `lib/features/collection/collection_store.dart` 854, `lib/features/season/season_engine.dart` 846, `lib/features/season/season_screen.dart` 803.
  - Header scan of all seven files: none documents a line-budget exception in its library doc.
  - `flutter`/`dart` are not available in this environment, so `flutter analyze` and `flutter test` could not be run here.
- **Concerns / assumptions:** BLOCKED — the acceptance criterion "the `wc -l` check returns only consciously-cleared exceptions (none expected)" cannot be met on main today:
  1. Six of the seven files (tactics.dart, pack_effects.dart, packs_screen.dart, squad_view.dart, season_engine.dart, season_screen.dart) are uncovered by any task file, and splitting them is explicitly Out of Scope here; per the 2026-11-06 review log each needs its own §1-compliant task file created after §4 investigation before work starts. I did not create those task files: the developer-agent hard rules restrict me to the picked task file and to doing exactly what the Requirements say.
  2. The tactics.dart sequencing precondition in the review log (wait for the fatigue-decoupling chain) is now satisfied — T-0037 and T-0038 are archived — so its split task file can be created immediately.
  3. `collection_store.dart` (854) was consciously cleared at a ≤900 budget by archived T-0034, but it exceeds the 800 convention and has no documented exception in its library doc; the board must either bless it as a documented exception or task another split.
  4. Fresh evidence vs the 2026-11-06 review log: of the twelve files it measured on `d0fbb88`, five are now under 800 on main (pre_match_screen, live_match_views, match_report, season_store, pack_opening_screen) — only collection_store remains above 800 among the covered files.
  What I need: six §1-compliant split task files created and completed (or an explicit board decision to record documented exceptions), plus a decision on collection_store's 854, before this gate can pass. `flutter analyze` / `flutter test` must be run where the Flutter toolchain exists.

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0021` (was `reviews/tasks/2026-11-05_app-structure_enforce-line-budget.md`, status OPEN).

- 2026-11-06 (reviewer, evidence refresh): the task premise "none expected" is no longer the measured truth — `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` on `d0fbb88` lists TWELVE files: three with open task files (pre_match_screen 1,187, live_match_views 853, match_report 1,026 — `2026-11-05_app-structure_split-pre-match-screen`, `split-live-match-views`, `split-commentary`), three with SPLIT correction follow-ups (season_store 1,167, collection_store 1,049, pack_opening_screen 892 — the `2026-11-06_app-structure_finish-*` files), and SIX uncovered by any task file (tactics.dart 1,110, pack_effects.dart 980, packs_screen.dart 901, squad_view.dart 890, season_engine.dart 846, season_screen.dart 803). Each uncovered file needs its own §1-compliant task file created after §4 investigation before work starts; note `tactics.dart` is also the subject of the pending balance chain (`2026-11-06_match-engine_fatigue-decoupling`) — sequence its split after that lands or coordinate explicitly. The enforcement criterion itself is unchanged; it simply cannot pass until the above is resolved.

### 2026-11-06 — reviewer/board pass: unblock via explicit task chain
- Responding to the developer block (attempt 1, commit `b2c0a27`): the blocker was that six over-800 files had no task files and `collection_store.dart` had no decision — both outside the developer's remit.
- Planner pass (delegated by the repo owner per HOW_TO_WRITE_TASKS.md): created seven §-compliant split tasks measured on `b2c0a27` — T-0039 (tactics.dart 1201 → five families + barrel), T-0040 (pack_effects.dart 980 → palette/foil/particles + barrel), T-0041 (packs_screen.dart 901 → shell/grid/price), T-0042 (squad_view.dart 890 → setup/pitch + barrel), T-0043 (season_engine.dart 846 → AI models out), T-0044 (season_screen.dart 803 → pre-match route out), T-0045 (collection_store.dart 854 → finish below 800 via the T-0034 part-file pattern).
- Decision on collection_store (854): split below 800 via T-0045, following the T-0035/T-0036 precedent, instead of blessing a documented exception — keeps this gate's "none expected" premise intact.
- depends_on extended with T-0039..T-0045 so sequencing is mechanical (the developer skips this task via the dependency rule until all seven archive); status back to `todo` — the missing-task-files blocker no longer exists.
- tactics.dart sequencing precondition from the evidence refresh is satisfied (T-0037/T-0038 archived).
- Goal, Requirements, Acceptance Criteria and How to Verify unchanged.

## Historical Links
- Depends on: `2026-11-05_app-structure_split-match-engine`, `2026-11-05_app-structure_split-match-screen-report`, `2026-11-05_app-structure_split-pack-reveal-widgets`, `2026-11-05_app-structure_split-season-models`, `2026-11-05_app-structure_split-player-card`, `2026-11-05_app-structure_split-collection-results-catalog`, `2026-11-05_app-structure_split-live-match-views`, `2026-11-05_app-structure_split-pre-match-screen`, `2026-11-05_app-structure_split-commentary`
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None
