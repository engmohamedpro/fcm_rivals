---
id: T-0024
title: Split live match views into header, commentary and touchline families
priority: medium
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-05
completed:
# migrated from: reviews/tasks/2026-11-05_app-structure_split-live-match-views.md
---

# T-0024: Split live match views into header, commentary and touchline families

## Goal
Split live_match_views.dart into its current header and touchline widget families with the original file left as a re-export barrel; every resulting file at most 800 lines.

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/match/live_match_views.dart` (853 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `live_match_views.dart` measured 1,206 lines at task creation (2026-11-04) with three widget families in one file (anchors at creation: header/momentum family :27-613, commentary/key-moment family :614-947, `TouchlinePepTalkCard`:948). On 2026-11-05 it measures 853 lines after the one-moment commentary ticker commit — still above the 800 threshold; re-locate the family boundaries before splitting.
- Root cause / technical justification: header, commentary and touchline widget families share one file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/match/live_match_views.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: `live_match_views.dart` may remain as a barrel so existing imports never churn; widget move only, no behaviour change.

## Requirements
- [x] Split live match views into header, commentary and touchline families | Where: `lib/features/match/live_match_views.dart` (853 lines on 2026-11-05, was 1,206 at creation) | Expected: `match_header.dart` (MatchHeader, TeamChip, MomentumBar, LiveDot, SpeedSelector), `match_commentary.dart` (CommentaryRow, KeyMomentCard, EventRow, FillerRow) and `touchline_pep_talk.dart`; `live_match_views.dart` may remain as a barrel; live UX tests green with zero test edits. (Executed per the Investigation's own "re-locate the family boundaries before splitting" instruction — see Developer Notes for the executed boundary set.)

## Out of Scope
- Nothing beyond the requirements above was scoped out in the original task.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes
- [x] EN/AR localization complete and RTL verified where applicable (N/A — verbatim widget move; no text, directionality or layout code changed)
- [x] No performance or application-size regression (widget move only, no behaviour change)
- [x] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [x] Live UX tests green with zero test edits; `live_match_views.dart` remains a re-export barrel

## How to Verify
Run the board's standard gates:

```bash
flutter analyze
flutter test
```
Expected: analyzer reports no issues; the full test suite passes. Per-task checks are quoted in Requirements and Developer Notes.

---

## Developer Notes
- Split landed 2026-11-06, following the Investigation's "re-locate the
  family boundaries before splitting" instruction. The task's Expected
  list was written against the pre-ticker file: the commentary/key-moment
  family (CommentaryRow, KeyMomentCard, EventRow, FillerRow) left this
  file in the one-moment commentary ticker redesign and today exists
  NOWHERE in lib/ or test/ (verified by grep + `git log -S`), so there
  was no commentary family left to move and no `match_commentary.dart`
  was created (an empty alias file would be noise; the live commentary
  lives in `commentary_ticker.dart`).
- Executed boundary set (current families, moved VERBATIM, no logic or
  signature changes): `lib/features/match/match_header.dart` (540 lines)
  — MatchHeader, _TeamChip, opponentMomentumColor, MomentumBar,
  _MomentumPainter, _LiveDot, _SpeedSelector, _HeaderIconButton;
  `lib/features/match/touchline_pep_talk.dart` (328 lines) —
  showPepTalkChooser, TouchlinePepTalkCard, _PepTalkOption, SheetOption
  (SheetOption is referenced only inside this family; its doc's
  "recovery sheets" consumer no longer exists).
- `live_match_views.dart` remains the re-export barrel (18 lines,
  `fcm_widgets.dart` pattern) — all consumers unchanged: match_screen
  and match_report_view (lib) plus live_match_ux_test and
  match_screen_test (test) import the barrel only; zero import churn.
- Observation for review (not acted on — out of scope for a move-only
  task): `showPepTalkChooser` has ZERO call sites in lib/ or test/ (its
  modal-sheet flow was superseded by the TouchlinePepTalkCard overlay).
  It was moved verbatim to keep the barrel API identical; deletion is a
  separate decision.
- Verification: `wc -l` → match_header.dart 540, touchline_pep_talk.dart
  328, live_match_views.dart 18 (all ≤800); `flutter analyze` → No
  issues found!; targeted suites `flutter test
  test/features/match/live_match_ux_test.dart
  test/features/match/match_screen_test.dart` → 26/26 passed.
- Final suite summary line: `flutter test` → `05:21 +709: All tests
  passed!` — 709/709, the same test count as before the split (709 at
  `34a5fed`), i.e. ZERO test edits, exactly as the task requires.

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0024` (was `reviews/tasks/2026-11-05_app-structure_split-live-match-views.md`, status DONE).
- Awaiting independent verification on the new board.

## Historical Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None
