# Task Briefs and Worker Reports

Each implementation brief is a self-contained contract derived from the
approved design. The coordinator and wave planner use it to keep workers
bounded, specialised and isolated. Workers do not infer architecture from
repository discovery or inherit conversational context.

## Required task brief

Every task brief records:

- Stable task and wave identifiers, objective and specialist subagent type.
- Requirement mapping, including integration, test and error-handling needs.
- Bounded context, relevant contracts, interfaces, assumptions and exclusions.
- Exact allowed write paths, plus known formatter, generator, build and test
  outputs. Anything not named is not an allowed write.
- Stable read paths and files that must not be read while concurrent writers
  can change them.
- Dependency edges, resource needs and possible conflicts: ports, databases,
  fixtures, temporary outputs or global tools.
- Acceptance criteria and task-local verification commands with expected
  evidence.
- Required model tier and specialist rationale.

The complete requirement map must cover every approved requirement. Same-wave
tasks have disjoint writes and may not read one another's changing files.
Shared reads are allowed only when those inputs remain stable for the full
wave. Integration work is a task, not an implicit assumption.
Prefer cohesive bounded tasks that permit multiple genuine sequential RED/GREEN cycles
without splitting work artificially or changing approved architecture.

## Dispatch constraints

Before each dispatch, read `subagent-dispatch.md` and follow its current
context-isolation, specialist-selection and model-resolution procedure.
Enumerate available model identifiers and verify that the harness can route
the selected capability. Use a high-capability tier for preparation and
independent reviews, and a low-cost capable tier for bounded implementation.
The `model` metadata in a skill does not switch the primary agent. If model
enumeration, routing or required capability is unavailable, report a blocker;
do not invent identifiers, silently downgrade, or retry at another tier.

The orchestrator supplies only the task brief and necessary source context.
Workers may change only allowed files and must not commit, push, create
branches or perform destructive Git operations. They return results to the
coordinator; they do not modify shared workflow state.

## Structured worker return

The worker returns exactly one outcome and enough evidence to act on it:

- `DONE`: acceptance criteria met; list changed paths, commands and outputs.
- `DONE_WITH_CONCERNS`: bounded work returned, with unresolved concerns and
  their impact identified.
- `NEEDS_CONTEXT`: name the missing fact or contract; do not guess or expand
  the task.
- `BLOCKED`: state the blocking condition, attempted safe actions and required
  user or coordinator decision.

The coordinator moves a returned task to `review`, not `verified`. Independent
review and fresh verification remain default requirements. Task-local checks
may run during other work only when their inputs are known stable. Broad
verification waits until all writers stop. A task is `integrated` only after
its required verification and wave integration barrier.

## Blockers and corrections

A real blocker halts new dispatch. Cancel active agents only when safe
cancellation is supported; otherwise allow them to settle and do not claim
they stopped. Preserve artefacts and report the blocker. Resume only after the
required authorisation is resolved. Do not silently expand scope or escalate
models. In-scope review corrections may be delegated within the approved task
contract; do not apply worker changes manually in the coordinator context.
