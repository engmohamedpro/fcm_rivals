# App structure: finish the pack-opening-screen split below the 800-line convention

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-06
- Status: OPEN
- Completed on: -

## Context
Correction follow-up of `2026-11-05_app-structure_split-pack-reveal-widgets` (SPLIT 2026-11-06: the timeline/widgets extraction verified good, but its acceptance criterion "every resulting file ≤800 lines" is unmet — `pack_opening_screen.dart` still measures 892 lines). This task finishes the split to the README's ~800-line convention (README.md:72-74).

## Investigation & Evidence
- Investigation: the timeline spec (`pack_reveal_timeline.dart`, 161 lines) and the painters/chain widgets (`pack_opening_widgets.dart`, 246 lines) landed, shrinking the screen 1,272 → 892 (measured 2026-11-06; the developer's notes report 893 at the task commit) — still ~92 lines above the budget; the file now holds `PackChainInfo` (:61) plus the screen state class (:96) whose reveal/handoff UI families carry the bulk.
- Root cause / technical justification: the reveal-flow UI families (chain/handoff presentation, reveal orchestration) remain inside the screen state class; only method/widget-family extraction remains.
- Affected files/components: `lib/features/packs/pack_opening_screen.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main at d0fbb88.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: the proven pattern is the engine split's (`5447a67`): cohesive widget/method families moved verbatim into part files or helper libraries with the screen as the importing barrel; reveal animations must stay frame-identical; the pack opening/squad reveal suites are the regression net.

## Reproduction Steps
Not applicable.

## Task
- [ ] Extract cohesive pack-opening widget/method families below the 800-line budget | Where: `lib/features/packs/pack_opening_screen.dart` (892 lines on 2026-11-06) | Expected: `pack_opening_screen.dart` and every new file ≤800 lines; reveal animations frame-identical — pack opening/squad reveal suites green with zero test edits.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [ ] Reveal animations frame-identical; pack opening/squad reveal suites green with zero test edits

## Developer Notes
<Implementation summary, files changed, exact test commands/results, and rejection reason/evidence if applicable. Implement this task only, create one task-specific commit, and push it before starting another task.>

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: None
- Follows: `2026-11-05_app-structure_split-pack-reveal-widgets`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
