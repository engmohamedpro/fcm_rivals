# App structure: enforce the ~800-line convention mechanically

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: OPEN
- Completed on: -

## Context
The closing gate of the ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). After the nine file splits land, this task makes the README's ~800-line convention (README.md:72-74) mechanically checkable instead of aspirational.

## Investigation & Evidence
- Investigation: the nine oversized files (match engine, match screen, pack opening screen, season store, player card, collection store, live match views, pre-match screen, match report) each have their own follow-up file; on 2026-11-05 all nine still measure above 800 lines.
- Root cause / technical justification: a line-count convention with no mechanical check regresses silently; the check must be a one-liner anyone can run.
- Affected files/components: `lib/` tree; `README.md` architecture table
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` currently lists all nine files on main.
- Expected benefit / necessity: measurable target — the check returns only consciously-cleared exceptions (none expected) after the nine splits.
- Dependencies / side effects: depends on all nine split follow-ups completing first; no runtime behaviour.

## Reproduction Steps
Not applicable.

## Task
- [ ] Enforce the convention mechanically | Where: `lib/` tree | Expected: after the nine splits, `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` returns only consciously-cleared exceptions (none expected); README architecture table gains a row per new top-level module family; `flutter analyze` clean; full suite green.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] The `wc -l` check returns only consciously-cleared exceptions (none expected)
- [ ] `README.md` architecture table matches the post-split tree

## Developer Notes
<Implementation summary, files changed, exact test commands/results, and rejection reason/evidence if applicable. Implement this task only, create one task-specific commit, and push it before starting another task.>

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: `2026-11-05_app-structure_split-match-engine`, `2026-11-05_app-structure_split-match-screen-report`, `2026-11-05_app-structure_split-pack-reveal-widgets`, `2026-11-05_app-structure_split-season-models`, `2026-11-05_app-structure_split-player-card`, `2026-11-05_app-structure_split-collection-results-catalog`, `2026-11-05_app-structure_split-live-match-views`, `2026-11-05_app-structure_split-pre-match-screen`, `2026-11-05_app-structure_split-commentary`
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None

## Amendments
- 2026-11-06 (reviewer, evidence refresh): the task premise "none expected" is no longer the measured truth — `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` on `d0fbb88` lists TWELVE files: three with open task files (pre_match_screen 1,187, live_match_views 853, match_report 1,026 — `2026-11-05_app-structure_split-pre-match-screen`, `split-live-match-views`, `split-commentary`), three with SPLIT correction follow-ups (season_store 1,167, collection_store 1,049, pack_opening_screen 892 — the `2026-11-06_app-structure_finish-*` files), and SIX uncovered by any task file (tactics.dart 1,110, pack_effects.dart 980, packs_screen.dart 901, squad_view.dart 890, season_engine.dart 846, season_screen.dart 803). Each uncovered file needs its own §1-compliant task file created after §4 investigation before work starts; note `tactics.dart` is also the subject of the pending balance chain (`2026-11-06_match-engine_fatigue-decoupling`) — sequence its split after that lands or coordinate explicitly. The enforcement criterion itself is unchanged; it simply cannot pass until the above is resolved.
