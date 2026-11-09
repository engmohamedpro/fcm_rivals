---
id: T-0081
title: Show team-style formation choices on club creation without reward promises
priority: high
status: done
attempts: 1
depends_on: []
created: 2026-11-09
completed: 2026-11-09
---

# T-0081: Show team-style formation choices on club creation without reward promises

## Goal
The club creation page picks the starter formation the same way the Team tab does — a simple dropdown of formation names — and tells the user nothing about what they will win: no coins/packs promises anywhere on the screen (owner decision 2026-11-09).

## Context
- Owner decision (2026-11-09): the landing page should list formations "like what in the team" and must not tell the user what he will win.
- Today (`lib/features/onboarding/club_creation_screen.dart`): the starter formation is a bounded 300px scroll list of `_FormationOption` rows (~222-238) — each row is the formation code headline plus position-census badges (`GK 1 · CB 2 · LB 1 · …`, the `_FormationOption` widget at ~339-445, doc: "so the user sees exactly what the 22 free packs will cover"). The Team tab instead uses `FcmDropdown<String>` with one simple item per formation (`lib/features/squad/tactics_setup_view.dart` ~245-253, items from `formations` in `lib/features/squad/formations.dart`).
- Reward-promise texts to remove (verified in the ARBs): `createYourClubIntro` ("You start with coins and 22 free packs…" / "تبدأ بعملات و٢٢ حزمة مجانية…") and `starterFormationIntro` ("…your 22 free packs match its positions…" / "…٢٢ حزمة مجانية تطابق مراكزها…"). The screen's doc comment also sells the packs ("the shape the free 22 packs are matched to") — rewrite it without the reward language.
- BEHAVIOR IS UNCHANGED: `createClub` still grants the same starter coins/packs (`_submit` ~44-65); only the telling is removed. Do not touch the store.
- No club-creation test exists today (verified by grep) — this task adds the first one.

## Requirements
1. Replace the bounded census list with the same formation picker the Team tab uses: an `FcmDropdown<String>` (matching `tactics_setup_view.dart` ~245-253 — same icon, same items built from `formations`, selected = `_formationCode`, selection updates state). The `starterFormationSection` label stays above it.
2. Delete the `_FormationOption` widget and the census-badges presentation entirely.
3. Remove the `createYourClubIntro` and `starterFormationIntro` texts from the screen. The `createYourClub` heading stays; the crest section is untouched.
4. Delete the two now-unused l10n keys (`createYourClubIntro`, `starterFormationIntro`) from BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`, regenerate (`flutter gen-l10n`), keep `test/core/ui/l10n_test.dart` green.
5. Update the screen's doc comment to drop the "22 free packs" language (behavior description without reward advertising).
6. Add a widget test (e.g. `test/features/onboarding/club_creation_test.dart`): the dropdown renders and lists all formations from `formations` when opened; selecting one updates the selection; none of the promise texts (no "22", no "free packs"/"مجانية" reward line) render in EN and AR; the form fields and submit still work.

## Out of Scope
- Changing what `createClub` grants (coins, packs, formation linkage) — the rewards still exist in the game, they are just not advertised here.
- The club name / manager fields, crest picker, submit button, validation.
- The Team tab's own formation picker (it is the reference, not the target).
- Any other onboarding/intro screens.

## Acceptance Criteria
- [x] Club creation shows a `FcmDropdown` of formation names identical in behavior to the Team tab's picker; the census-badges list is gone.
- [x] No text on the screen mentions coins, packs or any reward the user will win — in English and Arabic.
- [x] The unused l10n keys are removed from both ARBs; generation is clean; l10n parity test passes.
- [x] The new widget test covers: dropdown lists all formations, selection works, promise texts absent in both locales, submit path intact.
- [x] `flutter analyze` zero warnings; `flutter test test/features/onboarding/ test/core/ui/l10n_test.dart` green; full `flutter test` green.

## How to Verify
```bash
flutter gen-l10n && flutter analyze
# Expected: generation clean, No issues found!

flutter test test/features/onboarding/ test/core/ui/l10n_test.dart
# Expected: new club-creation test passes in EN + AR; l10n parity holds

flutter test
# Expected: full suite green, no REGEN_SNAPSHOT
```

---

## Review Log

### Review 2026-11-09, attempt 1: PASS
- File note: this task was authored without the Developer Notes / Review Log sections (older planning format); the developer's implementation summary lives in commit 2a98220's message. The Review Log section is added by this review per the reviewer workflow.
- Ran at af32eea (fresh Flutter 3.47.9 / Dart 3.13.7): `flutter gen-l10n` → clean; `flutter analyze` → No issues found; `flutter test test/features/onboarding/ test/core/ui/l10n_test.dart` → 8/8 green (4 new club-creation tests + l10n parity); full `flutter test` → 929/929 green with `REGEN_SNAPSHOT` unset (one shared run covering both tasks in review at this HEAD).
- Diff audit (2a98220): the bounded census list is replaced by `FcmDropdown<String>` built from `formations` with one `FcmDropdownItem` per formation — the same picker pattern as the Team tab's `tactics_setup_view.dart`; `_FormationOption` and the census badges are deleted entirely; `createYourClubIntro` and `starterFormationIntro` are removed from the screen, from BOTH `app_en.arb` and `app_ar.arb`, and from the generated `app_localizations*.dart` getters; the screen's doc comment no longer sells the packs. `createClub` and the store are untouched — behavior unchanged, only the telling (exactly what the task demands).
- The new `test/features/onboarding/club_creation_test.dart` (218 lines, 4 tests) covers all required cases: the dropdown lists every formation and selection works (EN); no reward promises render in EN; no reward promises in AR with the dropdown mirrored (RTL); and the submit path validates fields and runs `createClub` end-to-end on a real in-memory store.
- No out-of-scope changes: the diff touches only the screen, the l10n files, the task file and the new test.
