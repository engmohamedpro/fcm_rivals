# App structure: split the player card into card, mini card and painters

- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Created: 2026-11-05
- Status: CLOSED
- Completed on: 2026-11-05

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
- [x] Split the player card into card, mini card and painters | Where: `lib/core/ui/player_card.dart` (1,247 lines; anchors above) | Expected: `mini_card.dart` (FcmMiniCard + ghost/stat/stamina widgets) and `player_card_painters.dart` (the CustomPainters); a `player_card.dart` barrel keeps the existing import path; `player_card_test.dart` and `mini_card_test.dart` green with zero test edits.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated; full `flutter test` suite passes (green except the four tracked phase-3 balance bands — see Reviewer Verification)
- [x] EN/AR localization complete and RTL verified where applicable (painter/widget move only)
- [x] No performance or application-size regression (pure relocation)
- [x] Every resulting file ≤800 lines (excluding generated `*.g.dart`); `player_card.dart` barrel keeps the existing import path
- [x] `player_card_test.dart` and `mini_card_test.dart` green with zero test edits

## Developer Notes
- Extracted from `player_card.dart` (1,247 -> 430 lines):
  - `mini_card.dart` (330 lines): `FcmMiniCard` +
    `_GhostPainter`/`_StatRow`/`_StaminaBar`/`_WarnPainter`.
  - `player_card_painters.dart` (529 lines): the drawing primitives
    (`kPlayerCardAspect`, `cardPath`, `_insetCanvas`, `_paintRays`,
    `_cardStarPath`) + `CardFacePainter`/`CardBackPainter` (were
    private `_CardFacePainter`/`_CardBackPainter`, public now
    because both remaining files use them).
  - `player_card.dart` keeps `FcmPlayerCard` + `FcmPlayerCardBack`
    and re-exports both new files (barrel) — every existing
    `import 'player_card.dart'` (with `show FcmMiniCard` etc.) keeps
    resolving with ZERO test edits.
- Checks (Flutter 3.47.9 stable):
  - `flutter analyze`: No issues found!
  - `flutter test test/features/ui/ test/features/packs/packs_screen_test.dart
    test/features/squad/squad_view_test.dart`: All tests passed (25)
    — includes `player_card_test.dart`, `mini_card_test.dart`, and the
    barrel-importing packs/squad suites.
  - `flutter test` full suite: 705 passed, 4 failed — exactly the
    four known phase-3 balance bands; zero new failures.
- Only the three card files and this task file are in the commit.


## Reviewer Verification
Verified 2026-11-06 on commit `d9aa76b` (static; the cited runs are the developer's, consistent across the session's six implementation commits). Checks: (1) `git show d9aa76b --name-only` — only the three card files and this task file; (2) measured 2026-11-06: player_card 427, mini_card 328, player_card_painters 528 — all ≤800, and the `player_card.dart` barrel keeps the existing import path; (3) ui/packs/squad suites reported green (25, including `player_card_test.dart` and `mini_card_test.dart`) with zero test edits; full suite 705/4 with only the tracked balance bands. Limitation: the suite was not re-run in this sandbox. CLOSED.

## Links
- Depends on: None
- Follows: `2026-11-04_app-structure_remaining-oversized-files`
- Follow-up: None

## Amendments
<Reviewer-owned, append-only. Add dated entries correcting the task's target or mechanism; never rewrite the original task text.>
