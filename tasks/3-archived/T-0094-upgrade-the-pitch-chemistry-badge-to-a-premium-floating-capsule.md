---
id: T-0094
title: Upgrade the pitch chemistry badge to a premium floating capsule
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-09
---

# T-0094: Upgrade the pitch chemistry badge to a premium floating capsule

## Goal
The XI chemistry reading above the pitch becomes a premium floating capsule: a polished glass-dark pill with an icon, the full localized label (no more truncated 'CHEMI…'), and the '+N%' value that counts up smoothly to its final number whenever the squad changes (owner request 2026-11-09: "make chemistry effect float to the end, premium UI/UX").

## Context
- Today's badge is `lib/features/squad/squad_pitch_view.dart:405-450` — `_ChemistryBadge`, a bare `Row` of two `Text`s (a 5-char-truncated label + '+N%'), pinned above the top penalty box inside an `IgnorePointer` (lines 114-129). It reads flat and cut-off, not premium.
- "Float to the end" interpretation (state it in the PR): the badge keeps floating over the top strip of the pitch artwork as it does today, and its value animates — a `FcmCountUp` count-up — floating to the final reading whenever the XI changes; nothing about the chemistry formula or the badge's position changes.
- `chemistryPercent` is computed in `tactics_setup_view.dart:104-106` (T-0067 formula: starting-XI nationalities only) and passed into `SquadPitch` — the same badge serves the Team tab, pre-match and live tactics surfaces; the upgrade applies to all three (same widget, no flag).
- Existing premium idioms to reuse: `FcmCountUp` (used by the control card's rating at `tactics_setup_view.dart:322`), `FcmColors` (gold/bronze/surface), and the file's own rating colour ramp — today the value paints `ratingColor(70 + percent * 3)` for percent ≥ 1 and dim for 0; keep that colour semantics.
- The label comes from `l10nOf(context).teamChemistry` — both locales exist already. The truncation hack (`label.length > 5 ? …`) exists only because the badge had no background; the capsule removes the need for it.
- Tests pinning the badge today: `test/features/squad/squad_view_test.dart:805` ('the XI chemistry badge renders ON the pitch (+4%)') and `:841` (empty XI hides the badge). The '+4%' text assertion must keep passing after the upgrade (FcmCountUp settles to the final text).

## Requirements
1. `lib/features/squad/squad_pitch_view.dart` — rebuild `_ChemistryBadge` as a floating capsule: a rounded pill (radius ~14-16) over a translucent dark surface (surface colour at high alpha, e.g. `FcmColors.surface.withValues(alpha: 0.85)`) with a thin gold border (alpha ~0.35), containing: a small chemistry-flavoured icon (e.g. `Icons.link_rounded`, 12-14px, gold-tinted), the full localized `teamChemistry` label (still uppercase, now untruncated), and the value.
2. The value counts up: replace the value `Text` with `FcmCountUp` so a changed chemistry settles on the new '+N%' with the count animation; keep the existing colour semantics (`ratingColor(70 + percent * 3)` for percent ≥ 1, dim for 0).
3. One subtle entrance when the value changes (a single scale/fade pulse on the capsule, ~200-300ms, the file's animation idiom) — no looping animation, no per-frame work while idle.
4. The capsule stays: inside the existing `IgnorePointer` + `Positioned` top strip (lines 114-129), compact (capsule height ≤ 30px at default scale), never overlapping the top-line player chips' tap targets, and correct in RTL (Row order mirrors; use start/end alignment, no hardcoded left/right).
5. Update the two badge tests if needed (they must still pass — '+4%' rendered on the pitch, empty XI hides the badge) and add:
   - a test that a squad change re-renders the badge with the new settled value (e.g. seed an XI at +2%, swap in a nationality match, settle → '+3%' (or whatever the real formula gives) is on screen after the animation);
   - an Arabic-locale RTL pump asserting the capsule renders with the Arabic label and the value, mirrored (icon on the start side).

## Out of Scope
- The chemistry formula, its inputs or its display position (T-0067/T-0069/T-0080 decisions).
- The pitch artwork, player cards, stamina bars or any other pitch element.
- Adding chemistry to bench/reserves or anywhere outside the starting XI.
- The tactics summary row (T-0092) or the options sheet height (T-0095).

## Acceptance Criteria
- [x] The chemistry reading renders as a dark translucent capsule with gold border, icon, full untruncated localized label and the '+N%' value — above the pitch as today, on the Team tab, pre-match and live surfaces alike.
- [x] The value counts up to its final number on squad changes and settles on the exact reading; idle state is static (no looping animation).
- [x] Colour semantics unchanged: 0 reads dim, n ≥ 1 reads through the rating ramp; contrast stays legible on the grass (capsule background, not bare text).
- [x] Renders correctly in EN and AR under RTL (mirrored capsule, Arabic label, no overflow at the 5-char-equivalent label lengths).
- [x] Existing badge tests still pass; the new change-settle and AR-RTL tests green; `flutter analyze` zero warnings; `flutter test test/features/squad/` green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/squad/squad_view_test.dart
# Expected: all pass — existing badge tests plus the new settle and AR/RTL tests

flutter test test/features/squad/
# Expected: whole squad suite green

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes

### Attempt 1 — implementation

**Summary of changes:** the chemistry reading above the pitch is now a premium floating capsule: a 28px dark glass pill (surface at 0.85 alpha, radius 15, thin gold border at 0.35) containing a gold `Icons.link_rounded` (13px), the FULL localized `teamChemistry` label (the 5-char truncation is gone — it existed only because bare text had no background) and an `FcmCountUp` value that floats to the new '+N%' whenever the squad changes. One subtle 240ms scale/fade pulse fires on the value change only; idle is fully static. Colour semantics unchanged (dim at 0, ratingColor ramp at n ≥ 1). Position unchanged: the same IgnorePointer + Positioned top strip, same widget on Team/pre-match/live surfaces (no flag), compact ≤ 30px, RTL-safe (Row order mirrors, no hardcoded edges).

1. `lib/features/squad/squad_pitch_view.dart` — `_ChemistryBadge` rebuilt as a StatefulWidget: `_pulse` controller, `didUpdateWidget` fires the pulse + re-keys the FcmCountUp on percent change; capsule Container/Row/Icon/Text/FcmCountUp.
2. `test/features/squad/squad_view_test.dart` — the four badge tests updated to the full labels ('CHEMISTRY' / 'الكيمياء'), plus icon-on-capsule, top-strip bounds, and AR RTL icon-position (start/right edge) assertions, and two NEW tests: **change-settle** (XI at +1% → two players swap to Brazil → count-up settles on '+2%', old text gone, idle static) and **glass-pill shape** (decoration: surface 0.85 background, gold 0.35 border, height ≤ 30).

**Files changed:** `lib/features/squad/squad_pitch_view.dart`, `test/features/squad/squad_view_test.dart`, this task file.

**How I tested it:** `flutter analyze` → No issues found ✓. `flutter test test/features/squad/squad_view_test.dart` → **18/18 green** ✓. `flutter test test/features/squad/` → **238/238 green** ✓. Full `flutter test --concurrency=1` — **NOT run this session** (session time budget; the squad suite covers every touched surface) — flagged for the reviewer to trigger CI or re-run.

**Concerns / assumptions:**
- "Float to the end" interpreted exactly as the task's Context reads: the badge keeps floating over the pitch's top strip AND its value floats (counts up) to the final reading — position and formula untouched.
- Session incident: the first capsule implementation was lost to a workspace hiccup mid-session (the file reverted to HEAD while its tests stayed updated — all failures traced to the OLD badge rendering 'CHEMI…'). Re-applied the identical implementation; all tests then passed with no further test changes.
- FcmCountUp is re-keyed on the percent change so the count restarts from 0 to the new value; the first build also counts up once (700ms) — the control card's rating idiom.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — PASS (2026-11-09)

Ran every How to Verify command, all green — including the full suite the developer flagged as not run (their time budget):
- `flutter analyze` → No issues found.
- `flutter test test/features/squad/squad_view_test.dart` → 18/18.
- `flutter test test/features/squad/` → 238/238.
- Full `flutter test` → **954/954** (+2 = the two new T-0094 tests), no REGEN_SNAPSHOT.

Checked each acceptance criterion against real code and behavior:
- Capsule: 28px dark glass pill (surface 0.85, radius 15, gold border 0.35, 13px gold link icon), full untruncated `teamChemistry` label, `FcmCountUp` value; same `IgnorePointer` top strip and same widget on all three surfaces (no flag — Team/pre-match/live share `SquadPitch`). Pinned by the glass-pill shape test reading the real `BoxDecoration` and the ≤30 height constraint.
- Count-up + settle + idle static: `didUpdateWidget` fires one 240ms scale/fade pulse on percent change only; controller disposed; the change-settle test drives a real chemistry change (+1% → 2 Egypt + 2 Brazil → +2%), asserts the old text gone mid-count, settles on the exact new reading and stays static on a plain frame.
- Colour semantics: identical `ratingColor(70 + percent*3)` / dim-at-0 logic as before; legibility now on the capsule background rather than bare text over grass.
- EN/AR RTL: full 'الكيمياء' label, icon mirrored to the start (right) edge — asserted with measured positions, capsule inside pitch bounds.
- Removed test lines were only the old 'CHEMI…'/'الكيم…' truncation assertions — replaced by stronger full-label + icon + bounds checks; no assertion weakened.

Scope check: `squad_pitch_view.dart` + `squad_view_test.dart` + this task file only — exactly the task's files. Formula, position and pitch artwork untouched. No regressions.

All criteria met — PASS.
