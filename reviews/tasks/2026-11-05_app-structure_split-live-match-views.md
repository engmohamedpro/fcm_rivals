# App structure: split live match views into header, commentary and touchline families

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: OPEN
- Completed on: -

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/features/match/live_match_views.dart` (853 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `live_match_views.dart` measured 1,206 lines at task creation (2026-11-04) with three widget families in one file (anchors at creation: header/momentum family :27-613, commentary/key-moment family :614-947, `TouchlinePepTalkCard`:948). On 2026-11-05 it measures 853 lines after the one-moment commentary ticker commit — still above the 800 threshold; re-locate the family boundaries before splitting.
- Root cause / technical justification: header, commentary and touchline widget families share one file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/features/match/live_match_views.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: `live_match_views.dart` may remain as a barrel so existing imports never churn; widget move only, no behaviour change.

## Reproduction Steps
Not applicable.

## Task
- [ ] Split live match views into header, commentary and touchline families | Where: `lib/features/match/live_match_views.dart` (853 lines on 2026-11-05, was 1,206 at creation) | Expected: `match_header.dart` (MatchHeader, TeamChip, MomentumBar, LiveDot, SpeedSelector), `match_commentary.dart` (CommentaryRow, KeyMomentCard, EventRow, FillerRow) and `touchline_pep_talk.dart`; `live_match_views.dart` may remain as a barrel; live UX tests green with zero test edits.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`)
- [ ] Live UX tests green with zero test edits; `live_match_views.dart` remains a re-export barrel

## Developer Notes
<Implementation summary, files changed, exact test commands/results, and rejection reason/evidence if applicable. Implement this task only, create one task-specific commit, and push it before starting another task.>

## Reviewer Verification
<Reviewer records verification date, tested commit hash, checks performed, results, and remaining limitations. Do not add personal names.>

## Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
