---
id: T-0061
title: Mirror the tactic scale slider in RTL locales
priority: high
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-08
completed:
---

# T-0061: Mirror the tactic scale slider in RTL locales

## Goal
`FcmScaleSlider` renders and behaves correctly when the ambient text direction is RTL (Arabic), mirroring like Flutter's own `Slider`, so the same component can be reused for every tactic axis.

## Context
- `lib/core/ui/fcm_scale_slider.dart` is the branded 0-100 scale slider (gold marker, floating pill, centre tick). Its only user today is the mentality row of the tactic options sheet (`lib/features/squad/tactics_setup_view.dart`, around line 445).
- The widget is LTR-hardcoded: `Positioned(left: ...)` for the thumb / filled track / centre tick / pill clamp, `_updateFromDx` maps raw touch dx left-to-right onto 0-100, and the pill `TextPainter` fixes `TextDirection.ltr` (line 110).
- The app ships EN + AR (`lib/l10n/app_ar.arb`, `lib/l10n/l10n_context.dart`), so today's Arabic mentality slider is wrong-sided: minimum on the left, fill running the wrong way.
- Existing slider interactions are tested in `test/features/squad/squad_view_test.dart` (findsOneWidget around line 266, drag around line 351) — those run LTR and must stay green untouched.
- RTL test precedent to copy the pattern from: `test/core/ui/shell_directionality_test.dart` pumps the whole `GameShell` under an explicit `TextDirection.rtl`. The new slider tests go in a new `test/core/ui/fcm_scale_slider_test.dart`.

## Requirements
1. In `lib/core/ui/fcm_scale_slider.dart`, resolve `Directionality.of(context)` once per build and mirror every horizontal position in RTL: thumb x, filled-track width, centre tick, and the pill clamp region.
2. Mirror the gesture mapping in RTL so the minimum end sits at the RIGHT (Flutter `Slider` convention): in RTL, dragging towards the left increases the value, and tap-to-set lands on the mirrored position.
3. The pill label `TextPainter` must measure with the ambient text direction so Arabic pill text lays out correctly.
4. The min/max caption row must show the min caption at the min end in both directions (a `Row` already flips child order under RTL — verify with a test, force `textDirection` only if the test proves it necessary).
5. New widget tests in `test/core/ui/fcm_scale_slider_test.dart`: pump the slider under `Directionality(textDirection: TextDirection.rtl)` and assert (a) at value 0 the thumb sits at the right end and the fill spans from the right, (b) a drag from centre towards the left raises the value (and towards the right lowers it), (c) the pill stays clamped inside the track with Arabic label text.

## Out of Scope
- Stepped snapping / tick marks (T-0062).
- Applying the slider to the other nine tactic axes (T-0064).
- Any change to track, tick, thumb or pill styling and colors.

## Acceptance Criteria
- [ ] Under LTR the widget renders and commits exactly as before — `test/features/squad/squad_view_test.dart` passes untouched.
- [ ] In RTL the minimum end is on the right and dragging left increases the value (new test proves it).
- [ ] The floating pill clamps inside the track and measures Arabic text RTL (new test).
- [ ] `flutter analyze` reports zero warnings.
- [ ] New RTL widget tests exist and pass.

## How to Verify
```bash
# from the repo root
flutter analyze
flutter test test/core/ui/
flutter test test/features/squad/squad_view_test.dart
```
Expected: analyze clean; the new `fcm_scale_slider_test.dart` (RTL cases), the rest of `test/core/ui/` and the squad view suite are green; no behaviour change in EN/LTR.

---

## Developer Notes

- **Summary of changes:** `FcmScaleSlider` now mirrors under an ambient RTL direction, matching Flutter's own `Slider` convention. The direction resolves once per `didChangeDependencies` (`Directionality.of`) and drives: (1) the thumb position (`markerLeft` = mirrored x − radius), (2) the filled track (RTL: `left = rtlThumbX`, `width = w − rtlThumbX`, gradient flipped so the fill reads gold-soft→gold from the RIGHT), (3) the pill clamp anchor (mirrored thumb x, same clamp bounds), (4) the gesture mapping (`_updateFromDx` mirrors dx as `width − dx` in RTL, so the minimum sits at the RIGHT, dragging left increases the value, tap-to-set lands mirrored), (5) the pill `TextPainter` measures with the ambient direction so Arabic pill text lays out correctly. The centre tick needs no change (it sits at w/2 either way); the min/max caption `Row` flips child order under RTL automatically — verified by the pill-clamp test pumping Arabic captions, no forced textDirection needed.
- **Files changed:** lib/core/ui/fcm_scale_slider.dart, test/core/ui/fcm_scale_slider_test.dart (new).
- **How I tested it:** `flutter analyze` — No issues found. New `test/core/ui/fcm_scale_slider_test.dart` — **5/5 passed**: RTL value 0 → thumb anchored at the RIGHT end; RTL centre drag LEFT raises the value (and drag RIGHT lowers it); RTL tap near the right edge sets a low value (< 20); the pill with a long Arabic label stays clamped inside the slider bounds and rides above the track; LTR baseline value 0 → thumb at the LEFT end (the untouched pre-T-0061 behaviour). `flutter test test/core/ui/ test/features/squad/squad_view_test.dart --concurrency=1` — **37/37 passed**, the squad view mentality-slider suite untouched and green (LTR behaviour identical).
- **Concerns / assumptions:** (1) The thumb is located in tests as the rightmost/leftmost ≤22px decorated container inside the slider — stable against the pill (22px tall band but wide) and captions; if the marker styling ever changes size the finder tolerance (6px) absorbs small drift. (2) No styling/colour changed anywhere (Out of Scope) — only geometry mirroring and direction-aware measuring. (3) Snapping (T-0062) and the nine instruction axes (T-0064) are untouched; this task leaves the component reusable exactly as the T-0061→T-0062 dependency chain expects.

## Review Log
