---
name: brainstorming-skip
description: "Lightweight design capture for cases where structured brainstorming would be overkill. Asks the user for a brief design statement, presents it for explicit approval, and hands off to create-tickets or subagent-driven-development. Only invoked from the brainstorming router when the user picks the skip option."
---

# Brainstorming (Skip)

The escape hatch for the brainstorming router. The user has indicated they already have a clear design and do not want to go through structured dialogue, walkthrough, or committee deliberation. This skill captures the user's design as a brief statement, gets explicit approval via plan mode, and hands off to implementation.

For the rule that no implementation may begin until the user has approved a design, see `../../rules/common/workflow.md`. The skip path satisfies that rule by capturing a brief design statement and getting explicit approval through `{{EXIT_PLAN_TOOL}}`.

## Preconditions

- You **MUST** be in plan mode before invoking this skill. The `brainstorming` router enters plan mode before invoking any mode skill. If you somehow arrived here without plan mode, enter it now using `{{ENTER_PLAN_TOOL}}`.
- This skill is invoked only from the `brainstorming` router after the user explicitly picks "Skip brainstorming". You **MUST NOT** invoke this skill directly to bypass the router.
- The skip option is for cases where the user already knows what they want. If the user is uncertain or asking for help with the design, this is the wrong skill, return to the router and let them pick a different mode.

## Procedure

1. **Ask for a brief design statement.** Use plain text (not `{{ASK_USER_QUESTION_TOOL}}`, because the answer is free-form). Ask the user to describe what they want to build in 1-3 sentences. Example: "What would you like to build? A 1-3 sentence description is enough, I will capture it as the approved design and proceed."

2. **Capture additional context if needed.** If the user's statement is so terse that you genuinely cannot derive acceptance criteria from it, ask one targeted follow-up question. **MUST NOT** stack multiple questions. **MUST NOT** turn this into a brainstorming dialogue, if you find yourself needing more than one follow-up, stop and tell the user that skip mode is the wrong choice for this work; they should re-invoke `brainstorming` and pick standard or guided mode instead.

3. **Present the captured design via plan mode.** Use `{{EXIT_PLAN_TOOL}}` to present the design statement as the plan content. Format:

   ```
   ## Approved Design (skip mode)

   **What to build:** [user's statement]

   **Acceptance criteria:** [bullets derived from the statement, or "as described above" if a short change]

   **Out of scope:** [anything the user explicitly excluded, or "nothing flagged"]
   ```

   The `{{EXIT_PLAN_TOOL}}` call IS the explicit approval step. The user accepts or rejects the design by approving or rejecting the plan.

4. **Decide the next step.** After plan mode is exited and the design is approved, use `{{ASK_USER_QUESTION_TOOL}}` to ask whether to create tickets or start implementation:

   ```
   {{ASK_USER_QUESTION_TOOL}}:
     question: "How would you like to proceed with this design?"
     header: "Next step"
     options:
       - label: "Implement directly"
         description: "Hand off to subagent-driven-development to implement this now."
       - label: "Create tickets first"
         description: "Hand off to create-tickets to track this work in the project's ticketing system."
     multiSelect: false
   ```

5. **Hand off via `{{INVOKE_SKILL_TOOL}}`.** Invoke `subagent-driven-development` or `create-tickets` per the user's choice. **MUST NOT** invoke any other skill from here.

## What Skip Mode Does Not Do

- It does not explore the codebase. The user has told you what they want; trust them.
- It does not ask clarifying questions beyond a single targeted follow-up.
- It does not run `design-review`. The user explicitly chose a lightweight path; running design-review would defeat the purpose. The trade-off is that the user is the only reviewer.
- It does not propose alternative approaches. The user already knows what they want.

If the user's request turns out to be ambiguous or larger than they thought, stop and tell them to re-invoke `brainstorming` and pick a different mode. Skip is not the right tool for everything.

## Worked Example

User invokes the router, picks "Skip brainstorming".

```
You: What would you like to build? A 1-3 sentence description is enough.

User: Add a --dry-run flag to the deploy script that prints what it would do without actually doing it.

[Use {{EXIT_PLAN_TOOL}} with:]
## Approved Design (skip mode)

**What to build:** Add a `--dry-run` flag to the deploy script that prints the actions it would take without executing them.

**Acceptance criteria:**
- The deploy script accepts a `--dry-run` flag
- When the flag is set, the script prints each action it would take, prefixed with `[dry-run]`
- When the flag is set, no actual deploy actions are executed
- The flag is documented in `--help` output

**Out of scope:** Nothing flagged.

[User approves via {{EXIT_PLAN_TOOL}}]

[Ask via {{ASK_USER_QUESTION_TOOL}}: Implement directly or Create tickets first?]
User picks: Implement directly

[Invoke {{INVOKE_SKILL_TOOL}}: subagent-driven-development]
```

## Completion Gate

You **MUST NOT** invoke `create-tickets` or `subagent-driven-development` until all of these are true:

- The user provided a brief design statement
- You presented it via `{{EXIT_PLAN_TOOL}}` and the user approved
- The user picked an implementation next step via `{{ASK_USER_QUESTION_TOOL}}`

If any one of these is false, the gate has not been crossed, and you **MUST NOT** hand off.

## Common Mistakes

| Mistake                                                          | Why it is wrong                                                                                                                                |
|------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Treating skip as "no design needed"                              | Skip is "lightweight design", not "no design". The brief statement IS the design.                                                              |
| Stacking multiple clarifying questions                           | Skip is the lightweight path. If you need a dialogue, the user should be in standard or guided mode instead.                                   |
| Skipping the `{{EXIT_PLAN_TOOL}}` step                           | `{{EXIT_PLAN_TOOL}}` is how the user approves. Without it, you have not satisfied the workflow.md "explicit approval" requirement.             |
| Running `design-review`                                          | The user explicitly chose a lightweight path. Running design-review defeats the purpose. The reviewer is the user.                             |
| Inventing requirements not in the user's statement               | YAGNI per `../../rules/common/coding-style.md`. The design covers what the user asked for, not what you would also build.                     |
| Routing to skip yourself instead of letting the user pick        | The router asks; the user picks. You **MUST NOT** invoke this skill except as a hand-off from the router after the user explicitly picks skip. |
