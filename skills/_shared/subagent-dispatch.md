# Subagent Dispatch - Procedural Rules

The workflow coordinator owns dispatch and shared state. These procedures
supplement `../../rules/common/subagents.md`. Read this file before every
dispatch.

## Context isolation

Delegated work starts fresh without inherited parent transcript. Verify the
actual current interface, schema and version against accessible harness evidence.
A documented fresh-child creation interface suffices without an explicit
inheritance parameter. Use an exposed inheritance control when required by the
actual schema; do not invent fields or assume that an omitted field means fresh.
Supply the bounded sufficient inputs from `./task-briefs.md`, not parent history.

Do not reuse accumulated child history as a fresh start or silently fall back to
history forks. Missing required isolation is a capability blocker; obtain
explicit alternative authorisation before continuing under different semantics.
Record capability and inheritance evidence under `./phase-evidence.md`.

Reuse still-valid isolation or compaction capability checks only while the
harness, schema and configuration remain unchanged. This never waives the
per-dispatch model enumeration and routing checks below.

## Subagent type selection

Before each dispatch, select the most specific available subagent type that
fits the task, including reviewers. Identify the language, framework or domain,
then choose a specialist that fits. Use a general-purpose agent only when no
specialist applies. Record the specialist type and rationale in each task
brief. Default to no nested delegation unless the dispatch explicitly permits
it and the harness supports it.

## Model selection

Choose a model tier based on the work, then select and verify an exposed
concrete model for each dispatch. Preparation phases (Research, Planning and
Wave Planning) and independent design or readiness reviews require
high-capability reasoning. Bounded implementers use the lowest-cost capable
tier. Select reviewers by scope and capability, not by assuming every review
is tiny. Cross-cutting or design-level review needs a capable reviewer.

### Tier examples

| Tier             | Task signal                                     | Provider-agnostic example |
|------------------|-------------------------------------------------|---------------------------|
| Low-cost capable | Bounded implementation with a clear brief       | Fast, lower-cost tier     |
| Standard         | Multi-file integration or moderate judgement    | Balanced tier             |
| High-capability  | Preparation, design or broad independent review | High-reasoning tier       |

Tier examples are guidance, not an allowlist or availability guarantee. Use
capability and cost as the criteria, not the example names.

### Resolution procedure

Before every dispatch:

1. Enumerate the model identifiers exposed by the current environment using
   `{{MODEL_ENUMERATION}}`.
2. Select a model capable of the required tier and verify that the harness
   supports routing to it. Use the actual exposed interface; do not invent
   tool parameters or schema fields.
3. Never construct an identifier from a pattern or rely on remembered
   availability. Confirm both identifier and routing support.
4. Confirm that the active primary-session model has high-capability reasoning
   before conversational Research or Planning. Skill metadata does not switch
   it. If it is unsuitable, ask the user to switch; do not replace the
   user-facing conversation with an unrequested detached agent.
5. If enumeration, routing or required capability cannot be verified, report
   a blocker. Do not silently inherit, downgrade or substitute a model. A user
   may explicitly authorise an alternative; record the decision and its
   consequence.

### Tier changes and blockers

Use the tier required by the task from the outset. Do not use a low-cost
implementer default for preparation or independent design/readiness reviews.
Do not silently change a selected tier after failure. Stop and report the
blocker, then wait for explicit resolution. Do not force an unchanged retry or
escalate without authorisation.

| You might think...                              | Reality |
|-------------------------------------------------|---------|
| "I know the naming pattern"                    | Enumerate the environment; never invent an identifier. |
| "This was available before"                     | Confirm current availability and routing for every dispatch. |
| "The examples list it"                         | Examples are not an availability guarantee. |
| "The skill metadata selected this model"        | Metadata does not switch the active primary model. |
| "I can silently use the inherited model instead"| Missing enumeration, routing or capability is a blocker unless the user authorises an alternative. |

## Answering subagent questions

When a subagent asks a question before or during its task, answer it clearly
and completely before allowing it to proceed. Do not rush implementation or
expect a worker to guess missing requirements.

## Process discipline

When coordinating a workflow, do not:

- Skip a review unless the user explicitly skipped that scoped phase; record
  the skip and never present it as a verdict.
- Proceed while an applicable review has unresolved in-scope issues.
- Accept "close enough" where acceptance criteria are unmet.
- Treat an implementer's report as independent review or verification.
- Force an unchanged retry after failure.
- Silently repair worker output in coordinator context; delegate in-scope
  corrections under the existing task contract.
- Start the next wave before current writers settle and the integration
  barrier completes.

## Blockers and recovery

If a real blocker occurs, stop new dispatch. Cancel active work only if safe
cancellation is supported; otherwise let it settle without claiming it
stopped. Preserve workflow state and report the blocker. Do not silently expand
scope, change model tier or force an unchanged retry. Resume only after the
required user or coordinator resolution. Never represent failed or blocked
work as successful.
