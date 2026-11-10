---
id: T-0100
title: Remove the post-match pep talk step
priority: high
status: needs-review
attempts: 1
depends_on: []
created: 2026-11-09
completed:
---

# T-0100: Remove the post-match pep talk step

## Goal
When the full-time whistle blows, the match finishes straight into the report — the post-match pep-talk / recovery chooser card is gone entirely (owner request 2026-11-09). The half-time touchline talk stays exactly as is.

## Context
- The flow today (`lib/features/match/match_screen.dart`): `_finishMatch` (`:343-405`) sets up a `_recoveryChoice` completer and waits; the recovery card (built around `:440-530`) offers every `PepTalk.values` option (recovery bonuses), an ad-boosted recovery row (defeats only, GDD 19.3) and a 'No pep talk — default recovery' skip, with a two-tap scrim skip (`_confirmSkipOnScrim`, `:530-536`); the answer goes into `session.finish(pepTalk:, adBoostedRecovery:)`.
- `session.finish` (`lib/features/match/match_session.dart:474-480`) takes `PepTalk? pepTalk` and `bool adBoostedRecovery` with the GDD 19.4 mutual-exclusion assert.
- `enum PepTalk` (+ `PepTalkTarget`) lives at `lib/features/match/stamina.dart:135-165` — used ONLY by this post-match flow (the half-time talk is the separate `MatchPepTalk` family in `lib/features/match/touchline_pep_talk.dart` — DO NOT touch it).
- The report shows a pep-talk confirmation line (`lib/features/match/match_report_view.dart:99-113` field, `:305-320` usage, `RecoveryChoice` at `:587-589`).
- Tests pinning the card: five recovery-card tests in `test/features/match/match_screen_test.dart` (`:425` pep-talk commit, `:472` ad-boost after defeat, `:507` scrim double-tap, `:550` Arabic card, `:590` dispose mid-card) plus helpers around `:249-253` and `:398-413`.
- OWNER DECISION to record in the PR: the ad-boosted recovery option lives only inside this card — removing the step removes it too (no other surface offers it). If it should come back elsewhere, that is a NEW task, not this one's scope. Default recovery (the current no-choice path, `restDays = 3`) applies to every match after this change.

## Requirements
1. `lib/features/match/match_screen.dart` — delete the recovery chooser: the card builder, `_recoveryChoice`/`_recoveryPending`/`_scrimSkipArmed`/`_choiceMade`/`_answerRecovery` machinery, and the waiting in `_finishMatch`. Full time now calls `session.finish()` (no pep talk, no ad boost) and goes straight to the report with the same error/loading handling it has today.
2. `lib/features/match/match_session.dart` — `finish()` drops the `pepTalk` and `adBoostedRecovery` parameters and the GDD 19.4 assert; the PepTalk recovery-bonus application logic inside goes; every other persistence path (result, rewards, stamina, lockstep AI) is byte-identical. `restDays` stays.
3. `lib/features/match/stamina.dart` — delete `enum PepTalk` and `PepTalkTarget` once nothing references them (verify with grep first).
4. `lib/features/match/match_report.dart` / `match_report_view.dart` — remove the `pepTalk` field, the recovery-confirmation section and `RecoveryChoice`; the report's other sections untouched.
5. l10n — remove the keys that become unused (candidates: `postMatchRecoveryTitle`, `postMatchRecoveryIntro`, `recoveryBonusEffect`, `watchAdBoostedRecovery`, `watchAdBoostedEffect`, `noPepTalkDefault`, `tapAgainToSkip`, `pepTalkRecoveryConfirmation`, `pepTalkName`) — verify EACH is unreferenced before deleting (grep lib/ and test/), keep any the half-time flow or report still uses, regen localizations.
6. Tests — replace the five recovery-card tests with: full-time lands on the report with NO recovery card ever shown (both win and defeat paths); the report still renders its sections; stamina recovery applies the default. The half-time talk tests and every other match test stay green.

## Out of Scope
- The half-time `MatchPepTalk` chooser and its l10n (`lib/l10n/pep_talk_l10n.dart`) — untouched.
- Stamina/recovery math beyond removing the pep-talk bonus path; ads elsewhere in the app.
- The report's layout or any other report section.

## Acceptance Criteria
- [ ] After full time (win, draw or defeat) the report appears directly — no recovery card, no scrim, no completer wait; no dead UI state remains (no unreachable branches, no unused fields).
- [ ] `finish()` has no pep-talk or ad-boost parameters; `PepTalk`/`PepTalkTarget` are deleted from `stamina.dart`; `RecoveryChoice` and the report's pep-talk confirmation are gone.
- [ ] Only genuinely unused l10n keys were removed (both ARBs updated, regen clean); the half-time talk still renders EN and AR with its strings intact.
- [ ] `flutter analyze` zero warnings; match suite green with the reworked tests; full `flutter test` green, no REGEN_SNAPSHOT.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/match/
# Expected: green — recovery-card tests replaced by straight-to-report tests, half-time tests untouched

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

Manual: play a match to full time (win one, lose one) → the report opens immediately after the whistle; half-time still shows the touchline talk.

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


### Attempt 1 — implementation complete (gates run in the follow-up session)

Code done (all compiles, `flutter analyze` → No issues found):
1. `match_screen.dart` — recovery chooser fully removed (fields, completer, dispose unblock, `_finishMatch` wait, card builder, scrim machinery, build conditions); full time calls `session.finish()` straight to the report.
2. `match_session.dart` — `finish({int restDays = 3})`: pepTalk/adBoosted params + GDD 19.4 assert gone; stamina import dropped.
3. `collection_store_match.dart` — `applyMatchResult` params gone; the recovery branch is now plain natural+campus recovery for every match.
4. `stamina.dart` — `PepTalk`, `PepTalkTarget`, `pepTalkAppliesTo`, `applyPepTalkBonus` deleted.
5. `match_report_view.dart` — pepTalk/adBoostedRecovery fields, both status-line sections, `RecoveryChoice`, `RecoveryOption`, imports gone.
6. `lib/l10n/pep_talk_l10n.dart` DELETED; 12 keys + 1 @metadata entry removed from BOTH ARBs, gen-l10n regenerated; `l10n_test.dart` tapAgainToSkip assertion dropped.
7. Tests reworked (compile-clean, NOT yet run): match_screen_test — 5 recovery-card tests replaced by 2 straight-to-report tests (win + defeat, no card ever, no status lines, report sections render) + `driveToRecoveryCard` → `driveToFullTimeReport`; stamina_test — pep-talk group removed; ad_store_test — boosted-recovery comparison replaced by default-recovery sanity; injury_ui_test — pepTalk:null args dropped; match_session_test — pep-talk comparison replaced by determinism check; economy_simulator — boosted-recovery ad path replaced by plain finish().

**Gates (follow-up session):** three test fixes after the first full run — the two new T-0100 tests asserted a 'CONTINUE' label where the actual FcmButton reads 'Continue'; the legacy ratings-tab test still waited for the old card's 'No pep talk — default recovery' tap (its loop now breaks on the report's 'Full time:' line); the season live-flow test expected the card after full time (now asserts it findsNothing and proceeds straight to the report); the economy-simulator ads test expected adsWatched > 0 from the removed boosted-recovery path (now pins 0 — no rewarded ads on the settlement path anymore, and the simulator's two identical finish branches collapsed). `flutter analyze` → No issues found ✓. `flutter test test/features/match/` → **187/187 green** ✓. `flutter test test/features/season/season_live_match_flow_test.dart` → 1/1 ✓. `flutter test test/features/simulation/` → **13/13 green** ✓. Full `flutter test` → (result recorded in the submit commit message) ✓.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
