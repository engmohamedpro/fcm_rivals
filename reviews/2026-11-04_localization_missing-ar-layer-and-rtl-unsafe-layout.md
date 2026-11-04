# Localization: no EN/AR layer, no RTL-ready layouts
- Feature: localization
- Type: Localization
- Priority: Major
- Reviewer: Kareem
- Created: 2026-11-04
- Status: OPEN
- Completed by: -
- Completed on: -

## Context
The project's own review template gates every task on "EN/AR localized, RTL verified", but the app has no localization layer at all: zero `.arb` files, no `flutter_localizations`/`intl` in `pubspec.yaml`, and `MaterialApp` (`lib/main.dart:34`) sets no `localizationsDelegates`, `supportedLocales` or `locale`. Every user-facing string is a hardcoded English literal (21+ files), and seven files use `EdgeInsets.only(left/right)` / `TextAlign.right`, which mirror incorrectly the day RTL ships.

## Tasks
- [ ] Task 1: Add the localization scaffold | Where: `pubspec.yaml` (dependencies), `lib/main.dart:34-39` (MaterialApp), new `lib/l10n/app_en.arb` + `app_ar.arb` | Expected: `flutter_localizations` + `intl` pinned; `MaterialApp` wired with `AppLocalizations` delegates, `supportedLocales: [en, ar]`, `localeResolutionCallback` fallback to English; a language toggle in Settings persists the choice; skeleton keys for nav labels (Season/Team/Collection/Campus/Store) verified in both locales via a widget test.
- [ ] Task 2: Make the layout primitives direction-safe | Where: `lib/main.dart:248`, `lib/features/facilities/campus_screen.dart:145`, `lib/features/match/match_screen.dart:1197` and `:1205`, `lib/features/match/pre_match_screen.dart:372`, `lib/features/match/live_tactics_screen.dart:81`, `lib/features/collection/collection_collection_screen.dart:119` (all `EdgeInsets.only(left/right)`) and `lib/features/squad/squad_view.dart:310`, `lib/features/match/live_match_views.dart:838` (`TextAlign.right`) | Expected: all listed paddings use `EdgeInsetsDirectional.only(start/end)`; text alignment uses `TextAlign.start`/`end` (or stays intentionally fixed only with a comment saying why); `flutter test` green; a manual RTL screenshot pass (or golden test with `Directionality(TextDirection.rtl)`) shows no mirrored chrome.
- [ ] Task 3: Migrate user-facing strings to ARB keys, core surfaces first | Where: phase 1 — `lib/main.dart`, `lib/core/ui/fcm_widgets.dart`, `lib/features/onboarding/club_creation_screen.dart`, `lib/features/season/season_screen.dart` (tab bar, buttons, empty/error states); phase 2 — the remaining 17+ feature files (packs, squad, collection, campus, match commentary) | Expected: phase 1 files contain zero hardcoded English UI literals (grep for `Text('` returns only keys/interpolations); ARB files carry both locales with correct Arabic copy; phase 2 can land as follow-up commits but must be tracked to zero. State the phase split in Developer Notes.
- [ ] Task 4: Locale-aware number and compact-coin formatting | Where: `lib/core/ui/fcm_widgets.dart:995-1005` (`FcmCoinChip.compact` hardcodes Western 'M'/'K' suffixes) and every `toStringAsFixed` shown to the user | Expected: compact formatting goes through `intl` `NumberFormat.compactCurrency`-style locale-aware output (Arabic shows "م"/"ألف" per CLDR, English keeps "M"/"K"); unit tests lock both outputs; coin chip renders identically in LTR smoke run (no regression).

## Acceptance Criteria
- [ ] Compiles with zero analyzer warnings
- [ ] Tests added or updated
- [ ] EN/AR localized, RTL verified
- [ ] No performance regression
- [ ] `grep -r "EdgeInsets.only(left\|EdgeInsets.only(right" lib` returns zero hits (excluding generated code)
- [ ] Widget tests run in both `TextDirection.ltr` and `TextDirection.rtl` for the app shell

## Developer Notes
<Implementation notes, rejected points with reason.>

## Reviewer Verification
<Filled by reviewer before setting CLOSED.>
