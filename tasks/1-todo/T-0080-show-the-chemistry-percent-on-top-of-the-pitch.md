---
id: T-0080
title: Show the chemistry percent on top of the pitch
priority: high
status: todo
attempts: 0
depends_on: [T-0079]
created: 2026-11-09
completed:
---

# T-0080: Show the chemistry percent on top of the pitch

## Goal
The XI's chemistry percent reads as a compact badge ON the football pitch itself — pinned to the top end of the pitch artwork — instead of the text row in the control card (owner decision 2026-11-09).

## Context
- Today chemistry renders as a right-aligned `CHEMISTRY +N%` row inside the tactical control card: `_chemistry(...)` in `lib/features/squad/tactics_setup_view.dart` (~241 call site, ~314-340 widget). The value is computed in `TacticsSetupView.build` (~103-113) via `chemistryPercentOf(...)` from `lib/features/match/chemistry.dart` and passed down as `chemistryPercent` (T-0069).
- The pitch is `SquadPitch` (`lib/features/squad/squad_pitch_view.dart`, class at ~46): a `Stack` with a full-bleed `_PitchPainter` (goal/penalty boxes at top and bottom, margins `m` on each end, ~382-456) and `AnimatedPositioned` player chips. Keeper at the bottom, attack at the top.
- `TacticsSetupView` is shared by the Team tab and the pre-match phase — the badge appears on both automatically once it lives on the pitch.
- Tests to update: the T-0069 chemistry tests in `test/features/squad/squad_view_test.dart` (~800-867) — they assert `find.text('CHEMISTRY')` presence on the control card and `findsNothing` for the empty-squad case. Depends on T-0079 because both tasks edit `tactics_setup_view.dart` (serialization, not logic).

## Requirements
1. `lib/features/squad/tactics_setup_view.dart` — remove the `_chemistry` row from the control card (the card keeps TACTICS/MENTALITY info, rating, formation dropdown, buttons).
2. Plumb `chemistryPercent` into `SquadPitch` and render a compact badge pinned to the TOP end of the pitch, laid OVER the pitch artwork (inside the top margin strip / above the top penalty box): the localized `teamChemistry` label (shortened, e.g. `CHEM`) with the `+N%` value, styled like today (dim at 0, colour-coded at ≥ 1 via the existing `ratingColor` logic).
3. The badge must NOT overlap the top player chips or intercept their taps (`IgnorePointer` or equivalent), and must stay inside the pitch bounds in LTR and RTL (centre-top or directional placement — implementer's choice, verified in both directions).
4. The empty-collection case keeps hiding chemistry exactly as today (`findsNothing` behavior preserved).
5. Update the T-0069 tests: CHEMISTRY text now found on the pitch surface, not the control card; keep the +4% example semantics and the empty-squad absence case; cover RTL.

## Out of Scope
- Changing the chemistry FORMULA or the engine (T-0069 logic is final).
- Adding chemistry to the live match screen or anywhere else.
- Redesigning the control card beyond removing the row (T-0079 already owns the sheet text changes).

## Acceptance Criteria
- [ ] The chemistry percent badge renders on top of the pitch artwork at its top end, in the Team tab and the pre-match phase, EN and AR.
- [ ] The control card no longer shows a CHEMISTRY row; no duplicate display anywhere.
- [ ] No overlap with player chips; tapping players on the top line still opens the card reveal; RTL renders correctly.
- [ ] Empty squad hides the badge (test preserved); updated tests pass in both text directions.
- [ ] `flutter analyze` zero warnings; `flutter test test/features/squad/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/squad/
# Expected: all pass — chemistry badge on the pitch, absent from the control
# card, hidden for an empty squad, in LTR and RTL

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```
