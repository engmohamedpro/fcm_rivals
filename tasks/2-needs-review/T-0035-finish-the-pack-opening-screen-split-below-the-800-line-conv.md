---
id: T-0035
title: Finish the pack-opening-screen split below the 800-line convention
priority: medium
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-06
completed:
# migrated from: reviews/tasks/2026-11-06_app-structure_finish-pack-reveal-split.md
---

# T-0035: Finish the pack-opening-screen split below the 800-line convention

## Goal
Finish the pack-opening-screen split so the screen is at most 800 lines via verbatim extraction of the five reveal-stage view builders into a part file.

## Context
Correction follow-up of `2026-11-05_app-structure_split-pack-reveal-widgets` (SPLIT 2026-11-06: the timeline/widgets extraction verified good, but its acceptance criterion "every resulting file ≤800 lines" is unmet — `pack_opening_screen.dart` still measures 892 lines). This task finishes the split to the README's ~800-line convention (README.md:72-74).

## Investigation & Evidence
- Investigation: the timeline spec (`pack_reveal_timeline.dart`, 161 lines) and the painters/chain widgets (`pack_opening_widgets.dart`, 246 lines) landed, shrinking the screen 1,272 → 892 (measured 2026-11-06; the developer's notes report 893 at the task commit) — still ~92 lines above the budget; the file now holds `PackChainInfo` (:61) plus the screen state class (:96) whose reveal/handoff UI families carry the bulk.
- Root cause / technical justification: the reveal-flow UI families (chain/handoff presentation, reveal orchestration) remain inside the screen state class; only method/widget-family extraction remains.
- Affected files/components: `lib/features/packs/pack_opening_screen.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main at d0fbb88.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: the proven pattern is the engine split's (`5447a67`): cohesive widget/method families moved verbatim into part files or helper libraries with the screen as the importing barrel; reveal animations must stay frame-identical; the pack opening/squad reveal suites are the regression net.

## Requirements
- [x] Extract cohesive pack-opening widget/method families below the 800-line budget | Where: `lib/features/packs/pack_opening_screen.dart` (892 lines on 2026-11-06) | Expected: `pack_opening_screen.dart` and every new file ≤800 lines; reveal animations frame-identical — pack opening/squad reveal suites green with zero test edits.

## Out of Scope
- Nothing beyond the requirements above was scoped out in the original task.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [ ] Reveal animations frame-identical; pack opening/squad reveal suites green with zero test edits

## How to Verify
Run the board's standard gates:

```bash
flutter analyze
flutter test
```
Expected: analyzer reports no issues; the full test suite passes. Per-task checks are quoted in Requirements and Developer Notes.

---

## Developer Notes
Implemented 2026-11-06. Followed the endorsed engine-split pattern (`5447a67`): the five reveal-stage view builders of `_PackOpeningScreenState` — `_buildPack`, `_buildMystery`, `_buildCaption`, `_buildWalkout`, `_buildCard` — moved VERBATIM (bodies byte-identical, machine-diffed against `HEAD` before the move; only the extension's own closing brace differs) into a new private extension `extension _PackRevealViews on _PackOpeningScreenState` inside part file `lib/features/packs/pack_opening_screen_reveal.dart` (`part of 'pack_opening_screen.dart'`; screen stays the importing barrel, so no consumer import churn and all private state members stay reachable). Chain/handoff presentation was already extracted in the predecessor task (`pack_opening_widgets.dart`), so the reveal view family was the only remaining mass. No behaviour, timeline, haptic, or animation change; no test edits; no localization strings touched (relocation only, EN/AR and RTL unaffected). Files changed: `lib/features/packs/pack_opening_screen.dart` (892 → 654 lines incl. new `part` directive) and `lib/features/packs/pack_opening_screen_reveal.dart` (new, 249 lines).

Exact commands and results (2026-11-06, Flutter 3.47.9 stable / Dart 3.13.7, commit `43a488b` base):
- `flutter analyze` → `No issues found! (ran in 12.7s)` — zero analyzer warnings.
- `flutter test test/features/packs/pack_opening_screen_test.dart test/features/squad/player_card_reveal_test.dart test/features/packs/pack_effects_test.dart` → `+16: All tests passed!` with zero test edits.
- Full suite: `flutter test` → `+709: All tests passed!` exit 0, run 2026-11-06 (~5m30s wall), zero failures, zero skips observed.
- Line budget: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` no longer lists `pack_opening_screen.dart` (654) or the new part file (249); remaining >800 files are out of this task's scope (collection_store, season_store and the six files the 2026-11-06 enforcement amendment assigns to their own future task files).

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0035` (was `reviews/tasks/2026-11-06_app-structure_finish-pack-reveal-split.md`, status DONE).
- Awaiting independent verification on the new board.

## Historical Links
- Depends on: None
- Follows: `2026-11-05_app-structure_split-pack-reveal-widgets`
- Follow-up: None
