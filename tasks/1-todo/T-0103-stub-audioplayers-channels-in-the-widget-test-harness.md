---
id: T-0103
title: Stub the audioplayers platform channels in the widget-test harness
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-10
completed:
---

# T-0103: Stub the audioplayers platform channels in the widget-test harness

## Goal
Widget tests stop dying intermittently from the pack reveal's sound effects: the audioplayers plugin's platform channels are stubbed (or the soundtrack is inert) in the test environment, so `MissingPluginException` can never leak into an unrelated test again. Found during T-0087's review (2026-11-10) — the flake predates T-0087.

## Context
- The sound-effects commits (443a48e / c7b1125 / 83bce66) added the pack reveal soundtrack: `lib/features/packs/pack_soundtrack.dart` fires `SfxEvent`s from the reveal timeline marks (`lib/features/packs/pack_opening_screen.dart:329-332`), playing through the `audioplayers` plugin.
- In widget tests the plugin has no implementation: activating the global events stream throws `MissingPluginException(No implementation found for method listen on channel xyz.luan/audioplayers.global/events)`. Because the error is asynchronous, the test binding attributes it to whatever test is running when it lands — an INNOCENT BYSTANDER fails.
- Evidence from the T-0087 review (all reproduced by the reviewer, Flutter 3.47.9):
  - Full suite, commit af5516c, run 1: FAILED — "regression: after a BUY reveal closes, the store still opens packs" (`test/features/packs/packs_screen_test.dart:769`) with exactly that exception; run 2 on the same tree: 991/991 green.
  - That same test run ALONE fails with the same exception every time — including on commit 182d9e1, the tree BEFORE T-0087's implementation (2/2 in a clean worktree). So the defect is timing-dependent and pre-existing, not tied to any one test's code.
- Consequence if unfixed: the full-suite gate is a coin flip depending on machine load — every future task's "full `flutter test` green" criterion is unreliable.

## Requirements
1. Pick ONE mechanism and apply it consistently:
   - preferred: register no-op mock handlers for the audioplayers channels in the shared widget-test harness (e.g. via `TestDefaultBinaryMessengerBinding` mock method/stream handlers for `xyz.luan/audioplayers.*`), so any sound call in any test resolves silently; or
   - alternatively: make the soundtrack layer detect the test environment (`Platform.environment` / a flag) and no-op, with a comment pinning why.
2. Whatever the mechanism, it must cover every audio entry point that widget tests can reach (pack reveal soundtrack, card merge sound, any other sfx call site — grep for the audio service's usage).
3. Tests: the "regression: after a BUY reveal closes, the store still opens packs" test run ALONE with `--plain-name` passes 3/3 consecutive runs (today it fails every solo run); the packs suite stays green; no new analyzer warnings.
4. Do not change any runtime audio behavior in debug/profile/release builds — sounds must still play in the real app.

## Out of Scope
- Any change to the sound design, files, or mix (the sound-effects commits own that).
- Rewriting the affected tests' timing logic — the tests are fine; the harness is not.
- Golden/snapshot work.

## Acceptance Criteria
- [ ] Running `flutter test test/features/packs/packs_screen_test.dart --plain-name "regression: after a BUY reveal closes, the store still opens packs"` passes 3/3 consecutive times.
- [ ] No `MissingPluginException` appears anywhere in a full `flutter test` run's output (grep the log).
- [ ] Runtime audio behavior in the real app is unchanged (no release-mode guards beyond the test-env detection, no sound removed).
- [ ] `flutter analyze` zero warnings; packs suite green; full `flutter test` green.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/features/packs/packs_screen_test.dart --plain-name "regression: after a BUY reveal closes, the store still opens packs"
# Expected: passes — run it 3 times, 3/3 green (today: fails every solo run)

flutter test 2>&1 | tee /tmp/full.log
grep -c "MissingPluginException" /tmp/full.log
# Expected: 0, and "All tests passed!"

flutter test test/features/packs/
# Expected: 132/132 green
```

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
