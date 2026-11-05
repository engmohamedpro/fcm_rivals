# Reviews

This folder is the task inbox. Reviewers write review files here; developers execute them.
Every review follows one lifecycle from creation to archive. Files are never deleted.

## 1. File naming

`YYYY-MM-DD_<feature>_<short-title>.md`

Example: `2026-11-04_auth_login-validation.md`

Follow-up reviews use the same pattern with their own date and title and always link back to the file they continue (see section 6).

## 2. Status lifecycle

| Status | Meaning | Who sets it | Developer picks it up? |
|---|---|---|---|
| OPEN | Not started | Reviewer | Yes |
| IN_PROGRESS | Developer is working on it | Developer | Yes |
| DONE | All tasks ticked and fully implemented, waiting for verification | Developer | No |
| REJECTED_PARTIAL | At least one task could not be completed; reason written, waiting for the reviewer's decision | Developer | Yes, until the reviewer has decided (see section 5) |
| SPLIT | Reviewer examined the rejection and moved the unfinished work to a linked follow-up review | Reviewer | No |
| CLOSED | Reviewer verified the work; nothing left open | Reviewer | No |

Allowed transitions:

```
OPEN -> IN_PROGRESS -> DONE -> CLOSED
                    -> REJECTED_PARTIAL -> SPLIT -> CLOSED
                                        -> IN_PROGRESS   (reviewer amended the task, see 5.B)
DONE -> (verification fails) -> new follow-up review, old file -> SPLIT
```

No other transitions are allowed. A reviewer never closes a review that they executed themselves.

## 3. Review file structure

Every file is created from `_template.md` and must contain these sections:

- Header: Feature, Type, Priority, Reviewer, Created, Status, Completed by, Completed on
- Context (1-3 lines)
- Tasks
- Acceptance Criteria
- Developer Notes
- Reviewer Verification
- Links: `Follows:` (previous review this one continues, if any) and `Follow-up:` (review created from this one, if any)
- Amendments (reviewer-owned, append-only, see 5.B)

## 4. Reviewer rules (creating)

1. Create a new file per review from `_template.md`. Never overwrite an old review.
2. Every task states WHAT, WHERE (`path:line`) and EXPECTED result, with measurable targets when relevant (numbers, bands, thresholds, test names).
3. Set Priority: Critical | Major | Minor.
4. Every finding needs evidence (file:line, profiler data, size analysis, failing test output). No filler.
5. Do not bundle unrelated work. One file per feature/theme.
6. Commit: `review(<feature>): add <file-name-without-extension>`. Stage only the review file(s).

## 5. Reviewer rules (handling results)

### A. File is DONE: verify

1. Check every task and every Acceptance Criteria item against the code, tests and docs. Run `flutter analyze` and `flutter test` yourself.
2. All correct: fill Reviewer Verification (date, commit hash, what was checked), set Status = CLOSED.
3. Something is wrong or missing: do not reopen the file. Fill Reviewer Verification with the evidence, create a NEW review for the corrections with `Follows:` pointing to the old file, set the old file's Status = SPLIT and add `Follow-up:` pointing to the new file.

### B. File is REJECTED_PARTIAL: decide

Read the developer's rejection reason and alternative in Developer Notes, check the evidence, then record one of these decisions in Reviewer Verification (with date and commit hash reviewed):

| Decision | When | Action |
|---|---|---|
| Rejection upheld, work still needed | The task is valid but blocked by something outside the task's scope (for example an engine change, a missing dependency, a design decision) | Create a NEW review for the blocked work and, if needed, a prerequisite review. Link both ways. Set the old file's Status = SPLIT. Ticked tasks stay as they are. |
| Task was wrong or infeasible | The task text asked for something incorrect, contradictory or impossible | Do NOT edit the original task text. Append a dated entry under Amendments stating the corrected task, then set Status = IN_PROGRESS so the developer continues in the same file. |
| Rejection not accepted | The task is feasible as written and the developer's reason is not supported by evidence | Write the counter-evidence in Reviewer Verification, set Status = OPEN, and ask the developer to retry. |
| More information needed | The reason is unclear or has no measurements | Write the exact questions in Reviewer Verification and keep Status = REJECTED_PARTIAL. Do not decide until answered. |

Rules for every decision:

1. Decide within the same working session in which the file is reviewed. A REJECTED_PARTIAL file must never sit undecided.
2. Never leave a blocked task in two active files. Blocked tasks move to exactly one place.
3. The follow-up review must copy the exact bands, targets and evidence it depends on, so it can be executed without opening the old file.
4. Maximum two rejection rounds on the same task. On the third, escalate to the engineering manager for a scope or priority decision and record the decision in Reviewer Verification.

## 6. Linking and follow-ups

- The follow-up file has `Follows: <old-file-name>`; the old file has `Follow-up: <new-file-name>`.
- A SPLIT file closes only when every task it handed over is done in a follow-up that is itself CLOSED. When the last follow-up is CLOSED, the reviewer sets the SPLIT file to CLOSED and notes the closing commit in Reviewer Verification.
- Chains are allowed (A -> B -> C). Each file records only its direct predecessor and successor.

## 7. Developer rules (executing)

1. At the start of every session, read all files with Status OPEN, IN_PROGRESS or REJECTED_PARTIAL.
    - A REJECTED_PARTIAL file that already has a reviewer decision in Reviewer Verification is handled according to that decision. Without a decision, do not redo the rejected tasks; wait for the reviewer.
2. Execute by priority: Critical, then Major, then Minor. Oldest first within the same priority.
3. Set Status = IN_PROGRESS when starting.
4. Tick `- [x]` only when the task is fully done: code, tests, localization EN/AR with RTL verified, analyzer clean, no performance or size regression.
5. Never edit the reviewer's Context, Tasks or Acceptance Criteria text. Only tick boxes and write in Developer Notes.
6. Before any commit that changes UI or engine behaviour, run the full suite (`flutter test`), not only the feature's tests. A red suite blocks every future review's "tests green" criterion.
7. When all tasks are ticked and every Acceptance Criteria item is verified: Status = DONE, `Completed by`, `Completed on`, and short implementation notes.
8. Never delete review files. Ignore files with Status DONE, SPLIT, CLOSED, or anything in `archive/`.

### Rejecting a task

If a task is wrong, infeasible, or blocked, do NOT tick it. Write in Developer Notes:

1. Which task and why it cannot be completed (one or two lines).
2. Evidence: measured numbers, failing test names, commit hashes, reproduction command.
3. What was attempted and why it did not work.
4. A concrete alternative or the exact next step, with its estimated scope.
5. What is already done and verified, so the reviewer does not re-check it.

Then set Status = REJECTED_PARTIAL, commit the partial work that is green, and flag it to the manager. Never tick a box to make a status look better, and never lower a band or threshold to make a test pass; propose the change in Developer Notes instead.

## 8. Archive

1. A file moves to `archive/` only when its Status = CLOSED and, if it has follow-ups, all of them are CLOSED.
2. Use `git mv` so history is kept. Never delete.
3. Archive when the folder gets crowded or at the end of a milestone.
4. Archived files are read-only. Corrections always go into a new review in the main folder.

## 9. Definition of Done (applies to every task)

- Compiles with zero analyzer warnings
- Tests added or updated, full suite green
- EN/AR localized, RTL verified
- No performance or size regression
- Follows the project architecture

## 10. Commit messages

| Case | Message |
|---|---|
| Developer executes a review | `fix(<feature>): address review <file-name-without-extension>` (use `perf`, `refactor`, `test` or `feat` when the Type fits) |
| Reviewer adds a review | `review(<feature>): add <file-name-without-extension>` |
| Reviewer verifies, decides or closes | `review(<feature>): verify <file-name-without-extension>` |
| Archive move | `chore(reviews): archive <file-name-without-extension>` |

Stage only the related files plus the review file. Never force-push or rewrite history. If a push fails, report the exact error and stop.

## 11. Worked example

1. `2026-11-04_tactics_phase-3-transitions`: developer ticks Tasks 1-3, cannot meet the balance bands in Tasks 4-5, writes evidence and a proposed alternative, sets REJECTED_PARTIAL.
2. Reviewer checks the evidence, decides "rejection upheld, work still needed", creates `2026-11-05_tactics_phase3-balance-bands-and-sweep` with `Follows:` pointing to the first file and the exact bands copied in, then sets the first file to SPLIT with `Follow-up:` pointing to the new one.
3. Developer executes the new file only. The old file is ignored.
4. New file reaches DONE, reviewer verifies and sets CLOSED.
5. Reviewer sets the old file to CLOSED, then both move to `archive/` with `git mv`.
