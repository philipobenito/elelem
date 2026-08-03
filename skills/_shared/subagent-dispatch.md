# Subagent Dispatch - Procedural Rules

These rules apply to every subagent dispatch made from inside a skill. They are the procedural detail behind the iron laws in `../../rules/common/subagents.md`. The iron laws (context isolation, the git ban, the worktree ban, the privilege ban) live in the always-on rule file and bind whether or not a skill is running. The rules below govern *how* a dispatch is constructed and managed once a skill has decided to dispatch.

Skills that dispatch subagents (`debugging`, `design-review`, `requesting-code-review`, `skill-review`) **MUST** read this file before performing a dispatch.

## Agent Type

Per `../../rules/common/subagents.md`, agent type is a lookup. Dispatch templates already carry the value; this table is the source they follow.

| Dispatch                                                  | Type              |
|-----------------------------------------------------------|-------------------|
| Implementers                                              | `general-purpose` |
| Code reviewers                                            | `general-purpose` |
| Debugging evidence gatherers and hypothesis investigators | `general-purpose` |
| Design reviewer                                           | `Plan`            |
| Skill reviewer lenses                                     | `Plan`            |

Both types carry `Bash`, so a read-only boundary that matters **MUST** be stated in the dispatched prompt as well.

## Model Selection

You **MUST** select the tier whose task signal matches the dispatch, using the tier table below, and choose exactly one concrete model per dispatch. The signal decides the starting tier: a clearly specified small change starts low, and design judgement starts high. Do not start every dispatch at the bottom to save per-call cost. A dispatch that fails for want of capability consumes a review, a fix round trip and a re-dispatch, which together cost more tokens and more wall-clock than starting where the signal points.

A reviewer **MUST NOT** run at a lower tier than the work it is reviewing. A review is the last gate before the work is accepted, so a reviewer that misses a real defect is the most expensive failure a dispatch can produce, and no per-call saving covers it.

### Tier Table

| Tier                | Task signal                                    | Anthropic family                                                              |
|---------------------|------------------------------------------------|-------------------------------------------------------------------------------|
| Low-cost default    | Clear spec, 1-3 files                          | Haiku                                                                         |
| Standard escalation | Multi-file integration, judgement              | Sonnet                                                                        |
| High-capability     | Design judgement, broad codebase understanding | Opus or Fable (the inherited session model is also an acceptable choice here) |

The Anthropic column is a worked example, not an allowlist. Model catalogues change faster than this file, so no column written in advance can be authoritative on its own. Treat the table as a guide to tiers and use the resolution procedure below to pick a concrete model from whatever the environment actually exposes, listed here or not.

### Resolution Procedure

Naming a tier is not the same as producing a value the harness will accept. Before every dispatch:

1. Always enumerate the models the current environment actually exposes by reading the `model` enum on the Agent tool schema, which is the set of values the harness will accept.
2. Map the chosen tier to a concrete value from that enumeration.
3. Never construct an identifier from a pattern. Recognising the shape of an identifier is not the same as confirming it exists.
4. If no family listed in the tier table is exposed, order the available models from least to most capable and take the one whose position matches the chosen tier.
5. If enumeration is impossible, use the inherited session model and state in your response to the user that you did so. Never fall back silently.

### Escalation Triggers

Start at the tier the task signal names. Escalate exactly one tier at a time, and only on evidence: a failed attempt at the current tier, or a complexity signal the starting choice missed. Starting at the tier the signal names is not pre-escalation. Escalating beyond it on the assumption that a task might be hard is, and you **MUST NOT** do it: name the signal, or stay at the tier the named signal maps to.

### Rationalisation Prevention

Every thought below means **stop and re-run the resolution procedure**:

| You might think...                                      | Reality                                                                                                                                                           |
|---------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| "I know the naming pattern, I can write the identifier" | Recognising the shape of an identifier is not confirming it exists. Constructing an identifier from a pattern is inventing it; enumerate the environment instead. |
| "This was valid last month"                             | Catalogues change. Re-verify against the current environment before every dispatch, not from memory.                                                              |
| "The table lists it, so it exists"                      | The tier table is a worked example, not an availability guarantee. Confirm the value against the enumerated list.                                                 |
| "I will use the session model to be safe"               | "To be safe" is not a task signal. Name the signal from the tier table that maps to the tier you chose, or drop to the tier your named signal maps to.            |

## Parallel Dispatch

When more than one subagent runs concurrently, two mechanics bind in addition to everything above. They apply to any concurrent round, whatever the dispatching skill is doing with it.

**Parallelism comes from the message, not the intent.** Issue every `Agent` call for a concurrent round in the same message. A dispatch issued in the next turn runs only after the previous one has returned, which is sequential however it was described.

**Reconcile before drawing conclusions.** When a concurrent round returns, read every agent's full report before acting on any of them, and check for:

- **File-level overlap**, for any agent that wrote to the tree. If two agents touched the same file, read both diffs and confirm neither edit overwrote the other. Work that cannot be partitioned into non-overlapping write sets **MUST** be serialised instead of dispatched concurrently.
- **Systematic error.** Agents working in isolation can reach the same wrong conclusion. Convergent answers from isolated agents are as often a shared blind spot as they are proof.

For a round that changed the tree, per-agent local verification does not satisfy `../../rules/common/verification.md`. Run the full suite against the merged state; concurrent changes only pass the gate once they pass together. If reconciliation fails, use the Escalation section below. You **MUST NOT** patch a subagent's output manually in the orchestrator context.

## Answering Subagent Questions

When a subagent asks a question before or during its task, you **MUST** answer it clearly and completely before allowing the subagent to proceed. You **MUST NOT** rush a subagent into implementation, and you **MUST NOT** ignore a question in the hope the subagent will work it out alone.

## Process Discipline

When orchestrating subagents, you **MUST NOT**:

- Skip reviews, whether combined or separate
- Proceed to the next task while a review has unfixed issues
- Accept "close enough" on spec compliance. If the reviewer found issues, the task is not done.
- Let the implementer's self-review replace the external review. Both are required.
- Force the same model to retry a failed task without changing anything (more context, different model, smaller scope, or escalation to the human)
- Attempt to fix a subagent's output manually in the orchestrator context. Re-dispatch with a better context instead. Manual fixes pollute the orchestrator's context and defeat the isolation.

## Escalation

If a subagent reports BLOCKED or fails repeatedly, you **MUST** do one of the following and nothing else:

- Provide more context and re-dispatch
- Re-dispatch with a more capable model
- Split the task into smaller pieces
- Stop and escalate to the human per `../../rules/common/workflow.md`

You **MUST NOT** ignore an escalation. You **MUST NOT** pretend a failed task succeeded.
