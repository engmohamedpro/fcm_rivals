# Localization leftovers: unwired skip-hint key, missing RTL shell test, untracked phase-2
- Feature: localization
- Type: Localization
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Re-review of `2026-11-04_localization_missing-ar-layer-and-rtl-unsafe-layout` (now CLOSED with follow-ups): the scaffold, directional sweep and phase-1 strings landed, but the recovery-card skip hint added by the match-screen fix is a hardcoded English literal while its ARB key exists unused, the committed test suite contains no LTR/RTL directionality test for the app shell, and the phase-2 string migration (5+ feature files with zero `AppLocalizations` usage) is tracked nowhere — it will silently rot.

## Tasks
- [ ] Task 1: Wire the recovery-card skip hint through the ARB key | Where: `lib/features/match/match_screen.dart:516` (`'Tap outside again to skip without a pep talk'` literal inside `_scrimSkipArmed` block) and `lib/features/match/match_screen.dart:531` region — while there, check the card's own literals ('Post-match recovery', 'Watch ad: boosted recovery', 'No pep talk — default recovery', pep-talk `displayName`s from `lib/features/match/stamina.dart:137-160`) | Expected: hint renders from `AppLocalizations.of(context)!.tapAgainToSkip` (key + AR copy already exist in `app_en.arb:69` / `app_ar.arb`); either migrate the whole recovery card's literals in the same pass or list the unmigrated ones in Developer Notes with a plan; an AR-locale widget test asserts the Arabic hint text appears when the card is armed.
- [ ] Task 2: Commit a directionality smoke test for the app shell | Where: new `test/core/ui/shell_directionality_test.dart` (no existing test in `test/` pumps the shell under `TextDirection.rtl` — grep `TextDirection.rtl` over `test/` returns 0 files) | Expected: a widget test pumps the app shell (or `FcmRivalsApp` with providers stubbed to the loading state) inside `Directionality(textDirection: TextDirection.rtl)` and asserts: build completes with no exceptions, nav bar lays out with the RTL text direction (`find.byType(NavigationBar)` first widget `TextDirection` == RTL), and no horizontal overflow errors surface (tester.takeException() is null); the same shell pumps under LTR for the control case.
- [ ] Task 3: Track the phase-2 string migration to zero | Where: `lib/features/match/live_tactics_screen.dart`, `lib/features/facilities/campus_screen.dart`, `lib/features/collection/collection_collection_screen.dart`, `lib/features/packs/pack_contents_screen.dart`, `lib/features/packs/packs_screen.dart`, `lib/features/match/live_match_views.dart`, `lib/features/match/pre_match_screen.dart`, `lib/features/match/match_report.dart` (all carry `Text('` literals and zero `AppLocalizations` usage — 8 files counted today; match_screen/match_report strings like commentary lines may be engine data, not UI literals — separate them explicitly) | Expected: create a `reviews/` follow-up file (or a `docs/localization-phase2.md` checklist) enumerating every remaining file with a literal count baseline (re-run the grep counting `Text('` per file and record the numbers); migrate at least the two highest-traffic screens (packs_screen, live_match_views headers) to ARB keys with AR copy; the checklist's tracked count must move down, never up, in each commit.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] `grep -rn "tapAgainToSkip" lib/features` returns the match_screen usage (not only generated l10n files)
- [ ] A committed test pumps the shell under `TextDirection.rtl` and passes
- [ ] The phase-2 tracking checklist exists with per-file literal baselines and a monotonic-down rule

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
