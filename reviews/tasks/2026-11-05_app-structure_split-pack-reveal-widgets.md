# App structure: extract the reveal timeline and painters from the pack opening screen

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: DONE
- Completed on: 2026-11-05

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/packs/pack_opening_screen.dart` (1,272 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `pack_opening_screen.dart` measured 1,278 lines at task creation (2026-11-04), 1,272 on 2026-11-05; the reveal animation spec and its CustomPainters share the file with the screen (anchors at creation: `_Tl` timeline:72, `_MysteryPainter`:1044, `_ChainButton`:1110, `_ChainHandoffLine`:1242).
- Root cause / technical justification: timeline spec, painters and chain buttons live inside the screen file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/packs/pack_opening_screen.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: widget/painter move only; reveal animations must stay frame-identical; the pack opening/squad reveal suites are the regression net.

## Reproduction Steps
Not applicable.

## Task
- [x] Extract the reveal timeline and painters from the pack opening screen | Where: `lib/features/packs/pack_opening_screen.dart` (1,272 lines on 2026-11-05; anchors above) | Expected: `pack_reveal_timeline.dart` (the `_Tl` spec) and `pack_opening_widgets.dart` (painter + chain buttons/handoff line); reveal animations frame-identical — the pack opening/squad reveal suites green with zero test edits.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [ ] Reveal animations frame-identical; pack opening/squad reveal suites green with zero test edits

## Developer Notes
- Extracted from `pack_opening_screen.dart` (1,272 -> 893 lines):
  - `pack_reveal_timeline.dart` (162 lines): the `_Tl` timeline spec,
    renamed public `RevealTimeline`, plus the four public reveal
    duration/keyframe constants (`kStandardRevealDuration`,
    `kLegendaryRevealDuration`, `kLegendaryNameStart`, `kLegendaryDone`)
    that parameterise it.
  - `pack_opening_widgets.dart` (249 lines): `MysteryPainter` (was
    `_MysteryPainter`), `ChainButton` (was `_ChainButton`, gained
    `super.key`), `ChainHandoffLine` (was `_ChainHandoffLine`).
- `pack_opening_screen.dart` imports both and re-exports
  `pack_reveal_timeline.dart` (barrel) so `pack_opening_screen_test`
  keeps resolving the reveal duration constants with ZERO test edits.
- Reveal animation values, curves and widget trees unchanged — pure
  relocation plus identifier renames.
- Checks (Flutter 3.47.9 stable):
  - `flutter analyze`: No issues found!
  - `flutter test test/features/packs/`: All tests passed (47) —
    pack opening + engine + screen suites, zero test edits.
  - `flutter test` full suite: 705 passed, 4 failed — exactly the four
    known phase-3 balance bands (identical to the pre-change run);
    zero new failures.
- Only the three pack files and this task file are in the commit.


## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
