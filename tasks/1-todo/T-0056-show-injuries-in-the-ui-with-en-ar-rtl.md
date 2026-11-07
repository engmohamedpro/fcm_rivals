---
id: T-0056
title: Show injuries in the UI with EN-AR localization and RTL
priority: medium
status: todo
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

## Review Log
