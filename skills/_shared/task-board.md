# Task Board Schema

This file defines, once, how an implementation-task decomposition maps onto the fields of Claude Code's shared task board (the `Task*` family: `TaskCreate`, `TaskList`, `TaskGet`, `TaskUpdate`). It is a data schema, not a procedure. It does not describe how tasks get assigned, handed off, or orchestrated; that lifecycle belongs to whichever skill uses the board. Skills that use the board **MUST** cite this file for field definitions rather than redefining them locally.

## Field Mapping

| Board field   | Meaning                                                                                               |
|---------------|-------------------------------------------------------------------------------------------------------|
| `subject`     | The task name.                                                                                        |
| `description` | The human-readable narrative: scene-setting, file responsibilities, and acceptance criteria as prose. |
| `owner`       | Who holds the task. See "The `owner` Field" below.                                                    |
| `status`      | The native lifecycle: `pending` -> `in_progress` -> `completed`.                                      |
| `blockedBy`   | Dependency edges: the tasks that must complete before this one may start.                             |
| `blocks`      | The inverse edge: the tasks that depend on this one.                                                  |
| `metadata`    | Structured fields not covered above, split by write authority (see below).                            |

The native `status` field is teammate-writable and advisory: a teammate moves it through `pending` -> `in_progress` -> `completed` to report its own progress. It is **never** authoritative for completion; only the lead-only `verified` key establishes that a task is done.

### `description` Carries the Acceptance Criteria

`description` is the durable, reviewable content for a task. It **MUST** contain:

- Scene-setting: where this task fits in the overall design
- File responsibilities: which files the task touches and what each is for
- Acceptance criteria, written as prose

Acceptance criteria **MUST NOT** be duplicated into a separate structured `metadata` field. `description` is the single place they live; a second, structured copy would drift from the prose original and create two sources of truth for the same requirement.

### The `owner` Field

`owner` carries three states, and which call produces each matters:

| State           | Written by                 | Meaning                                            |
|-----------------|----------------------------|----------------------------------------------------|
| Absent          | Nobody. Native at creation | Created, not yet assigned to any teammate          |
| A teammate name | The lead, via `TaskUpdate` | Assigned to that teammate                          |
| `"lead"`        | The lead, via `TaskUpdate` | Reclaimed after a failure; assigned to no teammate |

`TaskCreate` exposes no `owner` parameter at all, so a new task is natively unowned and needs no normalising write. `TaskUpdate` types `owner` as a plain string and documents no way to clear it, in deliberate contrast to `metadata`, where setting a key to null deletes it. The unowned state is therefore reachable at creation and not reachable again afterwards, which is why reclaiming a task from a departed teammate writes the `"lead"` sentinel rather than trying to blank the field. Without it, a dead teammate's name would sit on the record indistinguishable from a live owner.

A teammate **MUST NOT** take a task whose `owner` is not its own name, and **MUST NOT** write the field at all. Assignment is the lead's.

## `metadata`: Split by Write Authority

The load-bearing property of this schema is that `metadata` keys are partitioned by **who is allowed to write them**, not by what they contain. This split exists because the board is shared: a lead and one or more teammates all read and write the same task record. Without an explicit authority split, a teammate could overwrite a fact only the lead is entitled to assert.

### Lead-Only Keys

These keys **MUST** be written only by the lead. A teammate **MUST NOT** write them, even if the board technically permits it.

| Key          | Meaning                                                                     |
|--------------|-----------------------------------------------------------------------------|
| `files`      | The exclusive set of file paths this task owns.                             |
| `verified`   | Boolean. Set `true` only after the lead's own verification gate has passed. |
| `base_sha`   | The commit the task's diff is measured against.                             |
| `commit_sha` | The commit the task's diff landed as, once committed.                       |

### Teammate-Advisory Keys

A teammate **MAY** write these keys, but they are **never** authoritative for a completion or commit decision. They exist to give the lead visibility into in-flight work, not to make claims the lead must accept.

| Key     | Meaning                                                           |
|---------|-------------------------------------------------------------------|
| `claim` | A heartbeat marking that a teammate is actively working the task. |

## Guiding Invariant

The board is advisory; the lead is authoritative. A teammate's self-reported `status` or `claim` heartbeat is never sufficient grounds for marking a task complete or committing its diff. Only the lead's own verification, recorded in the lead-only `verified`, `base_sha`, and `commit_sha` keys, establishes that a task is done.

## Capability Probe

Any skill using this schema **MUST** confirm `TaskCreate` is available before relying on it. There is no flat-checklist tool to fall back to. If `TaskCreate` is not available, the skill **MUST** halt with a named, actionable error rather than silently degrading to prose bullet lists, since a bullet list cannot carry `owner`, `blockedBy`/`blocks`, or the `metadata` authority split defined above.

## Retention

The task board is subject to cleanup mid-run, governed by the `cleanupPeriodDays` setting. A purge drops board state, including the `metadata` ownership map (`files`, `verified`, `base_sha`, `commit_sha`). Because of this, the authoritative file-ownership map **MUST** also be recorded outside the board: in the lead's own working notes, or in the epic or ticket body. A purge is then recoverable rather than fatal; the lead can reconstruct task state from the redundant record instead of losing ownership information outright.
