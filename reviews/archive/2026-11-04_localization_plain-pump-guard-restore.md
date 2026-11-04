# Localization: SquadScreen plain-MaterialApp guard lost; l10nOf fallback copy unasserted
- Feature: localization
- Type: Test
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: CLOSED
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
Re-review of `2026-11-04_localization_squad-l10n-crash-and-schema-test` (now CLOSED): the fix's `l10nOf` helper is correct and the suite is green, but the implemented `bootScreen` harness now installs the l10n delegates on EVERY pump — the plain `MaterialApp` (no delegates) pump that Task 1 requested as the self-containment guard no longer exists anywhere in `test/`. The `l10nOf` fallback branch is executed only indirectly (the packs reveal path, `lib/features/packs/packs_screen.dart:163`, runs under a plain MaterialApp), so a reintroduced `AppLocalizations.of(context)!` in SquadScreen would pass the whole suite and ship — the exact regression class the original Critical was filed for.

## Tasks
- [x] Task 1: Restore the plain pump as the squad screen's first test | Where: `test/features/squad/squad_screen_test.dart:56-64` (`bootScreen` unconditionally wires `localizationsDelegates` + `supportedLocales`) | Expected: the DEFAULT `bootScreen()` call (used by 'empty squad still shows the full tactical setup') pumps `SquadScreen` under a plain `MaterialApp` with NO delegates and asserts the English hint `'Open packs to collect players, then tap Auto Pick.'` renders — proving the fallback bundle flows through; the delegates+AR variant stays as the second test unchanged; both green in one `flutter test test/features/squad` run.
- [x] Task 2: Assert fallback copy somewhere user-visible | Where: `test/features/packs/packs_screen_test.dart` (the reveal flows already pump under a plain MaterialApp, but no test asserts the sold-for snackbar — `grep -rn "Sold for" test/` returns 0) | Expected: EITHER (a) one test claims an owned pack, sells the revealed player and asserts the English `'Sold for … coins'` fallback snackbar renders, OR (b) a focused widget test pumps a plain `MaterialApp` whose builder calls `l10nOf(context)` and asserts `.openPacksHint` equals the ARB English string — either closes the "fallback returns wrong/throws" hole with an explicit copy assertion.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] A test pumps SquadScreen under a plain MaterialApp (no delegates) and passes with the English hint visible
- [x] `grep -rn "localizationsDelegates" test/features/squad/squad_screen_test.dart` shows delegates only on the AR variant's pump, not the default pump

## Developer Notes
- Task 1: `bootScreen(tester, {Locale? locale})` now branches — `locale ==
  null` pumps a plain `const MaterialApp` (no delegates at all), the AR
  variant keeps the delegates + `supportedLocales`. The first test's
  existing `'Open packs to collect players, then tap Auto Pick.'`
  assertion IS the fallback-copy proof under the plain pump.
- Task 2 (option a): new test 'SELL from the reveal shows the English
  sold-for fallback snackbar' — claims the owned pack, walks the reveal
  timeline to done (`pump(18s)` covers the 17s legendary reveal before
  the action bar stops ignoring pointers), taps SELL, then asserts the
  full parameterized copy with `matches(RegExp(r'^Sold for [\d,]+
  coins$'))` and that the collection shrank by one. Structural
  `find.descendant(of: SnackBar)` scoping was avoided on purpose: the
  snackbar rebuilds mid-animation and presents as two elements sharing
  a GlobalKey, so a findsOneWidget on the type is flaky; the regex on
  the rendered Text data asserts the copy end-to-end without that
  brittleness.
- Full suite after both tasks: `02:49 +673: All tests passed!` (672
  before — the new sell test is the +1). `flutter analyze`: No issues
  found.

## Reviewer Verification
- Verified 2026-11-04 by re-running the checks, not reading the notes:
  `flutter analyze` — No issues found; full `flutter test` suite —
  `02:49 +673: All tests passed!` (0 failing, 0 skipped; the +1 over the
  previous 672 is the new sell test).
- Task 1: `bootScreen` branches on `locale == null` — the default pump is
  a plain `const MaterialApp` with no delegates anywhere
  (`squad_screen_test.dart:61-74`), and the first test drives it and
  asserts the English fallback hint
  'Open packs to collect players, then tap Auto Pick.'
  (`:87-93`). The AR variant keeps the delegates + `supportedLocales`
  and asserts the Arabic hint (`:131-141`). Acceptance grep holds:
  `localizationsDelegates` appears in the file only inside the AR
  branch (`:68-69`), never on the default pump.
- Task 2 (option a): the new test 'SELL from the reveal shows the
  English sold-for fallback snackbar'
  (`packs_screen_test.dart:271-337`) claims the owned pack, walks the
  reveal timeline to done (`pump(18s)` covers the 17s legendary case),
  taps SELL, asserts a SnackBar is present, the full parameterized copy
  via `matches(RegExp(r'^Sold for [\d,]+ coins$'))` (`:329`), and that
  the owned collection shrank by exactly one (`ownedBefore - 1`).
  `grep -rn "Sold for" test/` now returns hits (was 0 when the review
  was filed).
- The two-flow regression net requested by the original Critical is now
  real: the fallback branch runs under a plain pump in the squad suite
  AND end-to-end through the packs reveal path. No residual gaps.
