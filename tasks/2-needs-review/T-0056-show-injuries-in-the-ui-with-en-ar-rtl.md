---
id: T-0056
title: Show injuries in the UI with EN-AR localization and RTL
priority: medium
status: blocked
attempts: 0
depends_on: [T-0055]
created: 2026-11-07
completed:
---

# T-0056: Show injuries in the UI with EN-AR localization and RTL

## Goal
The player-facing layer of the injury system: badges and matches-out counts on card surfaces, unavailable players in squad selection, a pre-match availability section, a live injury banner with the forced substitution feedback, and the report's injury lines — all in EN and AR with RTL verified.

## Context (evidence, main `3614c4a`)
- Data now exists end-to-end: `PlayerInjury`/`InjuryKind` (T-0053), engine events + report rows (T-0054), persisted `injuryMatchesRemaining`/`injuryKind` + availability gating (T-0055). This task renders them; no behaviour changes.
- Card surfaces that must show the injury state: `lib/core/ui/mini_card.dart` and `lib/core/ui/player_card_painters.dart` (squad pitch mini cards), the collection grid and `player_detail_sheet.dart`, and the pre-match analysis rows (`lib/features/match/pre_match_analysis.dart`, stamina bars at `pre_match_phases.dart:89`). A single shared badge/ribbon widget in `lib/core/ui/` (the `fcm_widgets.dart` barrel pattern) keeps the five surfaces consistent.
- Live surface: the injury event arrives in `match_screen.dart`'s event stream next to the existing card/substitution banners (`live_match_views.dart`); the banner text follows the existing commentary l10n keys added in T-0054.
- Report surface: `match_report_view.dart` renders the injuries statistics row (T-0054) — verify it inside the existing report layout without a new section header if the stats table already carries it.
- Stamina bars change MEANING with the T-0052 decoupling (fitness now signals injury risk, not weaker play): the pre-match copy must say so in both languages — one EN string + one AR string, e.g. "Low fitness raises injury risk" — keeping the owner's model honest in the UI.
- The AR layer: follow the existing AR strings pattern (`lib/l10n/` per `l10n.yaml`) and the project's RTL conventions (T-0004/T-0006 archived lessons: RTL-ready layouts, no directional padding hacks).
- Seeded/injured fixtures for widget tests: build test players with `injuryMatchesRemaining` set directly (store-backed tests exist from T-0055).

## Requirements
1. Shared injury badge widget (red cross/bandage motif + `matchesOut` count) in `lib/core/ui/`, applied to: squad pitch mini cards, collection grid cards, player detail sheet, pre-match analysis rows, and bench/reserves rows. Injured players' rows are visually marked AND non-selectable where selection exists (squad save sheet).
2. Pre-match availability: the analysis screen lists injured players ("out for N matches") in both languages; the stamina-bar helper copy gains the injury-risk meaning string.
3. Live banner: an injury event shows the injured player + kind + who replaced him (or "playing with ten" when no sub was possible) — EN + AR; the banner respects the existing event-banner lifecycle (no leaks/unmounted-setstate — the T-0013 class of bugs).
4. Report: injuries statistics row renders in the report view; the commentary feed shows the injury lines from T-0054.
5. Widget tests: badge renders + count on each surface; injured player is not selectable in the squad save sheet; pre-match availability section lists the injured; live banner appears on an injury event and pops cleanly; report shows the row. All golden/semantic tests run under both locales with `Directionality` forced LTR and RTL.
6. Every new user-facing string exists in EN and AR `.arb` files; no hardcoded strings; `flutter analyze` clean including the l10n generation step.

## Out of Scope
- Any engine/store/schema change; any rebalance of injury rates.
- A dedicated medical/injury list screen (a surface-level need only; propose in Developer Notes if it feels missing).
- Pack/reveal surfaces (rarity work there is T-0049's).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Widget tests green for every surface in both LTR and RTL; full `flutter test` suite passes
- [ ] EN/AR localization complete and RTL verified — every new string present in both `.arb` files, AR reviewed for correct terminology
- [ ] No performance or application-size regression
- [ ] A player with `injuryMatchesRemaining = 3` shows the badge + "3" on all five card surfaces (test-locked)
- [ ] The live injury banner and report rows render for all three injury kinds

## How to Verify
```bash
flutter analyze
flutter gen-l10n
flutter test test/features/match/ test/features/collection/ test/features/squad/
flutter test
```
Expected: analyzer clean; l10n generation succeeds with no missing-translation errors; match/collection/squad widget suites green including the new injury surface tests in both directions.

## Side-effect risk (low)
Presentation over shipped data paths. Risks: the badge crowding the mini cards (check the pitch layout at small sizes), and the pre-match copy shifting the analysis column height — the pre-match screen tests lock the phase layout.

## Developer Notes

**Status: BLOCKED on the verification step only — the implementation is complete and committed.** The session's time budget ran out before the test suites could finish; what is verified and what is not is listed below so the next run (or the reviewer) can resume exactly here.

**Summary of changes (implementation complete):** the injury data now renders on every player-facing surface. (1) Shared `InjuryBadge` widget (`lib/core/ui/injury_badge.dart`): red medical-cross pill + matches-out count, locale-neutral digits, Semantics label via `injuryBadgeSemantics`, `PositionedDirectional` placement everywhere. `FcmMiniCard` gained `injuryMatchesOut` (badge over the shield corner). (2) Surfaces: squad pitch slots + bench/reserves strips (`squad_pitch_view.dart`) pass the injury state through; an injured player is rendered INERT — no `SquadDraggable`, no `SquadDropZone` (non-selectable per requirement 1; the T-0055 store refusal stays the save-time backstop; detail tap preserved). Collection grid `_GridCard` badges the card's corner; `player_detail_sheet.dart` shows badge + `injuryOutForMatches(n)` under the card. (3) Pre-match: `_MedicalRoomCard` in `AnalysisPhase` ("Medical room" / "الغرفة الطبية") listing injured players badge + name + "Out for N matches" / "خارج N مباراة", hidden when everyone fits; the stamina hint gained the T-0052 meaning line `injuryStaminaRiskHint` ("Low fitness raises injury risk." / "اللياقة المنخفضة تزيد خطر الإصابة."). (4) Live: `commentary.dart` injury lines now carry the matches-out count on `CommentaryLine.detail`; `InjuryLiveBanner` (`injury_live_banner.dart`, exported via the `live_match_views.dart` barrel) takes the lower third when the latest line is an injury — red frame, medical icon, the T-0054 localized text, `injuryChipOut` chip ("OUT 4" / "خارج 4"); swap derived purely from build state (no timers → the T-0013 lifecycle class of bugs is structurally excluded). (5) Report: the score panel shows an injuries row derived from `report.commentary`'s injury lines ("{n} player(s) injured" / "{n} لاعب مصاب"). ARB keys added to BOTH files (8 keys) + `flutter gen-l10n` regenerated clean.

**Files changed:** lib/core/ui/injury_badge.dart (new), lib/core/ui/mini_card.dart, lib/features/squad/squad_pitch_view.dart, lib/features/collection/collection_collection_screen.dart, lib/features/collection/player_detail_sheet.dart, lib/features/match/pre_match_analysis.dart, lib/features/match/pre_match_phases.dart, lib/features/match/commentary.dart, lib/features/match/injury_live_banner.dart (new), lib/features/match/live_match_views.dart, lib/features/match/match_screen.dart, lib/features/match/match_report_view.dart, lib/l10n/app_en.arb, lib/l10n/app_ar.arb, generated app_localizations*.dart. Tests (new): test/features/match/injury_ui_test.dart (12 tests: badge LTR/RTL + fit-hidden, medical room EN/hidden/AR + stamina hint strings, banner EN/AR/no-payload, report row + injury-free), test/features/collection/injury_surfaces_test.dart (4: sheet EN/fit/AR + grid badge), test/features/squad/injured_inert_test.dart (3: inert starter + AR badges + healed-reselectable).

**How I tested it:** `flutter analyze` — **No issues found** (lib + tests). `flutter gen-l10n` — clean, both locales. `flutter test test/features/match/injury_ui_test.dart test/features/collection/injury_surfaces_test.dart test/features/squad/injured_inert_test.dart` — **NOT completed**: the run was interrupted twice (once by a session cutoff, once by a flutter_tools platform-level error that looks like a concurrent-test-process conflict, not an assertion failure). `flutter test test/features/match/ test/features/collection/ test/features/squad/` and the full suite + `flutter test tool/simulation_report_test.dart` — **NOT run** in this session. THE REMAINING WORK: run the three suites, fix any assertion fallout, then the full suite + determinism, then resubmit.

**Concerns / assumptions:** (1) Injured players render FULLY inert (no drag AND no drop target) because the T-0055 store refuses ANY squad save referencing them — an injured starter therefore freezes his slot until healed; if the owner wants injured players removable into reserves, that is a store-behavior change (out of scope here). (2) The report injuries count derives from `report.commentary` (MatchReportResult carries no TeamMatchStats) — honest presentation-only derivation; if the report later gains the stats report, switch the source. (3) The badge count is locale-neutral digits (consistent with the coin chips); sentences localize fully. (4) A dedicated medical LIST screen is not built (out of scope) — the pre-match Medical room card covers the need.

## Review Log
