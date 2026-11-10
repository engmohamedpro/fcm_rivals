---
id: T-0096
title: Add a language toggle to the club creation screen
priority: medium
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-10
---

# T-0096: Add a language toggle to the club creation screen

## Goal
The club creation screen (the first screen a new player sees) carries an EN/AR language action, so the player can flip the app's language before creating the club — same behavior as the app bar toggle on the main shell.

## Context
- The toggle exists today but only in the main shell's app bar: `_LanguageToggle` at `lib/main.dart:159-185` — a private `ConsumerWidget` showing the TARGET language's glyph ('ع' / 'EN'), flipping via `setLocale()` (`lib/app/providers.dart:148-154`), which persists the choice through `userSettingsProvider` and updates `localeProvider` (`providers.dart:143`) so `MaterialApp` (locale wired at `lib/main.dart:39`) rebuilds immediately.
- The persisted locale loads at the entry gate before any screen renders (`_loadPersistedLocale`, `lib/main.dart:97-112`); the club creation screen is reached only when no club exists yet — a brand-new player has never seen the app bar toggle.
- `lib/features/onboarding/club_creation_screen.dart` is a full-screen form with NO app bar: `Scaffold > FcmBackdrop > SafeArea > Center > SingleChildScrollView > Form` (lines 70-233). A top-corner action row above the wordmark fits without disturbing the form.
- Tests: `test/features/onboarding/club_creation_test.dart` (real-DB harness for this screen).

## Requirements
1. Extract the app bar's `_LanguageToggle` (`lib/main.dart:159-185`) into a shared public widget `FcmLanguageToggle` under `lib/core/ui/` (suggest `fcm_language_toggle.dart`). Behavior identical: gold glyph of the target language, `languageLabel` tooltip, one tap flips and persists. `main.dart`'s app bar then uses the shared widget — no behavior change there.
2. In `club_creation_screen.dart`, place `FcmLanguageToggle` at the top of the scroll view — a start- or end-aligned row above the wordmark (`FcmEntrance` block at lines 84-97) — so it is visible without scrolling on small screens. It must not change the form's field order or validation.
3. Tapping it flips the whole screen's language live (labels, section headers, the START MANAGING button, validators' `fieldRequired` message) because `localeProvider` rebuilds `MaterialApp`. No screen re-push, no state loss: the typed club/manager names and the selected crest/formation survive the locale flip (they live in this screen's state — verify with a test that types a name, flips, and asserts the name is still in the field).
4. RTL: after flipping to Arabic the screen mirrors (already automatic); the toggle stays reachable and not clipped.

## Out of Scope
- Any other screen or a settings screen (none exists).
- Changing how the locale persists or loads (`setLocale`, entry gate).
- Adding new localized strings (the toggle is glyph-only; every existing key already has EN and AR).

## Acceptance Criteria
- [x] The club creation screen shows the language toggle without scrolling; tapping it switches EN↔AR live (form labels and the START MANAGING button re-render in the other language), and typed names plus the selected crest survive the flip.
- [x] Tapping twice (EN→AR→EN) returns to English with no visual glitch and no duplicated toggle instances.
- [x] The main shell's app bar toggle still works after the extraction to the shared widget (behavior unchanged).
- [x] `flutter analyze` zero warnings; onboarding suite green with a new test covering the flip on this screen; full `flutter test` green, no REGEN_SNAPSHOT.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/onboarding/
# Expected: green, including the new flip test

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

Manual: fresh install (no club) → club creation → tap the language glyph → the whole form flips to Arabic and back; typed text survives.

---
<!-- Everything below this line is filled in by agents, never by the task author. -->

## Developer Notes
<!-- Developer agent fills this in before moving the file to 2-needs-review. -->

- **Summary of changes:**
- **Files changed:**
- **How I tested it:**
- **Concerns / assumptions:**


### Attempt 1 — implementation complete (full suite run in the follow-up session)

**Summary of changes:**
1. `lib/core/ui/fcm_language_toggle.dart` (new) — the app bar's `_LanguageToggle` extracted verbatim into a public `FcmLanguageToggle` (gold target-language glyph, localized tooltip, one tap flips via `setLocale` and persists).
2. `lib/main.dart` — the app bar now uses the shared widget (the private class deleted); behavior unchanged.
3. `lib/features/onboarding/club_creation_screen.dart` — `FcmLanguageToggle` sits at the top of the scroll view above the wordmark, end-aligned via `AlignmentDirectional.centerEnd` so LTR/RTL both park it at the far corner; visible without scrolling; no field order or validation change.
4. `test/features/onboarding/club_creation_test.dart` — new harness `pumpCreationWithSettings` (a REAL `UserSettingsStore` on the same in-memory db — the default harness stubs the settings future with a throw, which would break the toggle's persist; MaterialApp follows `localeProvider` through a Consumer like the real app) + the new test 'T-0096: the language toggle flips EN↔AR live and typed names survive': asserts the 'ع' glyph, types 'Pyramid United', taps the flip, asserts the AR heading renders / EN heading gone / glyph flipped to 'EN', the typed name SURVIVED the rebuild, then flips back to EN with exactly one glyph on screen.

**Files changed:** `lib/core/ui/fcm_language_toggle.dart` (new), `lib/main.dart`, `lib/features/onboarding/club_creation_screen.dart`, `test/features/onboarding/club_creation_test.dart`, this task file.

**How I tested it:** `flutter analyze` → No issues found ✓ (whole project). `flutter test test/features/onboarding/` → **15/15 green** ✓ (including the new flip test). `flutter test test/core/ui/l10n_test.dart` → 4/4 ✓. Full `flutter test` → **1004/1004 green** ✓ (run in the follow-up session — note: the run overlapped the concurrent T-0099 implementation on the same tree, so a clean final re-run on the committed tree backs both tasks; no REGEN_SNAPSHOT).

**Concerns / assumptions:**
- The harness's MaterialApp follows `localeProvider` with a Consumer (mirroring the real app's wiring) — without it the flip can't rebuild the tree under test.

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->

### Review 1 — 2026-11-10 — PASS

**Ran (Flutter 3.47.9, main @ 36f8744):**
- `flutter analyze` → No issues found! ✓
- `flutter test test/features/onboarding/` → **19/19 green** ✓ — including the new flip test: EN → type 'Pyramid United' → tap 'ع' → the AR heading renders, the EN heading is gone, the glyph flips to 'EN', the typed name SURVIVED the rebuild, flip back with exactly one glyph on screen.
- `flutter test test/core/ui/l10n_test.dart` → **4/4 green** ✓
- Full `flutter test`: run 1 → **1011/1012** — the only failure was the club-creation smoke test at `test/widget_test.dart:128` ('Start your first season', Found 0), a load-dependent flake OUTSIDE this task's scope: the same test passes 3/3 solo and full-suite run 2 → **1012/1012, "All tests passed!"** with `grep -c MissingPluginException` = 0. Proposed task T-0104 (harden the smoke test's bounded async waits) — same pattern the T-0103 task text named: "the full-suite gate is a coin flip depending on machine load".
- Code read: the extraction is verbatim — the deleted `_LanguageToggle` body matches the new `FcmLanguageToggle` line for line (same `setLocale` call, glyph, tooltip, style); `main.dart`'s app bar uses the shared widget; club creation carries it at the top of the scroll view via `AlignmentDirectional.centerEnd` (mirrors in RTL, visible without scrolling, no field/validation change).
- AC3 note: the app-bar slot itself has no dedicated automated test (a pre-existing gap — the old private toggle had none either); verified by the verbatim-extraction diff plus the same widget's flip test.
- Only task of this batch whose full-suite result the developer actually recorded (1004/1004, commit e22475d).

All four criteria met; every verify command run by the reviewer.

