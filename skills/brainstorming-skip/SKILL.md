---
name: brainstorming-skip
description: "Lightweight design capture for cases where structured brainstorming would be overkill. Reuses a design already discussed in context when present, otherwise asks the user for a brief design statement; presents it for explicit approval and hands off to create-tickets or subagent-driven-development. Only invoked from the brainstorming router when the user picks the skip option."
---

# Brainstorming (Skip)

The escape hatch for the brainstorming router. The user already has a clear design and does not want structured dialogue, a walkthrough, or committee deliberation. This skill captures that design as a brief statement, gets explicit approval, and hands off to implementation. `../../rules/common/workflow.md` requires an approved design before any implementation, and skip satisfies that rule with the lightest artefact that still counts: a design the user has seen and agreed to.

## Preconditions

- **Plan mode.** The router enters it before handing off. If you arrived without it, call `EnterPlanMode`. Both it and `ExitPlanMode` are deferred tools in some sessions, meaning a direct call fails until the schema is loaded, so load them with `ToolSearch` (`select:EnterPlanMode,ExitPlanMode`) first.
- **If the router reports that plan mode could not be entered**, take the degraded path in step 4 rather than stopping. Plan mode is how approval is usually captured, not what makes approval real. Skip is the only mode whose approval rests on a single tool call, so treating that call as the requirement would leave the user with no legal route to any code edit at all.
- **The router picks the mode, not you.** This skill runs as a hand-off after the user explicitly chose skip. Deciding on their behalf that work is small enough for skip is the one judgement `../../rules/common/workflow.md` reserves for them.
- **Skip assumes certainty.** If the user is uncertain or asking for help with the design, send them back to the router for standard or guided mode.

## Procedure

1. **Look for a design already in context.** Prior discussion, harness-supplied context, or attached resources may already say what the user wants built. If so, that is the design statement; use it as-is. Asking someone to restate what they said five messages ago is the fastest way to make the lightweight path feel heavier than the alternatives.

2. **Otherwise ask for one.** Plain text rather than `AskUserQuestion`, because the answer is free-form: "What would you like to build? A 1-3 sentence description is enough, I will capture it as the approved design and proceed."

3. **Ask at most one follow-up, and only if you genuinely cannot derive acceptance criteria.** A contradiction, a missing decision you cannot infer, or a statement too vague to act on all qualify; double-checking something already clear does not. If one follow-up is not enough, that is the signal skip is the wrong fit: say so and send the user back to the router. Stacking questions rebuilds standard mode, badly.

4. **Present the design for approval.** Write the block below and call `ExitPlanMode`. That call is the approval step: the user accepts or rejects the design by approving or rejecting the plan. Where plan mode is unavailable, post the same block as plain text, ask directly for approval, and tell the user the plan-mode gate was unavailable so they know what they are carrying.

   ```
   ## Approved Design (skip mode)

   **What to build:** [the statement]

   **Acceptance criteria:** [bullets traceable to the statement, or "as described above" for a short change]

   **Out of scope:** [what the user excluded, or "nothing flagged"]
   ```

   For work escalated from `debugging`, where the root cause is confirmed but the fix is too large to apply minimally, add the root cause, the reproduction approach, and the modules that will change, which is what `../../rules/common/workflow.md` asks a bug-fix design to carry. Ordinary bug fixes never reach here: `debugging` Phase 6 takes its own approval and Phase 7 applies the fix inline.

5. **Ask what happens next.** Use `AskUserQuestion` with two options: "Implement directly" and "Create tickets first".

6. **Hand off via `Skill`.** Either `create-tickets`, or the orchestrator chosen per the "Choosing an Orchestration Skill" table in `../../rules/common/skills-policy.md` (`subagent-driven-development` by default, `team-driven-development` when the design qualifies for parallel execution, `dispatching-parallel-agents` for a stateless one-shot fan-out). Nothing else.

## What Skip Mode Does Not Do

It does not explore the codebase, propose alternative approaches, or run `design-review`. The user chose a lightweight path and is themselves the reviewer; that is the trade they made, and re-adding any of it defeats the point.

One consequence is worth stating plainly: because a skip-mode design carries no file-level evidence, `complexity-triage` downstream will usually classify the work COMPLEX. That is the expected outcome rather than a failure of skip mode. Triage reads the code itself; skip does not pre-empt it.

## Worked Example: Design Reused From Context

Earlier in the conversation the user said "let's add a `--dry-run` flag to the deploy script that prints what it would do". They then invoke the router and pick skip.

```
[No re-prompt. The design is already in context.]

[ExitPlanMode with:]
## Approved Design (skip mode)

**What to build:** Add a `--dry-run` flag to the deploy script that prints the actions it would take without executing them.

**Acceptance criteria:**
- The deploy script accepts a `--dry-run` flag
- When the flag is set, the script prints each action it would take
- When the flag is set, no deploy actions are executed

**Out of scope:** Nothing flagged.

[User approves.]

[AskUserQuestion: implement directly, or create tickets first? User picks implement directly.]

[Skill: subagent-driven-development]
```

Note what is absent: no `--help` documentation, no output prefix. Both would be reasonable things to build, and neither was asked for.

## Worked Example: Too Big For Skip

The user picks skip and says "replace the auth system with SSO".

```
You: Which identity provider, and does this cover the mobile clients too?

User: Not sure yet, probably Okta, and mobile is complicated because of the token store.

[Stop. Do not ask a second follow-up.]

You: That is two open decisions rather than one gap, so skip mode would produce a design thinner
than the work. Re-invoke `brainstorming` and pick standard mode, or guided if auth is unfamiliar.
```

No `ExitPlanMode`, no hand-off. Bouncing back costs one message; handing off a design with an undecided identity provider costs a whole implementation pass.

## Completion Gate

Do not invoke `create-tickets` or any orchestration skill until all three of these hold:

- A design statement has been captured, whether from context or from the user
- It was presented and explicitly approved, via `ExitPlanMode` or via the degraded plain-text path when plan mode was unavailable
- The user picked a next step via `AskUserQuestion`

## Common Mistakes

| Mistake                                                       | Why it is wrong                                                                                                     |
|---------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| Treating skip as "no design needed"                           | Skip is lightweight design, not absent design. The brief statement is the design.                                   |
| Inventing requirements the user did not state                 | YAGNI per `../../rules/common/coding-style.md`. Acceptance criteria elaborate the statement; they do not extend it. |
| Treating unavailable plan mode as permission to skip approval | The gate is the user's explicit yes. Losing the tool that usually captures it does not remove the requirement.      |
| Pushing on through a second and third follow-up               | Two gaps means the work needs a dialogue. Bounce back to the router rather than rebuilding standard mode here.      |
