# App structure: nine files still exceed the documented ~800-line convention
- Feature: app-structure
- Type: Refactor
- Priority: Minor
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Follow-up to `2026-11-04_app-structure_god-files-and-route-table.md` (now CLOSED): its two in-scope targets were split, but its blanket criterion "no file in `lib/` exceeds 1,000 lines" was over-broad — eight other files already exceeded it when that review was created, and the README's new "no god files (~800-line split threshold)" convention (README.md:72-74) is contradicted by nine files in the tree today. This review makes the convention real: split all of them following the proven `fcm_widgets.dart` barrel pattern so consumer imports never churn.

## Tasks
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

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] No file in `lib/` (excluding generated `*.g.dart`) exceeds 800 lines without a documented exception in the file's library doc
- [ ] Zero test edits beyond import-path moves absorbed by barrels — the 673-test suite green, plus `flutter test tool/simulation_report_test.dart` with determinism PASS
- [ ] `README.md` architecture table matches the post-split tree

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
