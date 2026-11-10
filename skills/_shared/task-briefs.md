# Task Briefs and Worker Reports

Each implementation brief is a self-contained contract derived from the
approved design. The coordinator and wave planner use it to keep workers
bounded, specialised and isolated. Workers do not infer architecture from
repository discovery or inherit conversational context.

## Phase inputs and returns

Apply this boundary contract to phase skills as well as delegated work. Phase
inputs include objective, method, scope and revision, applicable constraints,
required outputs and unresolved decisions. Supply precise artefact sections and
accessible source references, including relevant approval, exact-source skips,
baseline, checkpoint and evidence references. Select only what the next phase
needs; references must be accessible to its actual recipient.

Sufficiency takes precedence over arbitrary size caps. Broad reviews still
receive the full approved design and cumulative changes where required. Preserve
complete implementation briefs and all existing gates. Do not copy the whole
ledger or transcript. If necessary inputs are missing, return `NEEDS_CONTEXT`
rather than guess or rediscover broadly.

Phase returns include scope and revision, outcome, concise findings or proposed
content, evidence provenance, questions and blockers, and a next-action
recommendation. Return to the owning phase or coordinator under the existing
handoff path; a concise report does not replace original evidence or grant
approval. Implementation workers also follow the complete brief and structured
return below.

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
- Required implementation tier (`low`, `medium` or `high`) and short lowest-capable
  tier rationale, separate from the independent specialist rationale. Preparation
  and reviewer selection retain their scope/capability policy.
- Before dispatch: configured source/revision, requested tier and rationale,
  native selector, provider, API target/resolved model, reasoning effort or
  variant, fallback flag, reason, warning and evidence. Record explicit absence
  or inapplicability rather than guessing metadata. Include actual schema,
  catalogue/capability and routing evidence and the independent specialist.
- The retained actual task pin from the existing workflow record. In-scope
  corrections consume that retained actual selection, including fallback, with
  fresh drift/routing checks, not a newly selected current-session model.

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
the selected capability to the independently chosen specialist. Use a
high-capability tier for preparation and independent design/readiness reviews;
other reviewers remain scope/capability-selected. Implementation uses the lowest
capable named tier and native resolution, with only the warned, checked
current-model configuration fallback defined in `subagent-dispatch.md`. The
`model` metadata in a skill does not switch the primary agent. Missing model
enumeration, routing or required capability remains a blocker; do not invent
identifiers, silently downgrade or retry at another tier. Keep requested
workflow selection distinct from observed runtime execution; external runtime
plugin behaviour is outside this policy and is not controlled by task pins.

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

Ordinary workers report exact actual changed paths and rename mappings,
including intermediate or reverted edits and reviewer corrections, together
with baseline references, checks and per-behaviour TDD evidence. They do not
prepare whole-file test/case inventories or pruning evidence for task review.
The coordinator retains that history for one final union inventory after
cumulative final reviewer `PASS`. The separate final pruning brief supplies
the full frozen union and safety evidence under `test-pruning.md`; it is not an
ordinary implementation handoff requirement.

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
