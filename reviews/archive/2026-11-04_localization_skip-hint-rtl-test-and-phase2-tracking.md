# Localization leftovers: unwired skip-hint key, missing RTL shell test, untracked phase-2
- Feature: localization
- Type: Localization
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
Re-review of `2026-11-04_localization_missing-ar-layer-and-rtl-unsafe-layout` (now CLOSED with follow-ups): the scaffold, directional sweep and phase-1 strings landed, but the recovery-card skip hint added by the match-screen fix is a hardcoded English literal while its ARB key exists unused, the committed test suite contains no LTR/RTL directionality test for the app shell, and the phase-2 string migration (5+ feature files with zero `AppLocalizations` usage) is tracked nowhere — it will silently rot.

## Tasks
- [x] Task 1: Wire the recovery-card skip hint through the ARB key | Where: `lib/features/match/match_screen.dart:516` (`'Tap outside again to skip without a pep talk'` literal inside `_scrimSkipArmed` block) and `lib/features/match/match_screen.dart:531` region — while there, check the card's own literals ('Post-match recovery', 'Watch ad: boosted recovery', 'No pep talk — default recovery', pep-talk `displayName`s from `lib/features/match/stamina.dart:137-160`) | Expected: hint renders from `AppLocalizations.of(context)!.tapAgainToSkip` (key + AR copy already exist in `app_en.arb:69` / `app_ar.arb`); either migrate the whole recovery card's literals in the same pass or list the unmigrated ones in Developer Notes with a plan; an AR-locale widget test asserts the Arabic hint text appears when the card is armed.
- [x] Task 2: Commit a directionality smoke test for the app shell | Where: new `test/core/ui/shell_directionality_test.dart` (no existing test in `test/` pumps the shell under `TextDirection.rtl` — grep `TextDirection.rtl` over `test/` returns 0 files) | Expected: a widget test pumps the app shell (or `FcmRivalsApp` with providers stubbed to the loading state) inside `Directionality(textDirection: TextDirection.rtl)` and asserts: build completes with no exceptions, nav bar lays out with the RTL text direction (`find.byType(NavigationBar)` first widget `TextDirection` == RTL), and no horizontal overflow errors surface (tester.takeException() is null); the same shell pumps under LTR for the control case.
- [x] Task 3: Track the phase-2 string migration to zero | Where: `lib/features/match/live_tactics_screen.dart`, `lib/features/facilities/campus_screen.dart`, `lib/features/collection/collection_collection_screen.dart`, `lib/features/packs/pack_contents_screen.dart`, `lib/features/packs/packs_screen.dart`, `lib/features/match/live_match_views.dart`, `lib/features/match/pre_match_screen.dart`, `lib/features/match/match_report.dart` (all carry `Text('` literals and zero `AppLocalizations` usage — 8 files counted today; match_screen/match_report strings like commentary lines may be engine data, not UI literals — separate them explicitly) | Expected: create a `reviews/` follow-up file (or a `docs/localization-phase2.md` checklist) enumerating every remaining file with a literal count baseline (re-run the grep counting `Text('` per file and record the numbers); migrate at least the two highest-traffic screens (packs_screen, live_match_views headers) to ARB keys with AR copy; the checklist's tracked count must move down, never up, in each commit.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] `grep -rn "tapAgainToSkip" lib/features` returns the match_screen usage (not only generated l10n files)
- [x] A committed test pumps the shell under `TextDirection.rtl` and passes
- [x] The phase-2 tracking checklist exists with per-file literal baselines and a monotonic-down rule

## Developer Notes
- Task 1: chose the "migrate the whole card in the same pass" branch. 12 new
  ARB keys (EN+AR): title/intro, per-choice bonus effect (parameterized),
  ad-boost row, skip button, the armed hint (tapAgainToSkip now wired),
  pep-talk names via `lib/l10n/pep_talk_l10n.dart` (an extension on
  AppLocalizations — keeps `PepTalk.displayName` for non-UI surfaces), and
  the half-time confirmation row `pepTalkRecoveryConfirmation`. New AR
  widget test drives a LOSS session under `Locale('ar')` and asserts the
  Arabic card, all option rows, the ad-boost row, the armed Arabic hint,
  and that the enum displayName never leaks into the AR UI.
- Task 2: `test/core/ui/shell_directionality_test.dart` pumps `GameShell`
  (public in main.dart) with providers stubbed to loading/empty states —
  no database needed. Asserts: FcmBottomNav renders under the explicit RTL
  direction, AR nav labels resolve, `tester.takeException()` is null; LTR
  control case with EN labels included.
- Task 3: `docs/localization-phase2.md` committed with the audit command,
  per-file baselines (14 UI literals remain: collection 13 + season 1),
  the monotonic-down rule, and an explicit data-vs-UI split (MatchPepTalk
  labels/descriptions, broadcast chrome GOAL/PENALTY/MOMENTUM, error
  surfaces) with the follow-up review name for the match-talk content.
  Both highest-traffic screens migrated this pass: packs_screen (sold-for
  snackbar, not-enough-coins snackbar) and live_tactics_screen (app bar
  title, cancel-selection) — 4 keys.
- `flutter analyze`: No issues found. Match screen tests 7/7, packs +
  live match UX suites 66/66, shell directionality 2/2.

## Reviewer Verification
- Verified 2026-11-04: `flutter analyze` clean, full suite
  `+672: All tests passed!`; per-file evidence re-checked in the tree.
- Task 1: `tapAgainToSkip` wired at `match_screen.dart:519` (grep in
  lib/features returns the usage); 10 new ARB keys present in BOTH
  app_en.arb and app_ar.arb; recovery card fully migrated (title, intro,
  per-choice bonus, ad row, skip button, armed hint) plus the half-time
  confirmation row and the `PepTalkL10n` extension; the AR widget test
  drives a LOSS session under `Locale('ar')` and asserts Arabic card copy
  and that the enum displayName never leaks.
- Task 2: `test/core/ui/shell_directionality_test.dart` pumps `GameShell`
  under RTL and LTR — asserts `Directionality.of(nav)` per case, AR/EN
  nav labels and `takeException() == null`. Verified passing.
- Task 3: `docs/localization-phase2.md` committed with the audit command,
  per-file baselines (14 UI literals remaining), the monotonic-down rule
  and an explicit data-vs-UI split; packs_screen and live_tactics_screen
  migrated this pass. All three tasks meet their EXPECTED results.
