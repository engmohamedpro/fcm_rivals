# Localization regression: squads screen crashes without l10n delegates; v9 migration test stale
- Feature: localization
- Type: Bug
- Priority: Critical
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
Re-review verification of `2026-11-04_localization_missing-ar-layer-and-rtl-unsafe-layout` ran the FULL `flutter test` suite (which the developer skipped for time): 3 tests fail, 2 of them real regressions introduced by the localization commit `7d95068`. `SquadScreen.build` now calls `AppLocalizations.of(context)!` and crashes with "Null check operator used on a null value" in any `MaterialApp` that does not install the localization delegates (the shipped app does; direct widget tests and any embedded/host usage do not — the screen is no longer self-contained). Separately, `schema_v9_migration_test` pins `schemaVersion == 9` and rewinds only to v8, so the v10 migration double-applies and throws "duplicate column name: locale".

## Tasks
- [ ] Task 1: Make SquadScreen resolve l10n defensively | Where: `lib/features/squad/squad_screen.dart:85` (`AppLocalizations.of(context)!.openPacksHint`) and the snackbar site (`bestSquadSelected`, ~line 194) | Expected: either a null-aware fallback (`AppLocalizations.of(context)?.openPacksHint ?? 'Open packs to collect players, then tap Auto Pick.'`) or a private `String _l10n(BuildContext)` helper with the English fallback for both sites; `test/features/squad/squad_screen_test.dart:58` (plain `MaterialApp`, no delegates) pumps green with the hint text visible; the AR path still resolves through the delegates when present.
- [ ] Task 2: Update the schema migration test to the v10 world | Where: `test/features/season/schema_v9_migration_test.dart:81` (`expect(db.schemaVersion, 9)`) and the rewind phase that sets `PRAGMA user_version = 8` while the on-disk tables now also lack `user_settings.locale` | Expected: the test either (a) becomes `schema_v10_migration_test.dart`: rewind to v9 (drop `ai_players.real_player_id` is no longer needed — instead create the v9 shape and `PRAGMA user_version = 9`), reopen, assert `user_version == 10` and `PRAGMA table_info('user_settings')` contains `locale`; or (b) keeps the v8→v9 body and only relaxes the version assertion to `greaterThanOrEqualTo(9)` plus a separate v10 assertion; the migration must apply exactly once (no "duplicate column name" error) and both tests pass.
- [ ] Task 3: Adopt the l10n delegates in the failing widget test as the pattern guard | Where: `test/features/squad/squad_screen_test.dart:55-61` (`MaterialApp(home: Scaffold(body: SquadScreen()))`) | Expected: after Task 1 the plain pump passes; ADDITIONALLY add one variant pumping `SquadScreen` with `localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, locale: Locale('ar')` asserting the Arabic hint text renders — this is the committed pattern every future localized screen test copies; run `flutter test` full suite and paste the tail (expect 0 failing) in Developer Notes.

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] `flutter test` full suite exits with 0 failing tests (was 3)
- [ ] SquadScreen renders under a plain MaterialApp without crashing (null-safe l10n)
- [ ] Schema migration test asserts v10 and applies each step exactly once

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
