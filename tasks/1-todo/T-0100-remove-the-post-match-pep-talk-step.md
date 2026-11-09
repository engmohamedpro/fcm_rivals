---
id: T-0100
title: Remove the post-match pep talk step
priority: high
status: todo
attempts: 0
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

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
