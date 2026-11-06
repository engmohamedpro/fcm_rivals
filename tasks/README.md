# Tasks

A file-based task board for AI agents. **One task = one Markdown file.** The folder a file sits in is its stage.

```
tasks/
├── README.md                  ← you are here
├── HOW_TO_WRITE_TASKS.md      ← rules for creating task files
├── 1-todo/                    ← tasks waiting to be done (or sent back by the reviewer)
├── 2-needs-review/            ← tasks the developer finished, waiting for the reviewer
├── 3-archived/                ← tasks the reviewer verified and accepted
├── templates/
│   └── TASK_TEMPLATE.md       ← copy this to create a new task
└── agents/
    ├── DEVELOPER_AGENT.md     ← instructions for the developer agent
    └── REVIEWER_AGENT.md      ← instructions for the reviewer agent
```

## Lifecycle

```
                 developer finishes
   1-todo  ───────────────────────────►  2-needs-review
     ▲                                         │
     │          reviewer: FAIL                 │
     └─────────────────────────────────────────┤
                                               │ reviewer: PASS
                                               ▼
                                          3-archived
```

| Stage | Folder | Who moves a file **out** of it |
|-------|--------|--------------------------------|
| 1 | `1-todo/` | Developer agent → `2-needs-review/` |
| 2 | `2-needs-review/` | Reviewer agent → `3-archived/` (pass) or `1-todo/` (fail) |
| 3 | `3-archived/` | Nobody. Archived tasks are final. |

## Rules for everyone

1. Move files with `git mv` so history is kept. Never copy-and-delete.
2. Every move is its own commit, with the task ID in the message (for example `T-0007: submit for review`).
3. Always `git pull --rebase` before picking a task and before every move, and `git push` right after.
4. The `status` field in the task's front matter must always match the folder the file is in.
5. Only the developer agent moves tasks `1-todo → 2-needs-review`. Only the reviewer agent moves tasks out of `2-needs-review`. No agent moves a task into `3-archived` except the reviewer, and only after a pass.
6. `.gitkeep` files only keep empty folders in Git. Agents ignore them.

## Where to start

- Writing tasks: `HOW_TO_WRITE_TASKS.md`
- Developer agent: `agents/DEVELOPER_AGENT.md`
- Reviewer agent: `agents/REVIEWER_AGENT.md`
