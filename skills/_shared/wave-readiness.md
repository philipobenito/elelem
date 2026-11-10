# Wave Readiness Review

By default, an independent reviewer assesses the complete proposed task set and
wave schedule before implementation dispatch. This is distinct from design review:
it checks decomposition, ownership, dependency order and execution safety, not
whether the approved design itself should change. The review uses high-capability
reasoning and the current `subagent-dispatch.md` procedure. Model metadata does
not switch the active model; verify model enumeration and routing before
dispatch. Missing capability is a blocker, not grounds for silent fallback.

## Review inputs

Provide the reviewer with the approved plan revision and its explicit user
approval reference, full requirement-to-task map, every task brief, dependency
graph, wave assignment, concurrency limit, resource model and verification
barriers. Include relevant baseline and known repository constraints. Do not
pass session history as a substitute for these inputs.

## Readiness checks

The independent reviewer returns `READY` or `GAPS`, with evidence for each
finding. The planner checks the same requirements while constructing the
schedule, regardless of whether an independent review is authorised to be
skipped. Check:

- Every design requirement, integration need, test, error case and final check
  maps to a task or explicit verification activity.
- Task scopes are bounded, acceptance criteria are observable, and allowed
  writes include generated and verification outputs without overlapping.
- Stable reads are accurately identified; no same-wave task consumes a file
  another task may change.
- Dependency edges are complete and acyclic. Foundations precede consumers,
  and integration is explicit.
- Shared resource conflicts are accounted for, including ports, databases,
  fixtures, temp outputs and global tools.
- Wave identifiers and concurrency limits fit verified harness and resource
  capacity. No assumed capacity or unverified routing is treated as available.
- Ready independent tasks occupy the earliest safe wave up to verified harness
  and resource capacity. Check concrete reasons for serialisation, including
  concurrency one, against dependencies, ownership, stable reads and resources.
- Cohesive bounded tasks allow multiple genuine sequential RED/GREEN cycles
  where appropriate, without manufactured splits or architecture changes.
- Task-local checks use stable inputs. Full suite and integration barriers run
  only after all relevant writers stop.
- The requested implementation tier (`low`, `medium` or `high`) has a
  lowest-capable rationale and an independent specialist rationale. No task
  depends on workers discovering architecture outside the brief.
- The native mapping or bounded current-model configuration fallback path under
  `./subagent-dispatch.md` requires fresh availability, capability and explicit
  routing checks. Confirm the configuration source and actual schema can be
  inspected; missing evidence is not a configuration fault. Require, before first dispatch,
  the actual task pin and full provenance from `./task-briefs.md`, including any
  fallback warning and reason. Readiness does not select concrete models or
  replace per-dispatch checks. Corrections retain the pin, including fallback;
  relevant drift or workflow model changes require explicit authorisation.

Preparation and reviewer model policies remain unchanged. Implementation
configuration fallback does not waive non-configuration capability or routing
blockers. External runtime plugin recovery remains outside workflow-selection
policy; it neither blocks readiness by itself nor is prevented by task pins.

## Verdict and response

`READY` means the proposed schedule is complete and safe to dispatch against
the supplied approved design. It does not approve the design or authorise a
design change. Record verdict, reviewer identity, plan revision and material
findings in `waves.md` and coordinator state.

If the user explicitly skips only this review, do not invoke a reviewer and do
not record a review verdict. Record readiness review `SKIPPED`, its authorisation,
scope, reason and consequence in the planning/workflow records. The planner must
still complete the checks above and record the actual schedule, task ownership,
dependencies, resources, inputs, capacity and barriers. This is a planner-checked
schedule without an independent readiness verdict, not `READY`; do not describe
the skip as approval, evidence of review, or proof of readiness. The executor
may accept this record only after confirming the schedule and briefs are
otherwise complete and safe. Unknown critical inputs or other unsafe conditions
remain blockers.

For scheduling-only gaps, return precise corrections to wave planning. No new
user prompt is needed if requirements, architecture and contracts remain
unchanged. If a requirement, architecture, external expectation or contract is
missing, return the gap to planning. Any substantive design change requires
renewed explicit user approval and a fresh design review before readiness is
reassessed. Never dispatch on `GAPS`.

If wave planning was explicitly skipped, do not invent parallel tasks or claim
this review occurred. Require one complete, bounded task brief; execute only
that task through the coordinator's single-task path. This is distinct from
skipping the readiness review within completed wave planning.
