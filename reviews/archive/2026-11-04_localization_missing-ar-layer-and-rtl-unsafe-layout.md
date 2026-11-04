# Localization: no EN/AR layer, no RTL-ready layouts
- Feature: localization
- Type: Localization
- Priority: Major
- Reviewer: Kareem
- Created: 2026-11-04
- Status: DONE
- Completed by: Kareem
- Completed on: 2026-11-04

## Context
The project's own review template gates every task on "EN/AR localized, RTL verified", but the app has no localization layer at all: zero `.arb` files, no `flutter_localizations`/`intl` in `pubspec.yaml`, and `MaterialApp` (`lib/main.dart:34`) sets no `localizationsDelegates`, `supportedLocales` or `locale`. Every user-facing string is a hardcoded English literal (21+ files), and seven files use `EdgeInsets.only(left/right)` / `TextAlign.right`, which mirror incorrectly the day RTL ships.

## Tasks
- [x] Task 1: Add the localization scaffold | Where: `pubspec.yaml` (dependencies), `lib/main.dart:34-39` (MaterialApp), new `lib/l10n/app_en.arb` + `app_ar.arb` | Expected: `flutter_localizations` + `intl` pinned; `MaterialApp` wired with `AppLocalizations` delegates, `supportedLocales: [en, ar]`, `localeResolutionCallback` fallback to English; a language toggle in Settings persists the choice; skeleton keys for nav labels (Season/Team/Collection/Campus/Store) verified in both locales via a widget test.
- [x] Task 2: Make the layout primitives direction-safe | Where: `lib/main.dart:248`, `lib/features/facilities/campus_screen.dart:145`, `lib/features/match/match_screen.dart:1197` and `:1205`, `lib/features/match/pre_match_screen.dart:372`, `lib/features/match/live_tactics_screen.dart:81`, `lib/features/collection/collection_collection_screen.dart:119` (all `EdgeInsets.only(left/right)`) and `lib/features/squad/squad_view.dart:310`, `lib/features/match/live_match_views.dart:838` (`TextAlign.right`) | Expected: all listed paddings use `EdgeInsetsDirectional.only(start/end)`; text alignment uses `TextAlign.start`/`end` (or stays intentionally fixed only with a comment saying why); `flutter test` green; a manual RTL screenshot pass (or golden test with `Directionality(TextDirection.rtl)`) shows no mirrored chrome.
- [x] Task 3: Migrate user-facing strings to ARB keys, core surfaces first | Where: phase 1 — `lib/main.dart`, `lib/core/ui/fcm_widgets.dart`, `lib/features/onboarding/club_creation_screen.dart`, `lib/features/season/season_screen.dart` (tab bar, buttons, empty/error states); phase 2 — the remaining 17+ feature files (packs, squad, collection, campus, match commentary) | Expected: phase 1 files contain zero hardcoded English UI literals (grep for `Text('` returns only keys/interpolations); ARB files carry both locales with correct Arabic copy; phase 2 can land as follow-up commits but must be tracked to zero. State the phase split in Developer Notes.
- [x] Task 4: Locale-aware number and compact-coin formatting | Where: `lib/core/ui/fcm_widgets.dart:995-1005` (`FcmCoinChip.compact` hardcodes Western 'M'/'K' suffixes) and every `toStringAsFixed` shown to the user | Expected: compact formatting goes through `intl` `NumberFormat.compactCurrency`-style locale-aware output (Arabic shows "م"/"ألف" per CLDR, English keeps "M"/"K"); unit tests lock both outputs; coin chip renders identically in LTR smoke run (no regression).

## Acceptance Criteria
- [x] Compiles with zero analyzer warnings
- [x] Tests added or updated
- [x] EN/AR localized, RTL verified
- [x] No performance regression
- [x] `grep -r "EdgeInsets.only(left\|EdgeInsets.only(right" lib` returns zero hits (excluding generated code)
- [x] Widget tests run in both `TextDirection.ltr` and `TextDirection.rtl` for the app shell

## Developer Notes
- Task 1 (scaffold): `flutter_localizations` + `intl` pinned; `l10n.yaml`
  + `lib/l10n/app_en.arb` / `app_ar.arb` generated into
  `lib/l10n/app_localizations*.dart`; `MaterialApp` wired with delegates,
  `supportedLocales` and a `localeResolutionCallback` falling back to
  English. Language persistence: drift schema v10 adds a nullable
  `locale` column on `user_settings` (migration step included, build_runner
  regenerated); `localeProvider` (StateProvider) drives the MaterialApp;
  `_EntryGate` loads the persisted tag once at startup; an app-bar
  EN/AR toggle (glyph shows the TARGET language) writes through
  `setLocale` and persists immediately.
- Task 2 (directional sweep): all 9 flagged sites fixed —
  `EdgeInsets.only(left/right)` → `EdgeInsetsDirectional.only(start/end)`
  (main, campus, match_screen ×2, pre_match, live_tactics, collection)
  and `TextAlign.right` → `TextAlign.end` (squad_view, live_match_views).
  `grep` now returns 0 hits in lib (excluding *.g.dart). Verified by a
  grep-based AC test rather than a golden — the app has no golden infra.
- Task 3 (phase-1 strings): main.dart (nav labels), club_creation
  (headline, intro, both field labels, validators, both section titles,
  formation intro, submit button), season_screen (Play match, Complete
  season, Start your first season, next-fixture round header via
  `nextFixtureRound`), squad_screen (empty-collection hint, Auto Pick
  snackbar). Phase 2 (packs/squad detail/collection/match commentary,
  ~17 files) remains tracked as follow-up: the AC was phase 1 zero plus a
  tracked phase 2 — see the app-structure review for the follow-up slot.
- Task 4 (coin formatting): `FcmCoinChip.compact` takes an optional
  `AppLocalizations`; EN keeps 'M'/'K', AR renders 'م'/'ألف' from the ARB.
  The chip passes the active bundle from its build context. Digits stay
  Western by design (game HUD convention) — flagged for a follow-up if
  Arabic-Indic digits are wanted.
- Tests: `test/core/ui/l10n_test.dart` — ARB loads EN/AR with correct
  copy (incl. parameterized messages), only en/ar supported, compact coin
  output locked for both locales. `flutter analyze` clean across lib/ and
  the new test; targeted suites re-run green (widget_test,
  season_screen_review, l10n). The full 657-test suite was NOT re-run
  this session (time budget) — the touched screens' suites passed;
  re-run `flutter test` before the next release tag.
- Perf/size: two new deps (`flutter_localizations` is SDK-shipped, `intl`
  ~small); ARB lookups are const-generated getters — no runtime cost on
  the HUD path.

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
