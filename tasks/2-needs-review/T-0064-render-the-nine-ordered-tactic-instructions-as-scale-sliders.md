---
id: T-0064
title: Render the nine ordered tactic instructions as scale sliders
priority: critical
status: needs-review
attempts: 1
depends_on: [T-0062, T-0063]
created: 2026-11-08
completed:
---

# T-0064: Render the nine ordered tactic instructions as scale sliders

## Goal
In the tactic options sheet, the nine ordered instructions render as stepped scale sliders — the same drag UX as mentality — on all three hosts, while `FinalThirdApproach` stays a chip row and the offside trap stays a toggle.

## Context
- The instructions today are tap-chips: `_SegmentedRow` / `_OptionChip` in `lib/features/match/tactics_sections.dart` (around lines 241-339).
- `TacticsGroupScaffold` is single-sourced for all three hosts, each going through `TacticsSetupView` -> `showTacticsOptionsSheet`: Team tab (`lib/features/squad/squad_screen.dart:88`), pre-match (`lib/features/match/pre_match_phases.dart:105`), live tactics (`lib/features/match/live_tactics_screen.dart:144`) — one change covers all three.
- Slider component: `FcmScaleSlider` with RTL mirroring (T-0061) and stepped snapping (T-0062). Scale mapping: the T-0063 generic helpers.
- l10n: every step label and axis title already exists in `lib/l10n/app_en.arb` and `app_ar.arb` (e.g. `lineDeep` / `lineStandard` / `lineHigh`, `pressLow` / `pressMid` / `pressHigh`, `tacticsDefensiveLine`, `tacticsPressing`). No new keys are needed for the nine axes.
- GDD 10.3: effects must stay visible — each row keeps the selected step's `modifiers.effectSummary` (`tactic_modifiers.dart`, format like `Defence +34% · Chances +16% · Stamina use +30%`), and the in-possession estimated-possession readout (`tacticsEstPossession`) and the rest-defence hint (`restDefenceHint`) stay.
- The reference implementation is the mentality row (`lib/features/squad/tactics_setup_view.dart`, around lines 440-466): label, slider, effect summary under the track, one commit per gesture on `onChangeEnd`.
- The nine axes and their enum fields: buildUp, tempo, width (In Possession); defensiveLine, pressing, tackling (Out of Possession); counterPress, attackOnRecovery, restDefence (Transitions).
- Zero-drift gates that must pass unchanged: `test/features/match/engine_snapshot_test.dart` locks the engine's measured profile over seeds 0..999 with per-metric tolerances, and `test/balance/` holds the win-rate / goals bands. This task touches no engine or model file, so both suites must pass with NO snapshot regeneration (`REGEN_SNAPSHOT` must not be used).
- T-0063 locked the axis polarity: on every axis the scale-100 end is the aggressive step and every default sits at 50 — the sliders render `minLabel` at the safe end and `maxLabel` at the aggressive end.

## Requirements
1. In `lib/features/match/tactics_sections.dart` add a private `_SliderRow<T extends Enum>`: the axis label (existing l10n key), an `FcmScaleSlider` with `steps: values.length`, `valueLabel` / `minLabel` / `maxLabel` from the existing per-value l10n labels, values mapped through the T-0063 helpers, and the selected step's `effectSummary` line under the track updating live during the drag.
2. Commit once per gesture: `onChangeEnd` -> `onChanged(tactics.copyWith(...))`, exactly like the mentality row; intermediate `onChanged` ticks only update the local pill and summary.
3. Replace the nine `_SegmentedRow` usages with `_SliderRow`: buildUp, tempo, width, defensiveLine, pressing, tackling, counterPress, attackOnRecovery, restDefence.
4. Keep `FinalThirdApproach` as the chip row (4 categorical styles, not a spectrum) and keep the offside-trap toggle chip with its deep-line warning unchanged.
5. Keep the estimated-possession readout (In Possession section) and the rest-defence hint (Transitions section).
6. Localize the mentality row's hardcoded English: add the seven mentality display names plus a mentality row/axis label key to BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`, using exactly these Arabic names — veryDefensive: `دفاعي للغاية`, defensive: `دفاعي`, cautious: `حذر`, balanced: `متوازن`, positive: `إيجابي`, attacking: `هجومي`, veryAttacking: `هجومي للغاية` (standard football-manager Arabic; EN keeps the enum display names). Use them in the sheet's mentality slider (`valueLabel`, `minLabel`, `maxLabel`, `semanticsLabel`) and in the control card's MENTALITY value row (`lib/features/squad/tactics_setup_view.dart` `_ControlCard`). `Mentality.effectSummary` strings stay as-is (engine-generated, separate concern).
7. Widget tests: for at least one axis per section (e.g. pressing), dragging to an end commits the end enum and the visible effect summary updates; `FinalThirdApproach` chips and the offside toggle are still present; one RTL (Arabic) pump proves the mirrored drag commits the same enum.

## Out of Scope
- Any change to the tactics model, enum values, engine constants or balance — the sliders only re-present the existing enums, so engine/balance drift is impossible by construction; the full suite proves it.
- New instruction granularity (e.g. 5 steps per axis) — that would require inventing new modifier anchors and re-running the balance sweeps; a separate project if ever wanted.
- Localizing `effectSummary` strings (engine-generated, game-wide — separate task).
- Localizing the control card's remaining fixed labels (TACTICS, TEAM RATING, Auto Pick) — only the MENTALITY value row is in scope here.
- The formation dropdown (stays on the control card).

## Acceptance Criteria
- [ ] The nine ordered axes render as stepped sliders in the tactic options sheet on all three hosts (Team tab, pre-match, live tactics); chips remain only for `FinalThirdApproach`; the offside toggle remains.
- [ ] One drag gesture commits exactly one tactics change — no commit on intermediate ticks.
- [ ] Every slider row shows the selected step's effect summary; the estimated-possession readout and rest-defence hint still render.
- [ ] EN and AR are fully labelled, including the seven mentality names; an RTL drag commits the same enum as the mirrored LTR drag.
- [ ] `flutter analyze` reports zero warnings; `flutter test` full suite green with no engine or model file changed.
- [ ] `test/features/match/engine_snapshot_test.dart` and `test/balance/` pass with no snapshot regeneration (`REGEN_SNAPSHOT` unused) — proof of zero engine/balance drift.
- [ ] Every slider's `minLabel` names the safe end and `maxLabel` the aggressive end (per the T-0063 polarity table).
- [ ] The sheet still scrolls inside its 0.85-height cap with all rows expanded — no overflow errors in the widget tests.

## How to Verify
```bash
flutter analyze
flutter test
flutter test test/features/match/ test/balance/   # zero-drift gates, no REGEN_SNAPSHOT
flutter run  # manual: Team tab -> TACTICS -> drag Pressing to the max end
```
Expected: analyze clean and the full suite green; the engine snapshot and balance suites pass untouched; manually the pressing pill reads the localized "High Press" with the summary `Defence +34% · Chances +16% · Stamina use +30%`; switching to Arabic mirrors the sliders, the mentality pill reads `هجومي للغاية` at the max end, and the mirrored drags commit the same selections; the pre-match and LIVE tactics surfaces show the same sheet.

---

## Developer Notes

- **Summary of changes:** The nine ordered tactic axes render as stepped scale sliders in `tactics_sections.dart` through a new private `_SliderRow<T extends Enum>` (stateful): axis label (existing l10n key, uppercased), `FcmScaleSlider` with `steps: values.length`, `valueLabel`/`minLabel`/`maxLabel` from the existing per-value l10n labels mapped through the T-0063 helpers (`enumToScale` for the marker position, `enumFromScale` for commits), and the selected step's `modifiers.effectSummary` under the track updating live during the drag (local `_scale` state follows `onChanged` ticks; the pill + summary stream the crossed steps). One commit per gesture: `onChangeEnd` -> the existing `onSelect(tactics.copyWith(...))` — identical wiring to the mentality row. `values.first` labels the safe end (minLabel) and `values.last` the aggressive end (maxLabel) per the T-0063 polarity table, enforced by the existing polarity-guard test. `FinalThirdApproach` keeps its `_SegmentedRow` chip row, the offside-trap toggle chip + deep-line warning are untouched, the estimated-possession readout and the rest-defence hint stay. Mentality l10n (requirement 6): 8 new keys (`tacticsMentality` + the seven `mentality*` names, AR exactly as specified: دفاعي للغاية/دفاعي/حذر/متوازن/إيجابي/هجومي/هجومي للغاية) added to `app_en.arb`, `app_ar.arb`, `app_localizations.dart` (abstract), `app_localizations_en.dart`, `app_localizations_ar.dart`; a `mentalityDisplayName(l10n, m)` switch wires them into the sheet's slider (valueLabel/minLabel/maxLabel/semanticsLabel) and the control card's MENTALITY value row (`l10n.tacticsMentality.toUpperCase()` — the card's other fixed labels stay English, Out of Scope). `Mentality.displayName` stays the engine-facing English constant.
- **Files changed:** lib/features/match/tactics_sections.dart (+_SliderRow, 9 rows swapped), lib/features/squad/tactics_setup_view.dart (mentalityDisplayName helper, sheet slider + control card l10n), lib/l10n/app_en.arb, app_ar.arb, app_localizations.dart, app_localizations_en.dart, app_localizations_ar.dart (+8 keys each per locale), test/features/squad/squad_view_test.dart (5 new T-0064 tests + updated assertions), test/features/season/season_live_match_flow_test.dart (DONE reveal fix — see concerns).
- **How I tested it:** `flutter analyze` — No issues found. `flutter test test/features/squad/squad_view_test.dart` — **12/12**: structure test now locks 10 sliders, the three categorical final-third chip texts, the Off toggle, Est. possession + rest-defence hint, and `takeException() isNull` (no overflow in the 0.85-cap sheet with all rows expanded); three drag tests (one axis per section — buildUp→Long Ball, pressing→High Press, counterPress→Immediate Counter-Press) each assert ONE commit per gesture, the committed enum, the pill naming the snapped step scoped to its slider, and the visible summary strings (Defence +34% · Chances +16% · Stamina use +30% for High Press); the RTL Arabic pump asserts the localized mentality names (متوازن/دفاعي للغاية/هجومي للغاية) and that the MIRRORED drag-left commits the same High Press enum as LTR. `season_live_match_flow_test` + `live_match_ux_test` + `pre_match_screen_test` — **25/25** (the other two hosts render the same sheet). Zero-drift gates: `flutter test test/features/match/ test/balance/` — **266/266 green, REGEN_SNAPSHOT never set**, no engine or model file touched (git diff confirms only UI + l10n + test files). Full `flutter test` — all green — 867/867.
- **Concerns / assumptions:** (1) **Pre-existing gap found (NOT introduced here):** `app_ar.arb` is missing ~47 tactic keys that exist in `app_en.arb` (the axis titles like `tacticsBuildUp`/`tacticsPressing` and step names like `pressLow`/`lineDeep`/`buildUpPlayOut`) — the AR implementation class carries English fallback values for them, so the Arabic sheet shows English axis labels today. The task Context asserted these keys "already exist in both arb files"; they exist in the ARB→class generated layer, not in `app_ar.arb`. Translating 47 game-strings is a real task of its own (football terminology needs owner review) — flagged here rather than half-done silently; the AR class fallbacks keep the RTL pump fully functional, and the mentality names (the in-scope part) are properly Arabic. (2) The four DONE-button taps in tests needed `ensureVisible` because the sheet grew ~9 slider rows past the fold — the old fixed `-900` scroll hack stopped reaching DONE; same for the season flow test (one-line fix, same reason). (3) The slider-count assertions use fixed indices (`.at(4)` pressing etc.) matching the sheet's build order — stable because the section order is GDD-fixed; a comment in the test records the order. (4) `_SliderRow` keeps its own `_scale` mirroring the slider's echo-guard seam (same pattern as the mentality row) so an owner-echo never fights the local drag state.

## Review Log
