# Workflow

## Design Before Implementation

You **MUST NOT** write production code, scaffold a project, or invoke an implementation skill until a design has been presented and explicitly approved by your human partner. Trivial changes get trivial designs, still presented and still approved. A design never exists only in your own context.

### The Routing Ask

This file names each stage's job, never the skill that does it. At every routing moment you **MUST** put the choice to your human partner with `AskUserQuestion`, and you **MUST** build the options at ask time: enumerate the skills available in the session, match their descriptions against the stage's job as stated here, and list the recommended fit first. No skill name is hard-coded, so a renamed, added, or withdrawn skill changes the options rather than breaking the route.

Explicit user vocabulary invoking a specific skill's procedure is itself the answer: run that skill and skip the ask. Where no available skill matches the stage's job, the ask still fires, carrying the direct option plus whatever partial fits exist, so a missing or renamed skill surfaces visibly in the option list instead of being silently defaulted around. An answer outside the offered options is new instruction rather than a routing choice: it returns to your human partner, and no route is taken from it.

### The Design Threshold

The change's own evidence picks between two paths. The inline path applies only when all three hold, judged on code you have read rather than the feel of the request:

1. **Fully determined.** The request plus the code you have read fixes every remaining choice.
2. **No new surface.** No new endpoint, export, event, contract, configuration key, or component.
3. **Glanceable.** The whole design fits in a statement the user can read at a glance.

Where any criterion fails, or you cannot tell, the change is above the threshold: if classifying it takes real investigation, that difficulty is itself the verdict.

Below the threshold, present a short design statement (what changes, where, the acceptance criteria) and get explicit approval before any edit; no skill, no plan mode. Above it, the routing ask decides how the design is run, offering one option per available skill whose description claims turning an idea into an approved design as its job. Where no such skill is available, the ask's direct option means designing in conversation, presented and explicitly approved as the opening of this section requires. Each design skill carries its own plan-mode mechanics, scope rules, and completion gate.

Once an above-threshold design is approved and implementation is about to begin, whether it arrived from a design skill's hand-off, recovery from a ticket, or a committed specification the user points at, the routing ask decides how it is built. The options are "Implement directly", meaning the lead implements it in this session with the TDD, review, and verification gates applying unchanged, plus one per available skill whose description claims implementation of an approved design as its job. Below the threshold, implement the approved statement directly, with no ask. A bug fix is built inside `debug-investigation`, which takes its own fix approval.

### Approval

What counts: an explicit yes to a presented design, a ticket or specification the user wrote or previously approved, or the fix approach approved inside `debug-investigation`. What does not: silence, an unreviewed "looks fine", or your own unconfirmed interpretation.

### Bug Fixes

Bug fixes need an approved design too, at minimum the reproduction approach and the module that will change. Approval comes from `debug-investigation`'s own fix-approval phase; route to the design stage, through the same routing ask, only when the fix outgrows the minimal fix principle in `debugging.md` and needs decomposing.

## Waiving a Gate

User instructions say *what* to do; these rules say *how*. Casual phrasing ("just add X") does not waive the design step, TDD, review, or verification; only an explicit, scoped opt-out does ("skip TDD for this prototype"), and you **MUST** confirm it before acting on it. You **MUST NOT** invoke a rule or skill to override an explicit user instruction; the user is in control.

## Sequencing and Stopping

Complete changes in the design's order; where unspecified, foundations first, then features, integration, polish. You **MUST NOT** reorder tasks to make progress look faster or to avoid a harder task. Stop and consult your human partner when the design proves wrong mid-implementation, a blocked subagent changes the scope, a verification failure implicates the design, or you are about to bypass any rule in these instructions; "one small thing first, tell them after" is not acceptable.
