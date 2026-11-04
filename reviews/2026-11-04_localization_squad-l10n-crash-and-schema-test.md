# Localization regression: squads screen crashes without l10n delegates; v9 migration test stale
- Feature: localization
- Type: Bug
- Priority: Critical
- Reviewer: Coach Hady
- Created: 2026-11-04
- Status: DONE
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
Re-review verification of `2026-11-04_localization_missing-ar-layer-and-rtl-unsafe-layout` ran the FULL `flutter test` suite (which the developer skipped for time): 3 tests fail, 2 of them real regressions introduced by the localization commit `7d95068`. `SquadScreen.build` now calls `AppLocalizations.of(context)!` and crashes with "Null check operator used on a null value" in any `MaterialApp` that does not install the localization delegates (the shipped app does; direct widget tests and any embedded/host usage do not — the screen is no longer self-contained). Separately, `schema_v9_migration_test` pins `schemaVersion == 9` and rewinds only to v8, so the v10 migration double-applies and throws "duplicate column name: locale".

## Tasks
- [x] Task 1: Make SquadScreen resolve l10n defensively | Where: `lib/features/squad/squad_screen.dart:85` (`AppLocalizations.of(context)!.openPacksHint`) and the snackbar site (`bestSquadSelected`, ~line 194) | Expected: either a null-aware fallback (`AppLocalizations.of(context)?.openPacksHint ?? 'Open packs to collect players, then tap Auto Pick.'`) or a private `String _l10n(BuildContext)` helper with the English fallback for both sites; `test/features/squad/squad_screen_test.dart:58` (plain `MaterialApp`, no delegates) pumps green with the hint text visible; the AR path still resolves through the delegates when present.
- [x] Task 2: Update the schema migration test to the v10 world | Where: `test/features/season/schema_v9_migration_test.dart:81` (`expect(db.schemaVersion, 9)`) and the rewind phase that sets `PRAGMA user_version = 8` while the on-disk tables now also lack `user_settings.locale` | Expected: the test either (a) becomes `schema_v10_migration_test.dart`: rewind to v9 (drop `ai_players.real_player_id` is no longer needed — instead create the v9 shape and `PRAGMA user_version = 9`), reopen, assert `user_version == 10` and `PRAGMA table_info('user_settings')` contains `locale`; or (b) keeps the v8→v9 body and only relaxes the version assertion to `greaterThanOrEqualTo(9)` plus a separate v10 assertion; the migration must apply exactly once (no "duplicate column name" error) and both tests pass.
- [x] Task 3: Adopt the l10n delegates in the failing widget test as the pattern guard | Where: `test/features/squad/squad_screen_test.dart:55-61` (`MaterialApp(home: Scaffold(body: SquadScreen()))`) | Expected: after Task 1 the plain pump passes; ADDITIONALLY add one variant pumping `SquadScreen` with `localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, locale: Locale('ar')` asserting the Arabic hint text renders — this is the committed pattern every future localized screen test copies; run `flutter test` full suite and paste the tail (expect 0 failing) in Developer Notes.

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] `flutter test` full suite exits with 0 failing tests (was 3)
- [x] SquadScreen renders under a plain MaterialApp without crashing (null-safe l10n)
- [x] Schema migration test asserts v10 and applies each step exactly once

## Developer Notes
- Task 1: added `lib/l10n/l10n_context.dart` — `l10nOf(context)` returns the
  ambient AppLocalizations or falls back to `lookupAppLocalizations(Locale('en'))`,
  so no string is duplicated in Dart and every screen stays self-contained
  under a plain MaterialApp. Both SquadScreen sites (hint + snackbar) now
  resolve through it. Chosen over per-site `?.` fallbacks: one helper, zero
  drift between sites, and the fallback bundle IS the ARB source of truth.
- Task 2 (option a): `schema_v9_migration_test.dart` replaced by
  `schema_v10_migration_test.dart`. One rewind helper builds the v8 shape
  (no real_player_id, no locale) and optionally adds the v9 column, so both
  a v8 and a v9 install walk the real upgrade path; asserts user_version ==
  db.schemaVersion, surviving rows (stamina 88, match_speed 3), each added
  column exactly once, and real_player_id preserved across the v9→v10 step.
- Task 3: `bootScreen` gained a `locale` parameter wiring
  `AppLocalizations.localizationsDelegates` + `supportedLocales`; new test
  'Arabic locale renders the hint through the delegates' asserts the Arabic
  hint copy end-to-end — the committed pattern for future localized screens.
- Full suite tail (fresh run after all three tasks):
  `02:52 +669: All tests passed!` — 0 failing (was 3).
- `flutter analyze`: No issues found.

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
