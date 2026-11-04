# Reviews

This folder is the task inbox. Reviewers add review files here. The developer executes them.
Files are never deleted. Status tracks the lifecycle.

## File naming
`YYYY-MM-DD_<feature>_<short-title>.md`
Example: `2026-11-04_auth_login-validation.md`

## Status lifecycle
| Status | Meaning |
|---|---|
| OPEN | Not started |
| IN_PROGRESS | Developer is working on it |
| DONE | All tasks checked and fully implemented |
| REJECTED_PARTIAL | At least one task rejected with a reason, sent back to reviewer |
| CLOSED | Reviewer verified the work |

## Reviewer rules
1. Create a new file per review from `_template.md`. Never edit an old review; create a new one.
2. Every task must state: what, where (file/line), and the expected result.
3. Set Priority: Critical | Major | Minor.
4. After verifying a DONE file, set Status to CLOSED.
5. Move CLOSED files to `archive` when this folder gets crowded.

## Developer rules
1. At the start of every session, read all files with Status OPEN, IN_PROGRESS, or REJECTED_PARTIAL.
2. Execute by priority: Critical, then Major, then Minor. Oldest first within the same priority.
3. Set Status to IN_PROGRESS when starting.
4. Tick `- [x]` only when the task is fully done (code, tests, localization EN/AR, analyzer clean).
5. When all tasks are ticked: Status = DONE, fill `Completed by` and `Completed on`.
6. If a task is rejected: do NOT tick it. Write the reason in Developer Notes and set Status = REJECTED_PARTIAL.
7. Never delete review files.
8. Ignore files with Status DONE, CLOSED, or anything in `archive`.

## Commit message
`fix(<feature>): address review <file-name-without-extension>`
Example: `fix(auth): address review 2026-11-04_auth_login-validation`
