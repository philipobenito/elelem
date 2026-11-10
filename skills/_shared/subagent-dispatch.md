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

Preparation phases (Research, Planning and Wave Planning) and independent
design or readiness reviews require high-capability reasoning. Select reviewers
by scope and capability, not by assuming every review is tiny. Cross-cutting or
design-level review needs a capable reviewer. The implementation configuration
and configuration fallback below do not change preparation or reviewer policy.

### Implementation tiers

Implementation tiers are `low`, `medium` and `high`. Assign the lowest capable
tier with a short task-specific rationale in the brief, before native resolution.
Choose the specialist independently; specialist selection is independent of the
model and must not be changed to obtain a different model.

| Tier | Implementation task signal |
|------|----------------------------|
| low | Bounded mechanical work with explicit requirements |
| medium | Multi-file integration or moderate judgement |
| high | Broad reasoning or difficult implementation decisions |

These signals are guidance, not model names, an availability guarantee or an
automatic phase bypass. Concrete models remain user-configured. Do not infer a
reasoning effort or variant from the tier name. Use native configuration and
the actual exposed dispatch interface, not a new runtime router or framework.

### Native implementation configuration

Resolve only the requested implementation tier using the applicable adapter.
Inspect effective native configuration without exposing secrets, retaining
source/revision and precedence evidence. Configuration choices do not replace
per-dispatch enumeration, capability or explicit-routing checks.

#### OpenCode

Use `providers.<provider>.models.<tier>.modelID`, with exact `low`, `medium` or
`high` model keys. `modelID` is an opaque provider-local API target, including
slashes; do not parse it as a cross-provider redirect or alias chaining.
The explicit selector is `provider/alias[#variant]`, independent of the agent.

`GET /api/config` returns an array of document/directory `Config.Entry` records,
not a merged configuration object. Apply documented scope and precedence before
requiring a unique effective provider+alias identity for the tier. Multiple
layers overriding one identity are not duplicates. Include disabled and inactive
provider/alias candidates when detecting ambiguity; do not silently discard
them to select a convenient remaining provider. Missing, malformed or multiple
effective matches are configuration-resolution faults.

Cross-check the resolved alias against the current catalogue using
`{{MODEL_ENUMERATION}}` and full metadata from `GET /api/model` where needed.
Verify the alias's own capabilities, limits and variants. Do not assume metadata
is inherited from its API target or accept unknown-model fallback metadata as
capability evidence. A `#variant` is not an implementation tier. Verify any
selected variant actually exists and retain it in the explicit selector.

#### Claude Code

Use the user-accepted native slots `low=haiku`, `medium=sonnet`, `high=opus`.
Explicit pins are `ANTHROPIC_DEFAULT_HAIKU_MODEL`,
`ANTHROPIC_DEFAULT_SONNET_MODEL` and `ANTHROPIC_DEFAULT_OPUS_MODEL`, through
supported `settings.env` or process environment. Inspect effective settings and
environment precedence. Explain shared alias effects on other native consumers;
do not modify user settings or invent implementation-only aliases.

Use the actual per-call model enum, not an arbitrary full model ID in a
restricted argument. Check effective alias-family resolution, same-family parent
selection, override settings/mods and restrictions before claiming the pin is
routable. Verify capability and reasoning effort metadata against the actual
version/schema; effort is separate from model selection. Record both the native
call selector and resolved model, rather than assuming a slot proves its target.

#### Codex

Use native `$CODEX_HOME/<tier>.config.toml` files (`low.config.toml`,
`medium.config.toml`, `high.config.toml`) as a declarative source only for explicit
model, reasoning effort and provider compatibility. Since 0.134 these are named
profile files, not `[profiles.<tier>]` tables. This workflow convention is not a
native child tier resolver. Do not pass `--profile` to a child spawn, apply
unrelated profile settings or change the parent session to select a worker.

Classic Codex 0.163 exposes independent `agent_type`, `model` and
`reasoning_effort` fields when model overrides are exposed. V2 field exposure can
be gated; inspect the actual session tool schema and feature/version evidence.
Do not infer availability from version alone, invent a child profile parameter
or merge model/effort into the specialist identifier. Use independent native
fields only when the actual schema supports them. Specialist configuration
overrides and inherited provider conflicts that prevent the requested selection
are blockers, not reasons to change specialist or parent provider. Never assume
a profile switches a child's inherited provider.

### Configuration fallback and task pin

Missing, invalid or unresolvable selected implementation configuration triggers
a visible warning identifying the configuration fault, source and requested
tier. This includes duplicate effective mappings, disabled/inactive mappings and
unavailable mapped targets established during configuration-resolution checks.
Distinguish these from an actual execution failure, which does not trigger
configuration fallback. An inability to inspect configuration or enumerate the
environment is missing evidence, not proof of a faulty mapping.

Use only the current effective session selection, including its applicable
reasoning effort or variant, as the configuration fallback candidate. Verify it
is available, capable and explicitly routable to the same specialist before
dispatch. If usable, warn and continue without a routine prompt, retaining the
requested tier separately from the actual fallback selection. Do not manufacture
a variant such as `#high`, drop effort/variant or silently rely on inheritance.
No arbitrary working-model search, omitted-model defaults or workflow tier
escalation is permitted. Non-configuration capability or routing insufficiency
requires a decision, as does an unusable or unverifiable current model. A valid
mapping that cannot handle the task is not a configuration-fallback opportunity.

Pin the actual workflow selection before first dispatch in the existing task
record under `./workflow-artifacts.md`, with the complete selection provenance
required by `./task-briefs.md`. In-scope corrections must reuse that actual pin,
including a fallback pin; recheck availability, routing and configuration drift.
Do not reselect the then-current session model for corrections. Relevant drift
or any requested workflow model change requires explicit authorisation; record
the decision and revised pin rather than silently resolving again.

These rules govern workflow selection and configuration fallback only. Existing
external plugins' runtime retries and model switches remain outside this policy
and unchanged. Do not disable or block solely because of a runtime plugin.
Do not claim workflow pins prevent external runtime changes. Distinguish requested
workflow selection from observed effective runtime execution, recording available
harness evidence and any uncertainty. A worker self-report is not routing proof.

### Resolution procedure

Before every dispatch:

1. Enumerate the model identifiers exposed by the current environment using
   `{{MODEL_ENUMERATION}}`.
2. For implementation, resolve the native mapping or reuse the retained actual
   task pin as above. For preparation and reviews, select a model by the unchanged
   scope/capability policy. Verify explicit routing to the independent specialist
   using the actual exposed interface; do not invent parameters or schema fields.
3. Never construct an identifier from a pattern or rely on remembered
   availability. Confirm both identifier and routing support.
4. Confirm that the active primary-session model has high-capability reasoning
   before conversational Research or Planning. Skill metadata does not switch
   it. If it is unsuitable, ask the user to switch; do not replace the
   user-facing conversation with an unrequested detached agent.
5. If enumeration, routing or required capability cannot be verified, report
   a blocker. Apply only the bounded implementation configuration fallback above
   when its checks succeed. Otherwise do not silently inherit, downgrade or
   substitute a model. A user may explicitly authorise an alternative; record
   the decision and its consequence.

### Tier changes and blockers

Use the tier required by the task from the outset. Do not use a low-cost
implementer default for preparation or independent design/readiness reviews.
Do not silently change a workflow-selected tier after failure. For actual
execution failures, report the blocker and wait for explicit resolution; do not
force an unchanged workflow retry or escalate without authorisation. External
runtime plugin recovery remains outside this workflow-selection policy.

| You might think...                              | Reality |
|-------------------------------------------------|---------|
| "I know the naming pattern"                    | Enumerate the environment; never invent an identifier. |
| "This was available before"                     | Confirm current availability and routing for every dispatch. |
| "The examples list it"                         | Examples are not an availability guarantee. |
| "The skill metadata selected this model"        | Metadata does not switch the active primary model. |
| "I can silently use the inherited model instead"| Only a configuration fault permits the warned, checked, explicitly routed current-model fallback; missing routing or capability remains a blocker. |

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
