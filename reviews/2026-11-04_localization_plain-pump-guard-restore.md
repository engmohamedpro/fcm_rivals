# Localization: SquadScreen plain-MaterialApp guard lost; l10nOf fallback copy unasserted
- Feature: localization
- Type: Test
- Priority: Major
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Re-review of `2026-11-04_localization_squad-l10n-crash-and-schema-test` (now CLOSED): the fix's `l10nOf` helper is correct and the suite is green, but the implemented `bootScreen` harness now installs the l10n delegates on EVERY pump — the plain `MaterialApp` (no delegates) pump that Task 1 requested as the self-containment guard no longer exists anywhere in `test/`. The `l10nOf` fallback branch is executed only indirectly (the packs reveal path, `lib/features/packs/packs_screen.dart:163`, runs under a plain MaterialApp), so a reintroduced `AppLocalizations.of(context)!` in SquadScreen would pass the whole suite and ship — the exact regression class the original Critical was filed for.

## Tasks
- [ ] Task 1: Restore the plain pump as the squad screen's first test | Where: `test/features/squad/squad_screen_test.dart:56-64` (`bootScreen` unconditionally wires `localizationsDelegates` + `supportedLocales`) | Expected: the DEFAULT `bootScreen()` call (used by 'empty squad still shows the full tactical setup') pumps `SquadScreen` under a plain `MaterialApp` with NO delegates and asserts the English hint `'Open packs to collect players, then tap Auto Pick.'` renders — proving the fallback bundle flows through; the delegates+AR variant stays as the second test unchanged; both green in one `flutter test test/features/squad` run.
- [ ] Task 2: Assert fallback copy somewhere user-visible | Where: `test/features/packs/packs_screen_test.dart` (the reveal flows already pump under a plain MaterialApp, but no test asserts the sold-for snackbar — `grep -rn "Sold for" test/` returns 0) | Expected: EITHER (a) one test claims an owned pack, sells the revealed player and asserts the English `'Sold for … coins'` fallback snackbar renders, OR (b) a focused widget test pumps a plain `MaterialApp` whose builder calls `l10nOf(context)` and asserts `.openPacksHint` equals the ARB English string — either closes the "fallback returns wrong/throws" hole with an explicit copy assertion.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] A test pumps SquadScreen under a plain MaterialApp (no delegates) and passes with the English hint visible
- [ ] `grep -rn "localizationsDelegates" test/features/squad/squad_screen_test.dart` shows delegates only on the AR variant's pump, not the default pump

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
