---
name: brainstorming-guided
description: "Turns an idea into an approved design through interactive dialogue with a user who is unfamiliar with the codebase. Walks the user through the relevant architecture, patterns, and conventions while designing, builds their mental model alongside the design, then runs design-review and hands off to create-tickets or subagent-driven-development."
---

# Brainstorming (Guided)

Interactive design dialogue with built-in teaching for a user who does not know the codebase well. Same outcome as `brainstorming-standard`, but every phase explicitly surfaces what was found in the codebase and why it matters, so the user finishes the session with both a design and a working mental model of the area they will be touching.

For the rule that no implementation may begin until the user has approved a design, see `instructions/common/workflow.md`. The design review step is delegated to the `design-review` skill.

## Preconditions

- You **MUST** be in plan mode before invoking this skill. Use `{{ENTER_PLAN_TOOL}}` if you are not.
- This skill is invoked either directly or by the `brainstorming` router after the user selects guided mode.

## Communication Principles

These principles apply at every step of the procedure. They are what makes this skill different from `brainstorming-standard`:

- **Show your working.** When you read a file, name the file and explain what you found and why it matters for the design.
- **Name the patterns.** When the codebase follows a recognisable pattern (repository, MVC, event sourcing, plugin host), name it explicitly and explain it in one or two sentences.
- **Surface conventions.** Naming, testing approach, error handling, and module layout are conventions the user may not know. State them.
- **Invite questions.** After each explanation, ask if anything needs deeper exploration before moving on.

## Procedure

1. **Guided codebase walkthrough.** Read the area of the codebase relevant to the brief and present what you found in a structured way. Cover: how the project is organised (directory structure, key entry points), patterns in use and why, the relevant subsystems (which parts relate to what is being built and how they interact), and conventions in those areas (naming, testing, error handling). After each section ask, "Does this make sense, or would you like me to dig deeper into anything here?" via `{{ASK_USER_QUESTION_TOOL}}`. Stay scoped to the brief; do not exhaustively map the codebase.
2. **Contextualised clarifying questions.** One question per message, anchored to what you found. For example, "The codebase uses the repository pattern for data access. Should this feature follow that or sit outside it?" rather than "How should we handle data access?" Prefer multiple choice via `{{ASK_USER_QUESTION_TOOL}}`.
3. **Contextualised approaches.** Propose 2-3 approaches, each anchored to existing code. For example, "Option A follows the existing pattern in `src/services/`, the lowest friction. Option B introduces a new pattern, the trade-off is inconsistency until migration." Lead with the recommendation and explain why.
4. **Present the design in sections.** Cover architecture, components, data flow, error handling, and testing. For each section, reference the existing code that informed the choice. Get user approval on each section before moving to the next.
5. **Consolidate the design summary.** Once every section has been approved, write a single structured summary covering goal, architecture, components, interfaces, data flow, error handling, and testing strategy. The summary stands alone: it does not require the walkthrough to be understood.
6. **Invoke `design-review`.** Use `{{INVOKE_SKILL_TOOL}}` against the consolidated summary. Surface substantive change notes to the user before continuing. If `design-review` escalates, stop and ask the user how to proceed.
7. **Get explicit final approval.** Present the reviewed summary and ask directly. "Looks fine" is not approval.
8. **Decide the next step.** Use `{{ASK_USER_QUESTION_TOOL}}` to ask whether to create tickets or start implementation. The only permitted downstream skills are `create-tickets` and `subagent-driven-development`; invoke whichever the user picks via `{{INVOKE_SKILL_TOOL}}`.

## What Guided Mode Does Not Change

- The hard gate from `workflow.md` still applies. No implementation before approval.
- One question per message, multiple choices are preferred.
- YAGNI applies. Teaching the user about the codebase is not a licence to design extra features.
- The completion gate is identical to `brainstorming-standard`: consolidated summary, `design-review` Approved, explicit final approval.

## Worked Example

User: "I need to add an audit log for admin actions. I've never worked on this codebase before."

1. **Walkthrough.** Read `src/admin/`, `src/audit/` (if it exists), the routing layer, and the persistence layer. Present: "The project is organised by feature, not by layer. Each feature lives under `src/<feature>/` with its own routes, services, and tests. There is no existing `audit/` directory. The pattern for cross-cutting concerns in this codebase is middleware in `src/middleware/`, and there are two existing examples: `src/middleware/request_id.go` and `src/middleware/auth.go`. Tests live next to code as `*_test.go` and use table-driven tests, no external test framework. Errors are returned, never panicked, and wrapped with `fmt.Errorf` at every layer." Ask: "Does this layout make sense, or would you like me to look more closely at any of these?"
2. **Contextualised question 1**: "Both existing middlewares write directly to `slog`. For audit logging, do you want the same approach (logs flow through the same pipeline), or a separate persistent store (database table)?" → User picks "database table".
3. **Contextualised question 2**: "There is no existing database access in the middleware layer. Are you happy introducing it there, or would you rather the middleware emit events that a separate audit service consumes?" → "Emit events".
4. **Contextualised approaches**: A) follow the existing middleware pattern, emit events on a Go channel consumed by a new `audit` package. B) introduce a third-party event bus. C) skip the middleware entirely, instrument each admin handler. Recommend A.
5. **Sections**: architecture (middleware + event channel + audit service), components (`AuditEvent` struct, `AuditMiddleware`, `AuditService`), data flow (admin handler → middleware → channel → service → DB), error handling (audit failures must not block the admin action, log and continue), testing (table-driven tests for the middleware, integration test for the service against a test DB). Each section is approved.
6. **Consolidate**, invoke `design-review`, returns Approved on first pass.
7. **Final approval** explicit.
8. **Next step**: `create-tickets`.

## Completion Gate

Same as `brainstorming-standard`. You **MUST NOT** hand off until:

- The design summary was consolidated into a single text block
- `design-review` returned Approved
- The user gave explicit final approval against the reviewed summary

## Common Mistakes

| Mistake                                                  | Why it is wrong                                                                                                                                   |
|----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| Skipping the walkthrough to "save time"                  | The walkthrough is the difference between this skill and `brainstorming-standard`. Without it, use the standard skill instead.                    |
| Walking through the entire codebase                      | Stay scoped. Walk the area the brief touches and the patterns directly relevant to the design.                                                    |
| Naming patterns without explaining them                  | The user does not know the codebase. "It uses the repository pattern" without an explanation is just jargon.                                      |
| Asking abstract questions instead of contextualised ones | "How should we handle errors?" is abstract. "Errors are wrapped with `fmt.Errorf` at every layer here, should we follow that?" is contextualised. |
| Treating the walkthrough as documentation                | The walkthrough lives in the conversation. It is not written to disk and is not a deliverable.                                                    |
