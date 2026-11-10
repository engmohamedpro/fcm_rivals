---
id: T-0104
title: Harden the club-creation smoke test's bounded async waits (load-dependent flake)
priority: medium
status: todo
attempts: 0
depends_on: []
created: 2026-11-10
completed:
---

# T-0104: Harden the club-creation smoke test's bounded async waits (load-dependent flake)

## Goal
The app smoke test (`test/widget_test.dart`, 'club creation leads to the game shell with the 22 starter-formation packs') stops being load-dependent: its fixed-iteration async waits are too short under full-suite load on a cold build cache, so the full-suite gate stays a reliable green instead of a coin flip.

## Context
- Found during the T-0088..T-0103 batch review (2026-11-10, Flutter 3.47.9, main @ 36f8744):
  - Full suite run 1 (first run on a freshly installed SDK = cold build cache): FAILED exactly one test — `test/widget_test.dart:128`, Expected exactly one 'Start your first season', Actual Found 0. The test had already flushed 8×100ms + 200ms and polled 10×60ms (~1.6s total).
  - The same test file solo immediately after: 3/3 green.
  - Full suite run 2 (warm cache): 1012/1012, "All tests passed!".
  - Pre-batch (main @ 161d50b) the same smoke test passed 2/2 full-suite runs with a single 300ms flush — T-0098's grown crest form forced the wait rewrite (dragUntilVisible + flush loops, commit 7139e54), whose bounded polls are still racy under load.
- The T-0103 task text already named the pattern: "the full-suite gate is a coin flip depending on machine load — every future task's 'full `flutter test` green' criterion is unreliable." The audio half of that coin was fixed by T-0103; this is the wait-pattern half.
- The failing expectation sits after the post-submit provider flush (lines ~87-103: 8×100ms runAsync ticks + 200ms) and the CTA poll (lines ~126-133: 10×60ms ticking until 'Start your first season' appears).

## Requirements
1. Replace the fixed-iteration waits in `test/widget_test.dart` — the 8×100ms post-submit flush, the extra 200ms flush and the 10×60ms CTA poll — with ONE polled wait helper, e.g. `pumpUntilFound(WidgetTester tester, Finder finder, {Duration timeout})`: loop `runAsync(tick) + pump` until `finder.evaluate().isNotEmpty`, fail with a clear timeout message after ~5s. Use it for the game-shell tabs and the 'Start your first season' CTA.
2. No assertion is weakened or removed: every current `expect` stays; the helper replaces the WAITING, not the proof.
3. The drag-until-visible submit-button handling stays as is (it addresses geometry, not async timing).

## Out of Scope
- Any app/feature/production code — this is a test-infrastructure fix.
- The onboarding suite, the packs suite, other tests' waits.
- Animation timings or the reveal timeline.

## Acceptance Criteria
- [ ] The smoke test passes 3/3 consecutive solo runs.
- [ ] Two consecutive full `flutter test` runs green with no widget_test.dart failure — at least one of them on a cold build cache (fresh SDK or `flutter clean`) if feasible in the session.
- [ ] No assertion removed or weakened; `flutter analyze` zero warnings.

## How to Verify
```bash
flutter analyze
# Expected: No issues found!

flutter test test/widget_test.dart
# Expected: green — run it 3 times, 3/3

flutter test
# Expected: full suite green, twice in a row (one run on a cold cache if feasible)
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
