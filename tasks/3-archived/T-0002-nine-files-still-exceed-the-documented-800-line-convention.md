---
id: T-0002
title: Nine files still exceed the documented ~800-line convention
priority: medium
status: done
attempts: 0
depends_on: [T-0025, T-0026, T-0027, T-0030, T-0028, T-0022, T-0024, T-0029, T-0023, T-0021]
created: 2026-11-04
completed: 2026-11-07
# migrated from: reviews/tasks/2026-11-04_app-structure_remaining-oversized-files.md
---

# T-0002: Nine files still exceed the documented ~800-line convention

## Goal
Umbrella record for the god-file cleanup: nine oversized files are split via ten follow-up tasks; this file closes when those follow-ups and the enforcement task are archived.

## Context
> **Record shell (migrated 2026-11-06):** this file was status SPLIT on the old reviews/ board — its executable work was handed over to the follow-up tasks listed in `depends_on`. There is nothing to implement in this file; it is kept for traceability and closes only when all of its `depends_on` tasks are archived.

Follow-up to `2026-11-04_app-structure_god-files-and-route-table.md` (now CLOSED): its two in-scope targets were split, but its blanket criterion "no file in `lib/` exceeds 1,000 lines" was over-broad — eight other files already exceeded it when that review was created, and the README's new "no god files (~800-line split threshold)" convention (README.md:72-74) is contradicted by nine files in the tree today. This review makes the convention real: split all of them following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Requirements
- [ ] Task 1: Split the match engine into domain, commands and engine | Where: `lib/features/match/match_engine.dart` (1,970 lines; `MatchEvent`:69, `MatchPlayer`:113, `MatchTeamInput`:164, `MatchEngineConfig`:198, `MatchCommand` hierarchy:309) | Expected: `match_event.dart` (enums + event/player/team-input models + config) and `match_commands.dart` (the command hierarchy), engine core stays; pure Dart, no behaviour change — `engine_snapshot_test.dart` and `engine_calibration_test.dart` green with zero test edits and identical seed output; every resulting file ≤800 lines.
- [ ] Task 2: Extract the report view and ratings panels out of MatchScreen | Where: `lib/features/match/match_screen.dart` (1,296 lines; `_RecoveryOption`:753, `MatchReportView`:824, `_RatingsTabs`:1136, `_RatingsPanel`:1205) | Expected: `match_report_view.dart` owns `MatchReportView`, the ratings tabs/panels and the recovery widgets; `match_screen.dart` keeps the live-match shell; screen behaviour and widget tree identical — `match_screen_test.dart`, `live_match_ux_test.dart` and `season_live_match_flow_test.dart` green with zero test edits.
- [ ] Task 3: Extract the reveal timeline and painters from the pack opening screen | Where: `lib/features/packs/pack_opening_screen.dart` (1,278 lines; `_Tl` timeline:72, `_MysteryPainter`:1044, `_ChainButton`:1110, `_ChainHandoffLine`:1242) | Expected: `pack_reveal_timeline.dart` (the `_Tl` spec) and `pack_opening_widgets.dart` (painter + chain buttons/handoff line); reveal animations frame-identical — the pack opening/squad reveal suites green with zero test edits.
- [ ] Task 4: Move the season data classes out of SeasonStore | Where: `lib/features/season/season_store.dart` (1,263 lines; `SeasonSummary`:38, `NextFixture`:65, `SeasonCompletion`:84, `AiOpponentSquad`:110) | Expected: `season_models.dart` holds the data classes; `SeasonStore` keeps lifecycle/logic only; season suites and simulation harness green with zero test edits.
- [ ] Task 5: Split the player card into card, mini card and painters | Where: `lib/core/ui/player_card.dart` (1,247 lines; `FcmPlayerCardBack`:393, `_CardFacePainter`:504, `_CardBackPainter`:837, `FcmMiniCard`:938, `_GhostPainter`:1088) | Expected: `mini_card.dart` (FcmMiniCard + ghost/stat/stamina widgets) and `player_card_painters.dart` (the CustomPainters); a `player_card.dart` barrel keeps the existing import path; `player_card_test.dart` and `mini_card_test.dart` green with zero test edits.
- [ ] Task 6: Extract the result models and pack catalog from the CollectionStore facade | Where: `lib/features/collection/collection_store.dart` (1,243 lines; result models `PackOpenResult`:46 … `UpgradePurchaseResult`:145, offer building around :618) | Expected: `collection_results.dart` (the seven result/exception classes) and `pack_catalog.dart` (offer building/pricing over the registry); the facade composes `ClubStore`/`SquadStore`/`CampusStore` plus the new catalog and lands ≤900 lines; schema and behaviour unchanged — store/facilities/economy suites green with zero test edits.
- [ ] Task 7: Split live match views into header, commentary and touchline families | Where: `lib/features/match/live_match_views.dart` (1,206 lines; header/momentum family :27-613, commentary/key-moment family :614-947, `TouchlinePepTalkCard`:948) | Expected: `match_header.dart` (MatchHeader, TeamChip, MomentumBar, LiveDot, SpeedSelector), `match_commentary.dart` (CommentaryRow, KeyMomentCard, EventRow, FillerRow) and `touchline_pep_talk.dart`; `live_match_views.dart` may remain as a barrel; live UX tests green with zero test edits.
- [ ] Task 8: Split the pre-match screen by phase | Where: `lib/features/match/pre_match_screen.dart` (1,179 lines; analysis family :204-772, tactics/pep-talk/bottom-bar family :773+) | Expected: `pre_match_analysis.dart` (opponent header, forecast, strength, mirror bar, top players) and `pre_match_phases.dart` (tactics phase, pep-talk phase/tiles, bottom bar); `pre_match_screen_test.dart` and the live match flow green with zero test edits.
- [ ] Task 9: Split the match report models from commentary construction | Where: `lib/features/match/match_report.dart` (1,004 lines; `CommentaryKind`:17, `CommentaryLine`:44, `TeamMatchStats`:75, `PlayerMatchRating`:358) | Expected: commentary kinds/lines and their building move to `commentary.dart`; stats/rating models stay; `pass_completion_stats_test.dart` and report tests green with zero test edits.
- [ ] Task 10: Enforce the convention mechanically | Where: `lib/` tree | Expected: after Tasks 1-9, `find lib -name "*.dart" ! -name "*.g.dart" -exec wc -l {} + | awk '$1>800 && $2!="total"'` returns only consciously-cleared exceptions (none expected); README architecture table gains a row per new top-level module family; `flutter analyze` clean; full suite green.

## Out of Scope
- Any implementation in this file; all work lives in the follow-up tasks (`depends_on`).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] No file in `lib/` (excluding generated `*.g.dart`) exceeds 800 lines without a documented exception in the file's library doc
- [ ] Zero test edits beyond import-path moves absorbed by barrels — the 673-test suite green, plus `flutter test tool/simulation_report_test.dart` with determinism PASS
- [ ] `README.md` architecture table matches the post-split tree

## How to Verify
Run the board's standard gates:

```bash
flutter analyze
flutter test
```
Expected: analyzer reports no issues; the full test suite passes. Per-task checks are quoted in Requirements and Developer Notes.

---

## Review Log
### 2026-11-06 — board migration
- Migrated from `reviews/` to the `tasks/` board as `T-0002` (was `reviews/tasks/2026-11-04_app-structure_remaining-oversized-files.md`, status SPLIT).
- Record shell: executable work lives in the `depends_on` follow-ups.

- 2026-11-05 (structural split per README §1 — one file per independently executable task): the ten bundled tasks are each independently executable and now live in ten follow-up files under `reviews/tasks/` (listed under Follow-up). Status OPEN → SPLIT. Each follow-up copies its requirements, targets and evidence per README §7 so no work is reconstructed from this file; the enforcement task additionally declares `Depends on` the nine splits. The task text above is unchanged historical record; execute the work only in the follow-up files.

### 2026-11-07 — record shell closed (all dependencies archived; reviewer closure per repo-owner instruction)
- All `depends_on` tasks are in `tasks/3-archived/`: the nine split follow-ups (T-0022..T-0030) and the mechanical enforcement gate T-0021 (closed 2026-11-07 with full gate evidence: over-800 check returns zero files on main `c552ad6`, README table matches the tree, `flutter analyze` clean, `flutter test` +709 all passed exit 0).
- Its designed closure condition — "closes only when all of its `depends_on` tasks are archived" — is met. Acceptance criteria verified as part of T-0021's closure: no file in `lib/` (excluding `*.g.dart`) exceeds 800 lines (largest remaining: `lib/l10n/app_localizations.dart` 788); no documented exceptions required; suite green; determinism PASS recorded in the T-0043 review log (REPORT_WRITTEN); README architecture table matches the post-split tree (27 path tokens + 15 directories checked).
- No code change was ever required in this file (record shell, Out of Scope: any implementation here); attempts stays 0 by design. Task closed and archived — the god-file cleanup campaign is complete.

## Historical Links
- Follows: `2026-11-04_app-structure_god-files-and-route-table` (backfilled 2026-11-05 by the lifecycle audit `2026-11-05_reviews_lifecycle-compliance-audit`; the prose reference above predates the formal field)
- Follow-up: `2026-11-05_app-structure_split-match-engine`, `2026-11-05_app-structure_split-match-screen-report`, `2026-11-05_app-structure_split-pack-reveal-widgets`, `2026-11-05_app-structure_split-season-models`, `2026-11-05_app-structure_split-player-card`, `2026-11-05_app-structure_split-collection-results-catalog`, `2026-11-05_app-structure_split-live-match-views`, `2026-11-05_app-structure_split-pre-match-screen`, `2026-11-05_app-structure_split-commentary`, `2026-11-05_app-structure_enforce-line-budget`
