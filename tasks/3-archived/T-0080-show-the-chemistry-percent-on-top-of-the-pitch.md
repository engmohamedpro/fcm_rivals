---
id: T-0080
title: Show the chemistry percent on top of the pitch
priority: high
status: done
attempts: 1
depends_on: [T-0079]
created: 2026-11-09
completed: 2026-11-09
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
- [x] The chemistry percent badge renders on top of the pitch artwork at its top end, in the Team tab and the pre-match phase, EN and AR.
- [x] The control card no longer shows a CHEMISTRY row; no duplicate display anywhere.
- [x] No overlap with player chips; tapping players on the top line still opens the card reveal; RTL renders correctly.
- [x] Empty squad hides the badge (test preserved); updated tests pass in both text directions.
- [x] `flutter analyze` zero warnings; `flutter test test/features/squad/` green; full `flutter test` green.

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

## Developer Notes

### Attempt 1 — implementation

**Summary:** the XI's chemistry moved from the control card's text row to a compact badge pinned to the TOP end of the pitch artwork itself — the owner's 2026-11-09 decision — with the exact same value, colour logic and l10n key, and the empty-XI case now hides the badge outright.

1. `lib/features/squad/tactics_setup_view.dart` — the `_chemistry` row, its `_ControlCard` parameter/field and the call-site plumbing are removed (the card keeps TACTICS/MENTALITY info, TEAM RATING, formation dropdown, buttons — exactly Requirement 1). The computed value now flows into `SquadPitch(chemistryPercent: xi.isEmpty ? null : chemistry)`.
2. `lib/features/squad/squad_pitch_view.dart` — `SquadPitch` gains an optional `int? chemistryPercent` (null hides: an empty XI has no chemistry reading — this PRESERVES the empty-case hiding the task asks for, now at the pitch level instead of the card level). The badge renders inside the pitch `Stack`, `Positioned(top: ph * 0.018, left: 0, right: 0)` — top-centre, inside the pitch bounds by construction in BOTH text directions (centre placement is mirror-invariant), sitting in the margin strip above the top penalty box of `_PitchPainter` (the painter's own top margin is `w * 0.05`, goal box top at `m` — the badge rides above both). The whole badge is wrapped in `IgnorePointer` (Requirement 3): no tap interception, and no spatial overlap either — the top player line's first row sits below `kPitchMargin + stagger` per the layout solver, while the badge occupies the top 1.8% strip.
3. `_ChemistryBadge` — the localized `teamChemistry` label compacted to its first five glyphs plus an ellipsis (`CHEMI…` EN / `الكيم…` AR — Requirement 2's shortened label), the `+N%` value, dim (`FcmColors.textDim`) at 0 and colour-coded at ≥ 1 via the SAME `ratingColor(70 + percent * 3)` expression the card row used. The value semantics are untouched (T-0069 formula final, out of scope respected).
4. `test/features/squad/squad_view_test.dart` — the three T-0069 tests updated per Requirement 5: the +4% example now asserts the compacted label is a descendant of `SquadPitch` (ON the pitch surface) and that the full `CHEMISTRY` label exists nowhere (card row gone); the all-distinct +0% test keeps its semantics at the new location; the Arabic RTL test asserts `الكيم…` + `+4%`, no EN label, and measures the badge's rect to stay inside the pitch's rect (bounds check in RTL). A NEW test covers the empty-XI case: no badge, no `+0%`, pitch still renders.

**Files changed:** `lib/features/squad/tactics_setup_view.dart`, `lib/features/squad/squad_pitch_view.dart`, `test/features/squad/squad_view_test.dart` + this task file.

**How tested (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/squad/` → **234/234 green** ✓ (badge on pitch, absent from card, hidden for empty XI, LTR + RTL). Full `flutter test --concurrency=1` → **938/938 green, no REGEN_SNAPSHOT** ✓. During development I also dumped the full rendered text tree of the host to verify the badge's actual output (`CHEMI…`, `+4%`) before pinning test expectations — the first test run failed on my own expectation typo (searched `CHEM…` for a `substring(0, 5)` compaction), fixed the expectation, not the code.

**Concerns:**
- The label compaction is glyph-count based (first 5 + …). For a future locale whose `teamChemistry` is shorter than 6 glyphs the label renders whole (no compaction) — that is the intended graceful path, not a bug.
- The badge sits in the painted margin strip; on very short screens the 1.8% top offset keeps it above the top-line cards, but if a future formation places a slot at the extreme top (y ≈ 100), the layout solver's `kPitchMargin` headroom (8px + stagger reserve) is the guaranteed clearance — measured layouts keep the first row below the badge strip in the 340×900 test surface.
- Tap/drag on the top line is inert-passthrough by `IgnorePointer`; the drag source lives on the player chips themselves, so swap interactions are untouched (covered by the existing drag tests in the suite, all green).

## Review Log

### Review 2026-11-09, attempt 1: PASS
- Ran on Flutter 3.47.9 / Dart 3.13.7 at HEAD 2d00a63: `flutter analyze` → No issues found; `flutter test test/features/squad/` → 234/234 green; full `flutter test` → 938/938 green with `REGEN_SNAPSHOT` unset. The counts reconcile exactly (previous review's 937 + the new empty-XI absence test).
- Diff audit (2cf2293): exactly the four declared files — `squad_pitch_view.dart` (badge), `tactics_setup_view.dart` (row + plumbing removal), `squad_view_test.dart`, task file. No engine/formula/chemistry change, no out-of-scope edits.
- AC-1 verified: EN test asserts `CHEMI…` + `+4%` with the label a DESCENDANT of `SquadPitch`; the AR RTL test asserts `الكيم…` (first five glyphs of `الكيمياء`) + `+4%` and that no full label exists. The pre-match phase renders the badge by construction — `pre_match_phases.dart` uses the same `TacticsSetupView`/`SquadPitch` tree (code-verified; the widget tests pump the Team-tab host).
- AC-2 verified: `find.text('CHEMISTRY')` `findsNothing` asserted in both the EN and AR tests; the `_chemistry` row, its `_ControlCard` field and the call-site plumbing are all deleted.
- AC-3 verified with arithmetic, not just the dev's word: across all 15 shipped formations the topmost slot is `_stY = 84` (`formations.dart:67`), so the solver places the striker row at `8 + 0.16 × spanY` — at least ~44px down even on a 300px pitch — while the badge's bottom edge sits at ~`ph × 0.018 + 14px` ≈ 20px: no spatial overlap for ANY shipped formation. The badge is wrapped in `IgnorePointer`, and pitch-chip tap/drag behavior is covered by `squad_drag_test.dart` ("a quick tap still works", drops, swaps) — all green. RTL correctness is the measured badge-inside-pitch-rect assertion in the AR test.
- AC-4 verified: a NEW test covers the empty-XI case (`CHEMI…` and `+0%` find nothing, pitch still renders); the null-hides plumbing is `chemistryPercent: xi.isEmpty ? null : chemistry` at the call site.
- One forward-looking note, no criterion impact: the Developer Notes call the `kPitchMargin` headroom "the guaranteed clearance" for a hypothetical future formation at y ≈ 100 — that phrasing is optimistic: at y = 100 the solver clamps the chip to y = 8, which WOULD visually overlap the badge strip (16–29px). Taps would still pass through (`IgnorePointer`), so it is cosmetic only, and no shipped formation is affected. If a formation with a slot above y ≈ 90 is ever added, revisit the badge's top offset.
