# App structure: split the player card into card, mini card and painters

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: OPEN
- Completed on: -

## Context
One of ten follow-ups carved out of `2026-11-04_app-structure_remaining-oversized-files` (set to SPLIT 2026-11-05 per the README §1 one-file-per-task rule). The README's ~800-line split threshold (README.md:72-74) is contradicted by `lib/core/ui/player_card.dart` (1,247 lines on 2026-11-05). Split it following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Investigation & Evidence
- Investigation: `player_card.dart` measured 1,247 lines at task creation (2026-11-04) and on 2026-11-05; card face/back, mini card and three CustomPainters share one file (anchors at creation: `FcmPlayerCardBack`:393, `_CardFacePainter`:504, `_CardBackPainter`:837, `FcmMiniCard`:938, `_GhostPainter`:1088).
- Root cause / technical justification: the shared UI-kit card family grew inside a single file; the god-files review split only its two in-scope targets.
- Affected files/components: `lib/core/ui/player_card.dart`
- Evidence: `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` lists the file on main.
- Expected benefit / necessity: makes the README convention real; measurable target — every resulting file ≤800 lines.
- Dependencies / side effects: a `player_card.dart` barrel must keep the existing import path so the 20+ core/ui consumers never churn; painter move must not change rendering.

## Reproduction Steps
Not applicable.

## Task
- [ ] Split the player card into card, mini card and painters | Where: `lib/core/ui/player_card.dart` (1,247 lines; anchors above) | Expected: `mini_card.dart` (FcmMiniCard + ghost/stat/stamina widgets) and `player_card_painters.dart` (the CustomPainters); a `player_card.dart` barrel keeps the existing import path; `player_card_test.dart` and `mini_card_test.dart` green with zero test edits.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified where applicable
- [ ] No performance or application-size regression
- [ ] Every resulting file ≤800 lines (excluding generated `*.g.dart`); `player_card.dart` barrel keeps the existing import path
- [ ] `player_card_test.dart` and `mini_card_test.dart` green with zero test edits

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
