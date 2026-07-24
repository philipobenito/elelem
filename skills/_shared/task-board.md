# Task Board Schema

This file defines, once, how an implementation-task decomposition maps onto the fields of Claude Code's shared task board (the `Task*` family: `TaskCreate`, `TaskList`, `TaskGet`, `TaskUpdate`). It is a data schema, not a procedure. It does not describe how tasks get claimed, handed off, or orchestrated; that lifecycle belongs to whichever skill uses the board (`subagent-driven-development` today, `team-driven-development` later). Skills that use the board **MUST** cite this file for field definitions rather than redefining them locally.

## Field Mapping

| Board field   | Meaning                                                                              |
|---------------|---------------------------------------------------------------------------------------|
| `subject`     | The task name.                                                                        |
| `description` | The human-readable narrative: scene-setting, file responsibilities, and acceptance criteria as prose. |
| `owner`       | The sentinel string `"lead"` in the sequential path (there is no teammate); a teammate name in the team path. |
| `status`      | The native lifecycle: `pending` -> `in_progress` -> `completed`.                      |
| `blockedBy`   | Dependency edges: the tasks that must complete before this one may start.             |
| `blocks`      | The inverse edge: the tasks that depend on this one.                                  |
| `metadata`    | Structured fields not covered above, split by write authority (see below).            |

The native `status` field is teammate-writable and advisory in the team path: a teammate moves it through `pending` -> `in_progress` -> `completed` to report its own progress. It is **never** authoritative for completion; only the lead-only `verified` key establishes that a task is done. In the sequential path the lead is the only writer, so this distinction is latent.

### `description` Carries the Acceptance Criteria

`description` is the durable, reviewable content for a task. It **MUST** contain:

- Scene-setting: where this task fits in the overall design
- File responsibilities: which files the task touches and what each is for
- Acceptance criteria, written as prose

Acceptance criteria **MUST NOT** be duplicated into a separate structured `metadata` field. `description` is the single place they live; a second, structured copy would drift from the prose original and create two sources of truth for the same requirement.

## `metadata`: Split by Write Authority

The load-bearing property of this schema is that `metadata` keys are partitioned by **who is allowed to write them**, not by what they contain. This split exists because the board is shared: a lead (orchestrator) and, in the team path, one or more teammates all read and write the same task record. Without an explicit authority split, a teammate could overwrite a fact only the lead is entitled to assert.

### Lead-Only Keys

These keys **MUST** be written only by the orchestrator or lead. A teammate **MUST NOT** write them, even if the board technically permits it.

| Key           | Meaning                                                                               |
|---------------|-----------------------------------------------------------------------------------------|
| `files`       | The exclusive set of file paths this task owns.                                        |
| `verified`    | Boolean. Set `true` only after the lead's own verification gate has passed.            |
| `base_sha`    | The commit the task's diff is measured against.                                        |
| `commit_sha`  | The commit the task's diff landed as, once committed.                                  |

### Teammate-Advisory Keys

A teammate **MAY** write these keys, but they are **never** authoritative for a completion or commit decision. They exist to give the lead visibility into in-flight work, not to make claims the lead must accept.

| Key      | Meaning                                                                                    |
|----------|----------------------------------------------------------------------------------------------|
| `claim`  | A heartbeat marking that a teammate is actively working the task.                            |

## Guiding Invariant

The board is advisory; the lead is authoritative. A teammate's self-reported `status` (the native lifecycle field) or `claim` heartbeat is never sufficient grounds for marking a task complete or committing its diff. Only the lead's own verification, recorded in the lead-only `verified`, `base_sha`, and `commit_sha` keys, establishes that a task is done. This invariant holds in both the sequential path (where the lead is the only writer, so the distinction is latent) and the team path (where the distinction is load-bearing because a second party can write to the same record).

## Capability Probe

Any skill using this schema **MUST** confirm `TaskCreate` is available before relying on it. There is no flat-checklist tool to fall back to. If `TaskCreate` is not available, the skill **MUST** halt with a named, actionable error rather than silently degrading to prose bullet lists, since a bullet list cannot carry `owner`, `blockedBy`/`blocks`, or the `metadata` authority split defined above.

## Retention

The task board is subject to cleanup mid-run, governed by the `cleanupPeriodDays` setting. A purge drops board state, including the `metadata` ownership map (`files`, `verified`, `base_sha`, `commit_sha`). Because of this, the authoritative file-ownership map **MUST** also be recorded outside the board: in the lead's own working notes, or in the epic or ticket body. A purge is then recoverable rather than fatal; the lead can reconstruct task state from the redundant record instead of losing ownership information outright.

## Relationship to `team-driven-development`

`team-driven-development` layers ownership and concurrency semantics (claiming, mailboxes, conflict handling) on top of this schema. It does not redefine any field here. Any skill that needs those semantics should look to that skill's own procedure file, not to this one.
