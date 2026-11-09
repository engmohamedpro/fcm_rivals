---
id: T-0088
title: Size the campus upgrade control like the MAX pill
priority: low
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
---

# T-0088: Size the campus upgrade control like the MAX pill

## Goal
On each campus facility card, the upgrade control occupies the same visual size as the MAX pill shown at max level — today the swap between a 44px-tall `FcmButton` and a ~24px gold pill makes the row jump. After this task both states look like one continuous control.

## Context
- `lib/features/facilities/campus_screen.dart:220-234` (inside `FacilityCard.build`): `maxed` → `const FcmPill('MAX')`; otherwise → `FcmButton(compact: true, coinValue: price, label: '', loading: busy, style: affordable ? gold : steel, onPressed: busy ? null : onUpgrade)`.
- Sizes today: `FcmPill` (`lib/core/ui/fcm_chip.dart:15-48`) — padding 9×3, radius 20, gold fill, fontSize 12 w900, height ≈ 24; `FcmButton` compact (`lib/core/ui/fcm_button.dart:22-161`) — height 44, horizontal padding 18, radius 16. `FcmButton` has no width parameter.
- Interpretation (owner wording: "button to upgrade same size as max" — the button adapts to the pill): the upgrade control renders at the MAX pill's HEIGHT with pill-family styling (radius, fill, font scale) and the compact coin price inside. Width fits the price text.
- Touch-target mitigation is mandatory: a ~24px visual is too small to tap, so the pressable wrapper carries the hit padding — visual box stays pill-sized, hit box ≥ 40px tall.
- The upgrade path itself is untouched: `CampusScreen._upgrade` (`campus_screen.dart:34-53`) → `store.upgradeFacility` (`lib/features/collection/campus_store.dart:49-112`) → `ref.invalidate(campusProvider)`.
- Tests live in `test/features/facilities/campus_screen_test.dart` (asserts pill/button presence, not sizes) and `campus_visual_golden_test.dart`.

## Requirements
1. `lib/features/facilities/campus_screen.dart` — replace the `FcmButton` in the facility card row with a pill-sized upgrade control: same height as `FcmPill('MAX')`, same corner-radius/fill family (gold when affordable, steel when not), containing `FcmCoinGlyph` + the compact price (`FcmCoinChip.compact`), the busy spinner preserved, disabled while busy.
2. The control's hit area is ≥ 40px tall via wrapper padding (e.g. `FcmPressable`/`InkResponse` with padding outside the visual pill) — the visual box must not grow.
3. Tests (`test/features/facilities/campus_screen_test.dart`): update the upgrade-control assertions to the new widget/key; add a size assertion — pump a card below max level next to a maxed card and check `tester.getSize` of the upgrade control's visual box equals the MAX pill's height within 0.5px.
4. If `campus_visual_golden_test.dart` changes, regenerate via the documented `REGEN_SNAPSHOT` flow and state it in the notes.

## Out of Scope
- `campus_store.upgradeFacility`, prices, `maxLevel`, the rest of the facility card (effect text, level bar).
- `FcmButton`/`FcmPill` core widgets themselves (build the pill-styled control locally or compose `FcmPill` inside a pressable — do not reshape the shared widgets).
- Any other screen.

## Acceptance Criteria
- [ ] The upgrade control's visual height equals the MAX pill's (automated `tester.getSize` assertion within 0.5px).
- [ ] Affordability gold/steel, busy spinner, and the upgrade flow (level up, coins spent, providers invalidated) behave exactly as before.
- [ ] The hit area is ≥ 40px tall with the visual box still pill-sized (code-level, reviewer reads the wrapper).
- [ ] `flutter analyze` zero warnings; `flutter test test/features/facilities/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/facilities/
# Expected: facilities suite green including the new size assertion

flutter test
# Expected: full suite green (goldens regenerated only via the documented flow)
```

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
