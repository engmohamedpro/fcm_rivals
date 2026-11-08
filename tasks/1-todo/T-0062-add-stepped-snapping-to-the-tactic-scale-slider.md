---
id: T-0062
title: Add stepped snapping to the tactic scale slider
priority: medium
status: todo
attempts: 0
depends_on: [T-0061]
created: 2026-11-08
completed:
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
- [ ] Free mode (`steps: null`) behaves exactly as today — existing tests untouched and green.
- [ ] Stepped mode commits only snapped positions and settles the marker on release in both text directions (new tests).
- [ ] The mentality row commits the same enum as before for release positions 0, 50, 100 and the off-step releases 58 (→ Balanced) and 59 (→ Positive).
- [ ] `flutter analyze` reports zero warnings; `flutter test` full suite green.

## How to Verify
```bash
flutter analyze
flutter test
flutter run  # manual: Team tab -> TACTICS -> drag Mentality
```
Expected: analyze clean, full suite green; manually the marker settles on the seven step positions and the pill names them.

---

## Developer Notes

## Review Log
