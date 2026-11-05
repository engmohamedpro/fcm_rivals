# Reviews

This folder is the task inbox. Reviewers investigate, validate and write review files here; developers execute them.

Every review follows one lifecycle from creation to archive. Files are never deleted.

**Core principle:** A reviewer must prove that a problem or improvement is valid before creating a task, and independently verify that the implementation works before accepting it.

## 1. File naming

`YYYY-MM-DD_<feature>_<short-title>.md`

Example:

`2026-11-04_auth_login-validation.md`

Follow-up reviews use the same pattern with their own date and title and always link back to the file they continue (see section 7).

## 2. Status lifecycle

| Status | Meaning | Who sets it | Developer picks it up? |
|---|---|---|---|
| OPEN | Not started | Reviewer | Yes |
| IN_PROGRESS | Developer is working on it | Developer or reviewer when amending an incorrect task | Yes |
| DONE | All tasks ticked and fully implemented, waiting for verification | Developer | No |
| REJECTED_PARTIAL | At least one task could not be completed; reason written, waiting for the reviewer's decision | Developer | Yes, until the reviewer has decided (see section 6) |
| SPLIT | Reviewer examined the rejection or verification failure and moved unfinished work to a linked follow-up review | Reviewer | No |
| CLOSED | Reviewer verified the work; nothing left open | Reviewer | No |

Allowed transitions:

```text
OPEN -> IN_PROGRESS -> DONE -> CLOSED
                    -> REJECTED_PARTIAL -> SPLIT -> CLOSED
                                        -> IN_PROGRESS (reviewer amended the task, see 6.B)

DONE -> (verification fails) -> new follow-up review, old file -> SPLIT
```

No other transitions are allowed.

A reviewer never closes a review that they executed themselves.

## 3. Review file structure

Every file is created from `_template.md` and must contain these sections:

- Header: Feature, Type, Priority, Reviewer, Created, Status, Completed by, Completed on
- Context (1-3 lines)
- Investigation & Evidence
- Reproduction Steps (when applicable)
- Tasks
- Acceptance Criteria
- Developer Notes
- Reviewer Verification
- Links: `Follows:` (previous review this one continues, if any) and `Follow-up:` (review created from this one, if any)
- Amendments (reviewer-owned, append-only, see 6.B)

### Investigation & Evidence

This section documents why the review exists.

It must include:

- What was investigated.
- Root cause or technical justification.
- Files/components involved.
- Reproduction evidence, when applicable.
- Relevant test results, measurements or profiler output.
- Why the proposed change is necessary.
- Known dependencies and potential side effects.

For improvements rather than bugs, explain the measurable benefit expected.

## 4. Reviewer rules (before creating)

A reviewer MUST investigate and validate every potential task before creating a review.

Follow this exact order:

### A. Understand the feature

1. Read the relevant implementation, architecture and documentation.
2. Identify affected files, dependencies and execution flow.
3. Understand the expected behavior.
4. Inspect related components and existing implementations.

### B. Reproduce the issue

1. Run the application or relevant feature whenever possible.
2. Reproduce the reported bug or unexpected behavior.
3. Record exact reproduction steps.
4. Capture relevant logs, screenshots or test output when useful.
5. If the issue cannot be reproduced, investigate further before creating a task.

### C. Inspect the implementation

1. Trace the actual execution path.
2. Inspect related services, state management, data flow and dependencies.
3. Check whether existing code already solves the problem.
4. Identify the actual root cause rather than treating symptoms.
5. Check whether another feature or shared dependency is responsible.

### D. Run relevant tests

1. Run existing tests related to the affected functionality.
2. Add temporary experiments or test cases when necessary to validate the suspected issue.
3. Run relevant commands and inspect their output.
4. Distinguish between existing failures and failures caused by the investigated issue.
5. Record the results.

Never assume a problem exists based only on reading code.

### E. Validate the proposed solution

1. Confirm that the proposed change addresses the actual root cause.
2. Check that it follows project architecture.
3. Consider performance, memory and application size.
4. Consider backward compatibility.
5. Identify potential side effects and dependencies.
6. Determine whether a smaller or safer solution exists.

### F. Define measurable expectations

Before creating the review:

1. Define the expected behavior.
2. Define measurable acceptance criteria.
3. Identify the exact affected files or components.
4. Define how the developer will implement and verify the change.
5. Identify prerequisites and dependencies.
6. Define relevant edge cases.

### G. Create the review

Only create the review after completing the investigation.

Rules:

1. Create a new file per review from `_template.md`. Never overwrite an old review.
2. Every task states WHAT, WHERE (`path:line`) and EXPECTED result, with measurable targets when relevant (numbers, bands, thresholds, test names).
3. Set Priority: Critical | Major | Minor.
4. Every finding needs evidence (file:line, profiler data, size analysis, reproduction steps, failing test output).
5. Do not bundle unrelated work. One file per feature/theme.
6. Do not create speculative tasks.
7. Do not request a rewrite or refactor without evidence that it is necessary.
8. Do not duplicate existing tasks or implementations.
9. If testing is impossible, document exactly why and what evidence supports the task.
10. Commit: `review(<feature>): add <file-name-without-extension>`. Stage only the review file(s).

**Reviewer quality rule:** The reviewer must be able to explain WHY the task exists, WHAT needs to change, and HOW completion will be verified.

## 5. Reviewer task ordering and prioritization

When creating multiple reviews or multiple tasks within a review, follow this order:

1. **Blockers and prerequisites** – Tasks that other tasks depend on.
2. **Critical bugs** – Crashes, data corruption, security issues and broken core functionality.
3. **Major bugs** – Incorrect behavior affecting important functionality.
4. **Architecture and structural issues** – Foundational changes required by other features.
5. **Performance and resource optimization** – Proven performance, memory or size problems.
6. **Minor bugs and UX issues** – Non-blocking functionality and interface improvements.
7. **Optional improvements** – Non-essential enhancements.

Additional rules:

- Tasks with dependencies must explicitly identify their prerequisites.
- Do not create tasks that depend on unfinished work without documenting the dependency.
- Within each review, order tasks by execution dependency, then importance.
- Keep unrelated features in separate review files.
- Never prioritize cosmetic improvements over a blocking architectural or functional issue.
- Developers execute Critical, Major and Minor priorities according to the existing developer rules.

## 6. Reviewer rules (handling results)

### A. File is DONE: independently verify

A developer marking a review DONE does not mean the work is accepted.

The reviewer MUST independently verify the implementation.

Follow this exact order:

1. Read the developer's implementation notes.
2. Inspect the actual Git diff and commit history.
3. Verify that every requested task was implemented.
4. Confirm that no unrelated changes were introduced.
5. Run the application and manually test the affected functionality whenever possible.
6. Execute the original reproduction steps to confirm the issue is resolved.
7. Test every Acceptance Criteria item individually.
8. Test relevant edge cases, invalid inputs, empty states and failure scenarios.
9. Check for regressions in related functionality.
10. Run `flutter analyze`.
11. Run `flutter test` (full suite).
12. Verify localization EN/AR and Arabic RTL where applicable.
13. Verify performance and application size where relevant.
14. Record the exact tests performed, their results, the tested commit hash and any remaining limitations.

Important rules:

- A passing test suite does NOT automatically mean the task is accepted.
- Code inspection alone is NOT sufficient when runtime testing is possible.
- The reviewer must independently verify the result; never rely exclusively on the developer's claims.
- Never mark a task CLOSED just because its implementation looks correct.
- If manual testing is impossible, document the limitation and use the strongest available alternative verification.
- Any failed Acceptance Criteria item prevents closure.

**If all checks pass:**

- Fill Reviewer Verification with the date, commit hash, tests performed and verification results.
- Set Status = CLOSED.

**If something is wrong or missing:**

- Do not reopen the original file.
- Fill Reviewer Verification with the failure evidence.
- Create a NEW review for the corrections with `Follows:` pointing to the old file.
- Set the old file's Status = SPLIT.
- Add `Follow-up:` pointing to the new file.

### B. File is REJECTED_PARTIAL: decide

Read the developer's rejection reason and alternative in Developer Notes, check the evidence, then record one of these decisions in Reviewer Verification (with date and commit hash reviewed):

| Decision | When | Action |
|---|---|---|
| Rejection upheld, work still needed | The task is valid but blocked by something outside the task's scope (for example an engine change, a missing dependency, a design decision) | Create a NEW review for the blocked work and, if needed, a prerequisite review. Link both ways. Set the old file's Status = SPLIT. Ticked tasks stay as they are. |
| Task was wrong or infeasible | The task text asked for something incorrect, contradictory or impossible | Do NOT edit the original task text. Append a dated entry under Amendments stating the corrected task, then set Status = IN_PROGRESS so the developer continues in the same file. |
| Rejection not accepted | The task is feasible as written and the developer's reason is not supported by evidence | Write the counter-evidence in Reviewer Verification, set Status = OPEN, and ask the developer to retry. |
| More information needed | The reason is unclear or has no measurements | Write the exact questions in Reviewer Verification and keep Status = REJECTED_PARTIAL. Do not decide until answered. |

Rules for every decision:

1. Decide within the same working session in which the file is reviewed.
2. A REJECTED_PARTIAL file must never sit undecided.
3. Never leave a blocked task in two active files.
4. Blocked tasks move to exactly one place.
5. The follow-up review must copy the exact bands, targets and evidence it depends on, so it can be executed without opening the old file.
6. Maximum two rejection rounds on the same task. On the third, escalate to the engineering manager for a scope or priority decision and record the decision in Reviewer Verification.

## 7. Linking and follow-ups

- The follow-up file has `Follows: <old-file-name>`; the old file has `Follow-up: <new-file-name>`.
- A SPLIT file closes only when every task it handed over is done in a follow-up that is itself CLOSED.
- When the last follow-up is CLOSED, the reviewer sets the SPLIT file to CLOSED and notes the closing commit in Reviewer Verification.
- Chains are allowed (A -> B -> C).
- Each file records only its direct predecessor and successor.
- Follow-up reviews must be independently executable. Copy all relevant requirements, targets, reproduction steps and evidence into the new file.

## 8. Developer rules (executing)

1. At the start of every session, read all files with Status OPEN, IN_PROGRESS or REJECTED_PARTIAL.
    - A REJECTED_PARTIAL file that already has a reviewer decision in Reviewer Verification is handled according to that decision. Without a decision, do not redo the rejected tasks; wait for the reviewer.
2. Execute by priority: Critical, then Major, then Minor. Oldest first within the same priority.
3. Respect task dependencies. Never start a dependent task before its prerequisites are completed.
4. Set Status = IN_PROGRESS when starting.
5. Tick `- [x]` only when the task is fully done: code, tests, localization EN/AR with RTL verified, analyzer clean, no performance or size regression.
6. Never edit the reviewer's Context, Investigation & Evidence, Reproduction Steps, Tasks or Acceptance Criteria text. Only tick boxes and write in Developer Notes.
7. Before any commit that changes UI or engine behaviour, run the full suite (`flutter test`), not only the feature's tests. A red suite blocks every future review's "tests green" criterion.
8. When all tasks are ticked and every Acceptance Criteria item is verified:
    - Set Status = DONE.
    - Fill `Completed by` and `Completed on`.
    - Add short implementation notes.
    - Record relevant test commands and results.
9. Never delete review files.
10. Ignore files with Status DONE, SPLIT, CLOSED, or anything in `archive/`.

### Rejecting a task

If a task is wrong, infeasible, or blocked, do NOT tick it.

Write in Developer Notes:

1. Which task and why it cannot be completed (one or two lines).
2. Evidence: measured numbers, failing test names, commit hashes, reproduction command.
3. What was attempted and why it did not work.
4. A concrete alternative or the exact next step, with its estimated scope.
5. What is already done and verified, so the reviewer does not re-check it.

Then:

- Set Status = REJECTED_PARTIAL.
- Commit the partial work that is green.
- Flag it to the manager.

Never tick a box to make a status look better, and never lower a band or threshold to make a test pass. Propose the change in Developer Notes instead.

## 9. Definition of Done (applies to every task)

A task is considered implemented only when:

- Compiles with zero analyzer warnings.
- Tests are added or updated.
- Full test suite is green.
- EN/AR localization is complete where applicable.
- RTL is verified where applicable.
- No performance or size regression is introduced.
- Follows the project architecture.
- All Acceptance Criteria are satisfied.
- Relevant edge cases are handled.

A task is considered CLOSED only after independent reviewer verification.

## 10. Archive

1. A file moves to `archive/` only when its Status = CLOSED and, if it has follow-ups, all of them are CLOSED.
2. Use `git mv` so history is kept. Never delete.
3. Archive when the folder gets crowded or at the end of a milestone.
4. Archived files are read-only. Corrections always go into a new review in the main folder.

## 11. Commit messages

| Case | Message |
|---|---|
| Reviewer adds a review | `review(<feature>): add <file-name-without-extension>` |
| Developer executes a review | `fix(<feature>): address review <file-name-without-extension>` (use `perf`, `refactor`, `test` or `feat` when the Type fits) |
| Reviewer verifies, decides or closes | `review(<feature>): verify <file-name-without-extension>` |
| Archive move | `chore(reviews): archive <file-name-without-extension>` |

Stage only the related files plus the review file. Never force-push or rewrite history.

If a push fails, report the exact error and stop.

## 12. Worked example

1. Reviewer investigates a tactics transition bug, reads the relevant implementation, reproduces the issue in the application, checks existing tests and identifies the root cause.
2. Reviewer creates `2026-11-04_tactics_phase-3-transitions.md` with reproduction steps, evidence, measurable acceptance criteria and ordered tasks.
3. Developer reads the review, sets Status = IN_PROGRESS and executes Tasks 1-3.
4. Developer cannot meet the balance bands in Tasks 4-5, writes evidence and a proposed alternative, sets REJECTED_PARTIAL.
5. Reviewer checks the evidence and decides "rejection upheld, work still needed".
6. Reviewer creates `2026-11-05_tactics_phase3-balance-bands-and-sweep.md` with `Follows:` pointing to the first file and the exact bands and evidence copied in.
7. Reviewer sets the first file to SPLIT with `Follow-up:` pointing to the new one.
8. Developer executes the new file only. The old file is ignored.
9. New file reaches DONE.
10. Reviewer independently runs the application, tests the original reproduction steps, checks acceptance criteria, runs `flutter analyze` and `flutter test`, then sets the new file to CLOSED.
11. Reviewer sets the old file to CLOSED after confirming all its handed-over tasks are closed.
12. Both files move to `archive/` with `git mv`.

---

**Final rule:** Reviewers are responsible for validating the problem before assigning work and validating the solution before accepting work. Developers are responsible for implementing the agreed requirements and providing reproducible evidence of completion.