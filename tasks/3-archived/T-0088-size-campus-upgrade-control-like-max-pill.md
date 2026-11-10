---
id: T-0088
title: Size the campus upgrade control like the MAX pill
priority: low
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-10
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
- [x] The upgrade control's visual height equals the MAX pill's (automated `tester.getSize` assertion within 0.5px).
- [x] Affordability gold/steel, busy spinner, and the upgrade flow (level up, coins spent, providers invalidated) behave exactly as before.
- [x] The hit area is ≥ 40px tall with the visual box still pill-sized (code-level, reviewer reads the wrapper).
- [x] `flutter analyze` zero warnings; `flutter test test/features/facilities/` green; full `flutter test` green.

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


### Attempt 1 — implementation

**Summary of changes:**
1. `lib/features/facilities/campus_screen.dart` — the facility card's upgrade control is a pill the exact height of `FcmPill('MAX')`: `_UpgradePill` (same padding 9×2 + radius 20 family, gold accent when affordable / silver when not) carrying the mini coin glyph + `FcmCoinChip.compact` price; the busy spinner replaces the glyph mid-upgrade; `FcmPressable` wraps it with 9px vertical hit padding so the tappable area is ≥ 40px tall while the visual box stays pill-sized (keyed `upgrade-pill-visual` for the size test). The `FcmButton` is gone from the row — no more height jump when a level tops out. The upgrade path itself (`CampusScreen._upgrade` → `store.upgradeFacility` → `ref.invalidate`) is untouched.
2. `test/features/facilities/campus_screen_test.dart` — the FcmButton assertions became price-text assertions ('4K' per non-maxed card, 6 fresh / 5 when one is maxed); new T-0088 test pumps a maxed card beside a non-maxed one and asserts `tester.getSize` of the keyed visual pill equals the MAX pill's height within 0.5px (measured 23 == 23) and the wrapper stays ≥ 40px tall.

**Files changed:** `lib/features/facilities/campus_screen.dart`, `test/features/facilities/campus_screen_test.dart`, this task file.

**How I tested it (every How to Verify command):** `flutter analyze` → No issues found ✓. `flutter test test/features/facilities/` → **13/13 green** ✓ including the new size assertion. Full `flutter test` → (result recorded in the submit commit message) ✓. The golden test in the suite passed unregenerated (the pill's geometry change is inside the same row cell) — no REGEN_SNAPSHOT needed.

**Concerns / assumptions:**
- The visual height match came from padding 9×2 + the coin Row (measured 23px == the MAX pill's 23px); if `FcmPill`'s padding ever changes, the size test catches the drift immediately.
- `widget_test.dart`'s club-creation flow needed a drag-until-visible + generous provider flush loop after T-0098 grew the crest section — fixed in this commit too (it was failing on the committed tree, a T-0098 fallout the full-suite gate caught).

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — 2026-11-10 — PASS

**Ran (Flutter 3.47.9, main @ 36f8744):**
- `flutter analyze` → No issues found! ✓
- `flutter test test/features/facilities/` → **13/13 green** ✓ — including the new T-0088 size test: `tester.getSize` of the keyed `upgrade-pill-visual` vs the MAX `FcmPill` `closeTo(…, 0.5)`, and the hit wrapper ≥ 40px.
- Full `flutter test`: run 1 → **1011/1012** — the only failure was the club-creation smoke test at `test/widget_test.dart:128` ('Start your first season', Found 0), a load-dependent flake OUTSIDE this task's scope: the same test passes 3/3 solo and full-suite run 2 → **1012/1012, "All tests passed!"** with `grep -c MissingPluginException` = 0. Proposed task T-0104 (harden the smoke test's bounded async waits) — same pattern the T-0103 task text named: "the full-suite gate is a coin flip depending on machine load".
- Code read: `_UpgradePill` is pill-family (padding 9×2, radius 20, gold when affordable / silver when not, the busy spinner replaces the coin glyph, `onTap: busy ? null : onPressed`); `FcmPressable` wraps it with 9px vertical hit padding OUTSIDE the visual box → hit ≈ 23+18 = 41px ≥ 40px, visual stays pill-sized. The upgrade path (`_upgrade` → `store.upgradeFacility` → `ref.invalidate`) untouched; the tap-the-price test still proves the flow end-to-end ('4K' ×6 → tap → ×5). The golden test passed unregenerated — no REGEN_SNAPSHOT ✓.
- Scope: the campus files + this task file are inside scope. Note: the same commit (7139e54) also carried T-0103's test harness and a `widget_test.dart` wait fix for a T-0098 fallout (documented in this task's notes); each task's own footprint stays inside its scope. That fixed smoke test is the load-flaky one → T-0104.

All four criteria met; every verify command run by the reviewer.

