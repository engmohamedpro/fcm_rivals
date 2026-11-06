# How to Write a Task File

This guide is for whoever creates tasks: a human, or a planner agent. The rule is **one task per file**.

## 1. Where new tasks go

Always create new tasks in `tasks/1-todo/`. Never create them directly in the other two folders.

## 2. File name

```
T-<4-digit-number>-<short-kebab-case-title>.md
```

Examples:

- `T-0001-add-login-endpoint.md`
- `T-0042-fix-pagination-off-by-one.md`

**Choosing the number:** look in all three folders (`1-todo`, `2-needs-review`, `3-archived`), take the highest existing number, add 1. Never reuse a number, even for an archived task. The number in the file name must equal `id` in the front matter.

## 3. Create the file from the template

```bash
cp tasks/templates/TASK_TEMPLATE.md tasks/1-todo/T-0001-add-login-endpoint.md
```

Then fill in every section above the `---` divider. Leave **Developer Notes** and **Review Log** empty; agents fill those in.

## 4. Front matter fields

| Field | Values | Notes |
|-------|--------|-------|
| `id` | `T-0001` | Matches the file name |
| `title` | short imperative sentence | "Add login endpoint", not "Login" |
| `priority` | `critical`, `high`, `medium`, `low` | Developer picks highest priority first |
| `status` | `todo`, `needs-review`, `done`, `blocked` | New tasks start as `todo` |
| `attempts` | integer, starts at `0` | Developer increments on each submission |
| `depends_on` | list of IDs, or `[]` | Task is skipped until all of these are in `3-archived/` |
| `created` | `YYYY-MM-DD` | |
| `completed` | `YYYY-MM-DD` | Filled by the reviewer on pass |

## 5. Rules for a good task

1. **One task, one outcome.** If the title needs the word "and", split it into two files.
2. **Sized for one working session.** If an agent could not finish it in one sitting, it is too big. Split it and chain the pieces with `depends_on`.
3. **Self-contained.** The agent should not need to ask anyone anything. Put file paths, links and decisions in **Context**.
4. **Acceptance criteria are testable.** Bad: "Login works well." Good: "POST /login with a valid user returns 200 and a JWT; with a wrong password returns 401."
5. **How to Verify has real commands** and the expected output, so the reviewer can test without guessing.
6. **State what is out of scope.** This stops agents from refactoring things you did not ask for.
7. **Do not edit a task that is in `2-needs-review/` or `3-archived/`.** If requirements change, write a new task.

## 6. Example

File: `tasks/1-todo/T-0001-add-health-endpoint.md`

```markdown
---
id: T-0001
title: Add health check endpoint
priority: high
status: todo
attempts: 0
depends_on: []
created: 2026-11-06
completed:
---

# T-0001: Add health check endpoint

## Goal
Expose a lightweight endpoint so the load balancer can check that the API is alive.

## Context
The API entry point is `src/server.js`. Routes live in `src/routes/`.

## Requirements
1. Add `GET /health` in `src/routes/health.js` and register it in `src/server.js`.
2. It returns JSON `{"status": "ok"}` with HTTP 200.
3. It must not require authentication.

## Out of Scope
- Database connectivity checks.
- Any change to existing routes.

## Acceptance Criteria
- [ ] `GET /health` returns HTTP 200.
- [ ] The response body is exactly `{"status":"ok"}`.
- [ ] The endpoint works without an auth header.
- [ ] A test for the endpoint exists and passes.
- [ ] The existing test suite still passes.

## How to Verify
```bash
npm test
npm start &
curl -i http://localhost:3000/health
```
Expected: tests pass; curl shows `200 OK` and body `{"status":"ok"}`.

---

## Developer Notes

## Review Log
```

## 7. Checklist before you save a task

- [ ] File is in `tasks/1-todo/`
- [ ] File name is `T-NNNN-kebab-title.md` with a new, unused number
- [ ] `id` matches the file name, `status: todo`, `attempts: 0`
- [ ] Goal, Requirements, Out of Scope, Acceptance Criteria and How to Verify are all filled in
- [ ] Every acceptance criterion can be checked with a command or an observable result
- [ ] It is a single task, not several
