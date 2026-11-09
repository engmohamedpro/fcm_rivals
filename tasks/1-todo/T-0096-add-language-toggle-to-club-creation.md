---
id: T-0096
title: Add a language toggle to the club creation screen
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-09
completed:
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
- [ ] The club creation screen shows the language toggle without scrolling; tapping it switches EN↔AR live (form labels and the START MANAGING button re-render in the other language), and typed names plus the selected crest survive the flip.
- [ ] Tapping twice (EN→AR→EN) returns to English with no visual glitch and no duplicated toggle instances.
- [ ] The main shell's app bar toggle still works after the extraction to the shared widget (behavior unchanged).
- [ ] `flutter analyze` zero warnings; onboarding suite green with a new test covering the flip on this screen; full `flutter test` green, no REGEN_SNAPSHOT.

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

## Review Log
<!-- Reviewer agent appends one entry per review. Never delete old entries. -->
