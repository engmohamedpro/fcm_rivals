---
id: T-0062
title: Add stepped snapping to the tactic scale slider
priority: medium
status: done
attempts: 1
depends_on: [T-0061]
created: 2026-11-08
completed: 2026-11-08
---

# T-0062: Add stepped snapping to the tactic scale slider

## Goal
`FcmScaleSlider` gains a stepped mode for N named steps: the marker follows the finger while dragging, then settles on the snapped step position on release, so 3-step tactic axes (Deep / Standard / High …) never show a marker floating between two steps.

## Context
- Today the marker parks wherever the drag ends (any int 0-100) and only the floating pill snaps its name via `mentalityFromScale` (`lib/features/match/team_tactics.dart`, lines 200-209). That reads fine for the 7 mentalities but would look broken for 3-step axes.
- Step-math precedent to reuse: `index * 100 / (values.length - 1)` — the mentality positions 0, 17, 33, 50, 67, 83, 100.
- Rounding is Dart's `.round()` — half AWAY FROM ZERO, never truncation or int division. Verified boundaries to reuse in tests: with 3 steps, release 24 snaps to 0, 25 to 50, 74 to 50, 75 to 100; with 7 steps, release 58 lands on Balanced and 59 is the first scale landing on Positive.
- T-0061 introduced the direction seam in `lib/core/ui/fcm_scale_slider.dart`; snapping must work identically in LTR and RTL.
- The reference consumer is the mentality row in the tactic options sheet (`lib/features/squad/tactics_setup_view.dart`, around lines 440-466), which adopts the mode with `steps: 7`.

## Requirements
1. New `FcmScaleSlider` constructor parameter `steps` (`int?`). `null` keeps today's free continuous mode byte-identical.
2. Stepped mode: `onChanged` and `onChangeEnd` only ever report snapped step positions (3 steps → 0 / 50 / 100), computed with the same `.round()`-based math as `mentalityFromScale` (half away from zero). While dragging, the marker follows the finger; on release it animates (~150 ms, interruptible by a new drag) onto the snapped step position.
3. Render a small tick mark at every step position on the track so the steps are visible.
4. The mentality row in the tactic options sheet passes `steps: 7`; the committed enum per release position must equal what `mentalityFromScale(scale)` produces today.
5. New widget tests (extend `test/core/ui/fcm_scale_slider_test.dart` from T-0061): a 3-step slider released at 40 commits 50; at 95 commits 100; near the minimum commits 0; the boundary releases 24 → 0, 25 → 50 and 75 → 100 land on the verified sides; the pill names the snapped step; a drag in RTL still increases towards the left.

## Out of Scope
- Applying stepped sliders to the nine tactic axes (T-0064).
- Any change to `Mentality` values, the mapping formula, or persistence.
- New l10n keys.

## Acceptance Criteria
- [x] Free mode (`steps: null`) behaves exactly as today — existing tests untouched and green.
- [x] Stepped mode commits only snapped positions and settles the marker on release in both text directions (new tests).
- [x] The mentality row commits the same enum as before for release positions 0, 50, 100 and the off-step releases 58 (→ Balanced) and 59 (→ Positive).
- [x] `flutter analyze` reports zero warnings; `flutter test` full suite green.

## How to Verify
```bash
flutter analyze
flutter test
flutter run  # manual: Team tab -> TACTICS -> drag Mentality
```
Expected: analyze clean, full suite green; manually the marker settles on the seven step positions and the pill names them.

---

## Developer Notes

- **Summary of changes:** `FcmScaleSlider` gained stepped mode via the new `steps` constructor parameter (`int?`, asserted ≥ 2). **`steps: null` keeps the free continuous mode byte-identical** — the free path in `_updateFromDx` is the old code verbatim, the free `onHorizontalDragEnd` still commits directly with no animation, and the lone centre tick still renders. Stepped mode: (1) `_snapToStep` uses the exact `mentalityFromScale` math (`round(raw * (steps-1) / 100)` then `round(index * 100 / (steps-1))`, Dart `.round()` half away from zero, input clamped 0–100) — 3 steps commit only 0/50/100, 7 only the mentality positions; (2) the marker follows the finger while dragging (`_display` rides the raw position) but `onChanged`/`onChangeEnd` only ever report snapped step positions; (3) on release (`onHorizontalDragEnd`/`onTapUp`) the widget fires `onChangeEnd` with the snapped value and animates the marker onto it — a 150 ms `AnimationController` settle with `Curves.easeOut`, interruptible mid-flight by a new `onHorizontalDragStart` (which stops the controller; the finger takes the marker over from wherever it is); (4) step ticks render at every step position (replacing the free mode's centre tick — 50 is always among the step positions for odd counts), mirrored in RTL through the T-0061 `_xFor` seam, so snapping reads identically in both directions. The mentality row in `tactics_setup_view.dart` passes `steps: Mentality.values.length` (= 7); the committed enum per release is `mentalityFromScale(snappedScale)` — identical mapping, now with the marker visibly resting on the step.
- **Files changed:** lib/core/ui/fcm_scale_slider.dart, lib/features/squad/tactics_setup_view.dart (mentality row: + steps: 7), test/core/ui/fcm_scale_slider_test.dart (7 new tests in the `T-0062: stepped snapping` group).
- **How I tested it:** `flutter analyze` — No issues found. `test/core/ui/fcm_scale_slider_test.dart` — **12/12 passed**: the 5 T-0061 RTL/LTR tests untouched and green (free-mode RTL mirroring is regression-locked), plus 7 new: 3-step releases at 40→50, 95→100, near-min→0; boundary releases 24→0, 25→50, 75→100 (half away from zero, gesture x computed with the thumb inset); `onChanged` only ever reports step positions across a full-axis sweep; the pill names the snapped step (`قيمة 50` found, raw `قيمة 40` absent); the marker rests EXACTLY on the step after settle (centre ±3px); RTL stepped drag-left still increases to the max step; free mode still commits raw positions (62-ish, not a snapped 50). `test/features/squad/squad_view_test.dart` — **7/7 passed untouched** (the mentality row's drag-to-veryAttacking commit behaves identically through the stepped path). Full `flutter test` — run to completion after the fixes: all green — 862/862.
- **Concerns / assumptions:** (1) Bug found and fixed during verification, worth recording: the first implementation fired `onChangeEnd` only from the drag-update path, so a stepped drag whose last update lands on the SAME step as the previous one never committed (tests caught it — release 40→50 returned −1); `onHorizontalDragEnd` now always fires the commit in stepped mode before settling. (2) The boundary test computes the gesture x from the scale position using the thumb inset (`dx = thumbRadius + v/100 × span`) — that mirrors the engine's own mapping; a naive width-fraction drag would land 2-3 units off and flip the 24/25 boundary. (3) No l10n keys added, no `Mentality` change, no persistence change (Out of Scope respected). (4) The settle animation is 150 ms as specified; interrupting it mid-flight by a new drag is covered by design (the drag-start stops the controller) though not separately test-locked — the settle-onto-step and free-mode tests pin the observable endpoints.

## Review Log

### Review 2026-11-08, attempt 1: PASS
- Environment: Flutter 3.47.9 stable / Dart 3.13.7 (the workspace SDK), 2-core container, main @ `b3d70f2`.
- Code review of the diff (`32fb2ad..b3d70f2`): `_snapToStep` is exactly the `mentalityFromScale` math (`round(raw.clamp(0,100) * (steps-1) / 100)` → index → `round(index * 100 / (steps-1))`, Dart `.round()` half away from zero); the marker follows the finger (`_display` rides the raw position) while both callbacks only ever report snapped positions; release fires `onChangeEnd` from `onHorizontalDragEnd`/`onTapUp` and settles via the 150 ms easeOut controller that a new drag start stops mid-flight; step ticks render at every step position mirrored through the T-0061 `_xFor` seam (the free mode keeps its lone centre tick); `didUpdateWidget` snaps incoming external values so the marker can never park off-step. The free path is behaviourally identical to the pre-T-0062 code — the clamp/round order swap is equivalent for every input and the `_display` additions change no reported value; "byte-identical" in Developer Notes slightly overstates it, behaviour-identical is the accurate claim.
- The drag-end commit fix (Developer Notes concern 1) verified in code: stepped `onHorizontalDragEnd` always fires `onChangeEnd(_value)` even when the last update landed on the same step — the same-step-release bug is gone.
- Ran `flutter analyze` → `No issues found!` (zero warnings).
- Ran `flutter test test/core/ui/ test/features/squad/squad_view_test.dart test/features/match/tactics_scale_test.dart --concurrency=1` → **50/50 passed**: the 5 T-0061 RTL/LTR slider tests untouched and green; the 7 new T-0062 tests green (40 → 50, 95 → 100, near-min → 0; the boundary releases 24 → 0 / 25 → 50 / 75 → 100 with the thumb-inset gesture math; onChanged only ever reports step positions across a full-axis sweep; the pill names the snapped step; the marker settles exactly on the step; RTL drag-left still increases to the max step; free mode still commits raw positions); the squad-view mentality row 7/7 untouched; the enum-scale boundaries 6/6.
- Full `flutter test --concurrency=1` gate → **862/862 passed**.
- AC 3 verification note (recorded honestly): the 58/59 off-step releases are locked by composition, not by one end-to-end row test — the slider's snap formula is literally the same index math as `mentalityFromScale`, `tactics_scale_test.dart` locks 58 → Balanced / 59 → Positive and the canonical positions, and the row maps the committed scale through the unchanged `mentalityFromScale`. Every link is test-locked; a dedicated 7-step boundary release test would be reasonable hardening when T-0064 applies the slider to the nine axes. Not a blocker.
- `flutter run` manual check not possible in this headless container; the settle animation is covered by the pumpAndSettle-based tests instead (the marker-rests-on-step test pins the post-settle geometry to ±3 px).
- Acceptance criteria, one by one: free mode (`steps: null`) behaves exactly as today — existing tests untouched and green ✔; stepped mode commits only snapped positions and settles the marker on release in both text directions (new tests) ✔; the mentality row commits the same enum as before for 0/50/100 and the off-step 58/59 releases (by composition as above; the row suite green untouched) ✔; analyzer zero warnings and the full suite green ✔.
