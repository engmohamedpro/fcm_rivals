---
id: T-0027
title: Extract the reveal timeline and painters from the pack opening screen
priority: medium
status: todo
attempts: 0
depends_on: [T-0035]
created: 2026-11-05
completed:
# migrated from: reviews/tasks/2026-11-05_app-structure_split-pack-reveal-widgets.md
---

# T-0027: Extract the reveal timeline and painters from the pack opening screen

## Goal
Extract the pack reveal timeline and painters from the pack opening screen; finishing the screen below the 800-line convention lives in the follow-up task.

## Context
> **Record shell (migrated 2026-11-06):** this file was status SPLIT on the old reviews/ board — its executable work was handed over to the follow-up tasks listed in `depends_on`. There is nothing to implement in this file; it is kept for traceability and closes only when all of its `depends_on` tasks are archived.

One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/packs/pack_opening_screen.dart` (1,272 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `pack_opening_screen.dart` measured 1,278 lines at task creation (2026-11-04), 1,272 on 2026-11-05; the reveal animation spec and its CustomPainters share the file with the screen (anchors at creation: `_Tl` timeline:72, `_MysteryPainter`:1044, `_ChainButton`:1110, `_ChainHandoffLine`:1242).
- Root cause / technical justification: timeline spec, painters and chain buttons live inside the screen file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/packs/pack_opening_screen.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: widget/painter move only; reveal animations must stay frame-identical; the pack opening/squad reveal suites are the regression net.

## Requirements
- [x] Extract the reveal timeline and painters from the pack opening screen | Where: `lib/features/packs/pack_opening_screen.dart` (1,272 lines on 2026-11-05; anchors above) | Expected: `pack_reveal_timeline.dart` (the `_Tl` spec) and `pack_opening_widgets.dart` (painter + chain buttons/handoff line); reveal animations frame-identical — the pack opening/squad reveal suites green with zero test edits.

## Out of Scope
- Any remaining implementation in this file; the screen-budget completion lives in `2026-11-06_app-structure_finish-pack-reveal-split`.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes (green except the four tracked phase-3 balance bands — see Reviewer Verification)
- [x] EN/AR localization complete and RTL verified where applicable (widget/painter move only)
- [x] No performance or application-size regression (pure relocation plus identifier renames)
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`) — UNMET: `pack_opening_screen.dart` still 892 lines (Reviewer Verification)
- [x] Reveal animations frame-identical; pack opening/squad reveal suites green with zero test edits

## How to Verify
Run the board's standard gates:

```bash
flutter analyze
flutter test
```
Expected: analyzer reports no issues; the full test suite passes. Per-task checks are quoted in Requirements and Developer Notes.

---

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

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0027` (was `reviews/tasks/2026-11-05_app-structure_split-pack-reveal-widgets.md`, status SPLIT).
- Record shell: executable work lives in the `depends_on` follow-ups.

Verified 2026-11-06 on commit `35c953f` — extraction GOOD, closure BLOCKED by one acceptance criterion (§6.A). Checks: (1) `git show 35c953f --name-only` — only the three pack files and this task file; (2) measured 2026-11-06: `pack_reveal_timeline.dart` 161 ✓, `pack_opening_widgets.dart` 246 ✓, `pack_opening_screen.dart` 892 ✗ against the ≤800 criterion (1,272 → 892); (3) packs suites reported green (47 tests) with zero test edits; full suite 705/4 with only the tracked balance bands; (4) renames are identifier-visibility changes only (private → public), documented. Failure evidence: AC "Every resulting file ≤800 lines" unmet. Action per §6.A: correction task `2026-11-06_app-structure_finish-pack-reveal-split` created; this file → SPLIT and closes when the follow-up is CLOSED. Limitation: the suite was not re-run in this sandbox.

- 2026-11-06 (reviewer, verification of the DONE claim): Status DONE → SPLIT — the timeline/widgets extraction is verified good, but the "every resulting file ≤800 lines" criterion is unmet (pack_opening_screen.dart 892 measured). The remaining work lives in `2026-11-06_app-structure_finish-pack-reveal-split`; the task text above is unchanged historical record.

## Historical Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: `2026-11-06_app-structure_finish-pack-reveal-split`
