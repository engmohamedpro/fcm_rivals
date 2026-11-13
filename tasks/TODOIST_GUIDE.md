# Todoist Guide — the agent manual

Everything an agent needs to run the task board through the Todoist REST API
(v1). Read this once before your first task; the developer and reviewer guides
reference it.

## 1. Authentication

The API token lives in the environment variable `TODOIST_TOKEN` (ask the owner
if it is not set). Every request is a plain HTTPS call with a bearer header:

```bash
curl -s -H "Authorization: Bearer $TODOIST_TOKEN" \
     -H "Content-Type: application/json" \
     "https://api.todoist.com/api/v1/tasks"
```

Never print, commit or paste the token. Never write it into files, commit
messages or task descriptions.

**Project:** `Inbox` — project ID `6j28cCv8XPqPMhpV`.

**Sections** (verified live, in board order):

| Section | ID |
|---|---|
| Tasks | `6j28h7QfJCCxGMFV` |
| Doing | `6j28h8Pj5MpQC7V3` |
| Needs Review | `6j28h9XGxm733MhV` |
| In Review | `6j28hCQ8CgvxH6J3` |
| Done | `6j28hGRq3mqqmPF3` |

**Labels:** `blocked` — label ID `2186362765` (red). Apply it to any task that
needs an owner decision or is otherwise stuck; remove it when unblocked.

## 2. Task format

**Title** — `[T-NNNN] short imperative title`

- The number is the permanent ID. To create a task, list tasks in **all**
  sections (active *and* completed — see §6) and take max + 1. Never reuse a
  number.
- The same `[T-NNNN]` goes into every commit message for that task.

**Description** — fill these sections in this order (blank line between each):

```
Goal: one or two sentences — what must be true when done, and why it matters.

Context: files, modules, decisions already made, links. Write "None" if empty.

Requirements:
1. ...
2. ...

Out of Scope:
- ...

Acceptance Criteria (reviewer ticks these):
- [ ] ...  (every item checkable by someone who did not write the code)

How to Verify:
<exact commands with the expected result, e.g. flutter analyze / flutter test ...>
```

Todoist descriptions have a ~16,000-character limit; keep them tight and link
to files instead of pasting them.

**Priority** (Todoist inverts the scale — 4 is highest):

| Task priority | Todoist `priority` |
|---|---|
| critical | 4 (P1 red) |
| high | 3 (P2 orange) |
| medium | 2 (P3 yellow) |
| low | 1 (P4 grey) |

**Comments** are the audit log. Add one per event: dev notes (what changed,
files, how tested, concerns), review findings (PASS/FAIL, evidence), blocker
notes. Never delete or rewrite a comment — append a new one with the new facts.

## 3. API cheat-sheet

All calls are `https://api.todoist.com/api/v1` + path. Examples use
`$TODOIST_TOKEN` and the IDs above.

### List tasks (active, whole project)

```bash
curl -s -H "Authorization: Bearer $TODOIST_TOKEN" \
  "https://api.todoist.com/api/v1/tasks"
```

Each result carries `id`, `content`, `description`, `section_id`, `priority`,
`label_ids`, `is_completed`. Filter by `section_id` to see one column. The
project-wide list is how you pick your next task.

### Create a task

```bash
curl -s -X POST -H "Authorization: Bearer $TODOIST_TOKEN" \
  -H "Content-Type: application/json" -d '{
    "content": "[T-0126] Fix icon pack price ladder",
    "description": "Goal: ...\n\nContext: ...",
    "project_id": "6j28cCv8XPqPMhpV",
    "section_id": "6j28h7QfJCCxGMFV",
    "priority": 3
  }' "https://api.todoist.com/api/v1/tasks"
```

New tasks always start in **Tasks** (`6j28h7QfJCCxGMFV`).

### Move a task between sections

```bash
curl -s -X POST -H "Authorization: Bearer $TODOIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"section_id": "6j28h8Pj5MpQC7V3"}' \
  "https://api.todoist.com/api/v1/tasks/<task_id>/move"
```

Only ever move one step along the lifecycle; never jump columns.

### Update a task (title, description, priority, labels)

```bash
curl -s -X POST -H "Authorization: Bearer $TODOIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"description": "<new full description>", "label_ids": [2186362765]}' \
  "https://api.todoist.com/api/v1/tasks/<task_id>"
```

**Caution:** every update field you send **replaces** the stored value — send
the complete new description, not a fragment.

### Add a comment

```bash
curl -s -X POST -H "Authorization: Bearer $TODOIST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"task_id": "<task_id>", "content": "Implemented: ... / Review PASS: ..."}' \
  "https://api.todoist.com/api/v1/comments"
```

(Use the `/comments` endpoint with `task_id` in the body —
`/tasks/<id>/comments` is unreliable on this account.)

### Complete a task (QA pass)

```bash
curl -s -X POST -H "Authorization: Bearer $TODOIST_TOKEN" \
  "https://api.todoist.com/api/v1/tasks/<task_id>/close"
```

The task stays in its section, marked completed. Only the reviewer does this,
only on PASS, after the archive comment is posted.

### Delete a task

Only for tasks created by mistake in the same session. Never delete a task
that has history — correct it with a comment instead.

## 4. Board discipline

1. **One task at a time.** Never have two tasks in *Doing* (developer) or
   *In Review* (reviewer) at once.
2. **The section reflects verified reality.** A task moves to *Needs Review*
   only after the code is committed and pushed; to *Done* only after QA
   verified every acceptance criterion.
3. **Rework goes back to Tasks**, with a comment listing the exact failed
   criteria and how to reproduce them.
4. **Blocked ≠ failed.** Blocked needs a human; it gets the `blocked` label,
   a comment with what is needed, and the task stays where it is.
5. **Comments are append-only history.** A reviewer verdict never edits a dev
   comment; it adds its own.
6. **Completed tasks keep their ID retired.** Numbers never get reused, even
   after completion.

## 5. Progress reporting

No external notification systems are used. Report progress by:

1. Posting a **comment** on the task at each meaningful step (implementation
   milestones, test runs with real output, review findings).
2. The final console summary at the end of your session.

Never report a percentage or "done" you did not verify; a failed test or a
skipped check means the step is not complete. Say plainly what ran, what
passed, what did not run and why.

## 6. Numbering across completed tasks

`GET /tasks` returns active tasks only. Before creating a new task, also check
completed ones so numbers are never reused:

```bash
curl -s -H "Authorization: Bearer $TODOIST_TOKEN" \
  "https://api.todoist.com/api/v1/tasks/filter?query=search%3A%20done%20T-"
```

If the filter endpoint errors or returns nothing usable, the safe fallback is
to keep a local note of the highest ID you have seen in the board plus the
numbers in recent commit messages (`git log --oneline | grep -o 'T-[0-9]*'`),
and take max + 1. Err high rather than reuse.

## 7. Failure handling

- A failed API call is not a silent no-op: check the HTTP status (200/204 good,
  4xx/5xx bad) and the JSON body before claiming anything.
- If Todoist is unreachable, continue the engineering work, record the board
  actions you owe as a local todo, and apply them as soon as the API responds.
  State in your summary exactly which board moves are still pending.
- Never fabricate a task ID, a section move, a comment or a completion.
