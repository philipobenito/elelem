---
name: design-review
description: "Reviews a consolidated design summary for completeness, consistency, clarity, scope, and YAGNI by dispatching a fresh reviewer subagent against the summary text alone. Invoked by `brainstorming-standard`, `brainstorming-guided`, and `brainstorming-committee` once the design is consolidated and before final user approval; `brainstorming-skip` deliberately does not use it. Returns an approved summary, the open decisions the design never made, or an escalation once its three-dispatch budget is spent."
---

# Design Review

Runs a holistic pass over a consolidated design summary, catches what section-by-section approval missed, and returns an approved design, the open decisions it uncovered, or an escalation.

For the rule that no implementation may begin until a design has been approved, see `../../rules/common/workflow.md`. The iron laws on subagent dispatch (context isolation, the git ban, the worktree ban, the privilege ban, and the ban on writing an identifier you have not confirmed the environment exposes) live in `../../rules/common/subagents.md`.

Before running the procedure below, read `../_shared/subagent-dispatch.md` with the Read tool if you have not already read it this session. It holds the type selection and model resolution procedures this skill depends on, and a dispatch made without them in context is a guess.

## Preconditions

**A consolidated summary.** The caller has produced the design as a single self-contained block of text. Reviewing a design that lives only in conversation history is forbidden: the reviewer receives the summary and nothing else, so anything that only makes sense against the conversation is not in the design.

Self-contained is the whole precondition. A summary missing a section is not a precondition failure, it is a Completeness issue and the reviewer's job to find. Checking sections off a list here would review the design twice and reach the reviewer's verdict without the reviewer.

**A caller.** This skill runs as a step inside a design mode (`brainstorming-standard` step 6, `brainstorming-guided` step 6, `brainstorming-committee` step 9), never on its own and never against a design the user has not worked through. `brainstorming-skip` deliberately does not invoke it: the user chose a lightweight path and is themselves the reviewer.

## What This Skill May Change

The reviewer finds issues; this skill fixes them and re-reviews. That makes it the only skill in this set that edits an artefact the user has already approved, so the boundary on what it may edit is what keeps it safe.

Sort every issue before touching the summary:

| Class            | Test                                                                                                                                               | Response                                           |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------|
| **Determined**   | The design already contains what is needed to resolve it. Any competent implementer would resolve it the same way.                                 | Fix it in the summary and re-dispatch.             |
| **Undetermined** | Resolving it takes a choice the design does not contain. Two competent implementers could resolve it differently, both consistent with the design. | Stop. Return it to the caller as an open decision. |

An undetermined issue is not a defect in the writing, it is a decision nobody has made. Answering it here means an agent picks a behaviour, a cost, or a trade-off on the user's behalf and reports it afterwards as a change to a design they had already approved. The caller is the one holding the user, so open decisions go back immediately rather than after two more dispatches.

### Substantive and Editorial Fixes

Determined issues divide again, and the caller branches on which. A fix is **substantive** when an implementer would produce different code from the two versions of the summary, and **editorial** when it changes only how the design is expressed.

| Fix                                                                                                                                                                              | Class       | Why                                                                                                                   |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|-----------------------------------------------------------------------------------------------------------------------|
| Components says `IngestWorker`, data flow says "the ingest worker", error handling says `Worker`; settle on `IngestWorker` throughout                                            | Editorial   | Nothing built changes. The reader stops having to check they are the same thing.                                      |
| Components lists `IngestWorker` and interfaces never says how it is invoked; data flow says the scheduler triggers it every five minutes, so write it as a scheduled entry point | Substantive | The design determined it, but an implementer previously had to guess between a queue consumer and a cron entry point. |
| Error handling says "retry with backoff" and never gives an attempt count; pick three                                                                                            | Neither     | Undetermined. Three, five and ten are all consistent with the design, so this is an open decision rather than a fix.  |

Report every substantive fix when you return. The user approved text that no longer reads the same way, and the caller decides how to put that to them.

## Procedure

1. **Confirm the summary is consolidated.** If the caller has not produced a single self-contained block, stop and return **Not consolidated** per the Return Contract. Do not consolidate it yourself: the caller holds the conversation the summary has to be built from.

2. **Dispatch the reviewer** with `Agent`, following `design-reviewer-prompt.md`. Paste the full summary into the prompt and pass no session history.

   Resolve the subagent type and the model per `../_shared/subagent-dispatch.md`, at dispatch time and every time. Start at the Low-cost default tier. This skill's task signal is design judgement, which that file's tier table maps to High-capability, so escalation as far as that tier is available here. It is still one tier at a time and still only on evidence, per the no-pre-escalation rule: a dispatch that returned nothing but editorial noise, a dispatch that missed something you can see in the summary yourself, or a design whose architecture turns on several interacting components.

3. **Read the reviewer's status.**
   - **Approved**: go to step 7.
   - **Issues Found**: sort each issue as determined or undetermined per the table above.
   - **Neither, or the dispatch failed**: see "When the Dispatch Fails" below.

4. **Return early if any issue is undetermined.** Stop the loop and return **Decision required** with those issues and the current summary. Apply the determined fixes first, so the caller carries a summary as far along as it can honestly be, and say which you applied. Those fixes go back unreviewed on purpose: a Decision required return comes back here as revised text, and the fresh review that revision earns will see them.

5. **Fix the determined issues** by editing the summary text. Record which fixes were substantive.

6. **Re-dispatch** against the updated summary and return to step 3. At most three dispatches in this invocation. When the third returns anything other than Approved, stop and return **Issues outstanding**.

7. **Return the approved summary** per the Return Contract, carrying the substantive fixes and the reviewer's recommendations.

### When the Dispatch Fails

A dispatch that returns no usable status, reports BLOCKED, or errors has reviewed nothing, so it spends no budget. Retry it once, escalating one tier per `../_shared/subagent-dispatch.md`. If the retry also fails, the review cannot be performed here: return **Issues outstanding** with the dispatch failure as the outstanding item, so the decision reaches a human rather than a third attempt.

## Return Contract

This section is addressed to whichever skill invoked this one, and it lives here rather than being restated in each caller because invoking `design-review` is what loads this file: the caller has this text in context at exactly the moment it needs it. A caller that re-implements the loop above instead of following it ends up running this skill's fix-and-re-dispatch cycle twice.

**Approved.** The caller receives the design summary text, every substantive fix made during the review enumerated (or an explicit statement that there were none), and the reviewer's advisory recommendations. The caller continues. A substantive fix means the user approved a design this skill then altered, so the caller surfaces it before treating the design as settled. The recommendations travel unapplied: they are advisory by construction, and applying them would be this skill editing an approved design over things the reviewer did not consider issues.

**Decision required.** The design has a hole only a person can fill. The caller receives the open decisions, the current summary, and any determined fixes already applied. The caller **MUST NOT** answer the decisions itself and **MUST NOT** re-invoke this skill against unchanged text, because a reviewer cannot supply what the design never contained. It takes them to the user, or in `brainstorming-committee` to a targeted deliberation round, then invokes this skill again against the revised summary.

**Issues outstanding.** The three-dispatch budget is spent and issues remain, or the reviewer could not be dispatched. The caller receives those issues alongside the current summary, and **MUST NOT** invoke this skill again in the hope of a better verdict. The budget exists so that a design which will not converge reaches a human rather than a fourth reviewer. The caller stops and puts the decision to the user.

**Not consolidated.** The precondition failed. Nothing was reviewed and no budget was spent. The caller consolidates the design into a single self-contained block and invokes this skill again.

**Invoking again after the summary changes.** An Approved status covers the exact text that was reviewed. If the caller then changes the summary substantively, because the user revised it, because an open decision came back answered, or because a flagged reviewer edit went through another design round, the Approved no longer describes the text the caller is holding, and the caller invokes this skill again against the new summary. That is not budget evasion; it is a first review of content no reviewer has seen, and it gets a full budget. The distinction that matters is what prompted the new invocation: new content, or an unwelcome verdict on unchanged content.

Nothing bounds how many times that can happen, and nothing needs to. Every round passes through the user, so no loop runs unattended, and a design cycling through here repeatedly is telling the caller something its own design procedure should be catching upstream.

## What the Reviewer Checks

| Category     | What to look for                                                               |
|--------------|--------------------------------------------------------------------------------|
| Completeness | Gaps, undefined behaviour, missing components, unanswered questions            |
| Consistency  | Contradictions between sections, conflicting requirements                      |
| Clarity      | Requirements ambiguous enough that someone could build the wrong thing         |
| Scope        | Focused enough for a single plan, not covering multiple independent subsystems |
| YAGNI        | Unrequested features, over-engineering, unnecessary complexity                 |

This table exists here so step 3 can categorise what comes back. The reviewer's own copy, along with the calibration that stops it flagging stylistic preferences and the rules bounding what it may read, lives in `design-reviewer-prompt.md`. Keep the two copies of this table in sync when editing either file.

## Worked Example: An Open Decision

The caller (a brainstorming skill) consolidates a design for a new ingest pipeline and invokes this skill.

**Iteration 1** flags two issues.

- *Interfaces section never says how `IngestWorker` is invoked.* Determined: the data flow section already says the scheduler triggers it every five minutes. Fixed by writing the interface as a scheduled entry point, and recorded as substantive, because an implementer previously had to guess between that and a queue consumer.
- *Error handling never says what happens when the upstream feed returns malformed records.* Undetermined. Dropping them, dead-lettering them, and halting the pipeline are all consistent with the design, and each carries a different operational cost. Nothing in the summary chooses between them.

Return **Decision required** with the malformed-record question, carrying the summary with the interface fix applied and flagged. Note what did not happen: this skill did not add a dead-letter queue and report it afterwards. That would have committed the user to a component, a failure mode, and an operational cost they had never seen, on the strength of a reviewer's observation that something was missing.

The caller puts the question to the user, who picks a dead-letter queue with a seven-day retention. The caller revises the summary and invokes this skill again. That is new content, so it gets a fresh review.

**Second invocation, iteration 1** returns Approved with one advisory recommendation about consistent terminology. Return **Approved**, carrying the recommendation and no substantive fixes.

## Worked Example: The Budget Runs Out

A design for a permissions overhaul.

- **Iteration 1**: three issues, all determined, all fixed.
- **Iteration 2**: the reviewer accepts those and raises two more in the sections the fixes touched. Both determined, both fixed.
- **Iteration 3**: the reviewer finds the role model in the architecture section contradicting the permission check described in data flow, a contradiction the earlier fixes made visible.

That third issue is real and it is determined, so a fourth dispatch is tempting. The budget says no, and the reason is in the pattern rather than the issue: the summary has been rewritten twice and is still contradicting itself, which is the signal that the problem is the design and not its expression. Return **Issues outstanding** with the contradiction and the current summary. The caller stops and puts it to the user, who takes it back through a design round rather than another review.

## Completion Gate

You **MUST NOT** return Approved unless all of these are true:

- The most recent dispatch **in this invocation** returned Approved. A previous Approved from earlier in the session, or your own belief that what remains is minor, does not count.
- Every issue raised across every dispatch is either fixed in the text you are returning, or was undetermined and returned as an open decision instead.
- Every substantive fix is enumerated in the return, or you have stated explicitly that there were none.
- The reviewer's recommendations travel with the return.

If any one is false, the gate has not been crossed.

## Red Flags

Every thought below means stop:

- "I know what they would want here", about a question the design does not answer. That is an open decision and it belongs to the user.
- "This is close enough to Approved." The verdict comes from a dispatch, not from you.
- "One more dispatch and it will converge." The budget is the answer to that thought, not an obstacle to it.
- You are rewriting or expanding the summary rather than fixing specific issues in it. You are reviewing a design, not writing one.

## Common Mistakes

| Mistake                                                             | Why it is wrong                                                                                                                                                      |
|---------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Passing session history to the reviewer                             | Violates context isolation. The reviewer reads the design summary, otherwise it grades the conversation rather than the design.                                      |
| Skipping the dispatch and reviewing the summary yourself            | The orchestrator's perspective is not a fresh review. The whole point is the second pair of eyes.                                                                    |
| Answering an undetermined issue yourself                            | The design never made that decision, so filling it in commits the user to a choice they have not seen. It goes back to the caller, who has the user.                 |
| Treating a missing section as a precondition failure                | The precondition is that the summary stands alone, not that it is complete. Completeness is what the reviewer is for.                                                |
| Continuing past three dispatches                                    | The budget exists to prevent endless polish loops. Past three, the caller and the human need to decide whether to redesign.                                          |
| Counting a failed dispatch against the budget                       | A dispatch that errored reviewed nothing. Retry it once at the next tier; spending budget on it burns a review the design never got.                                 |
| Pre-escalating to the top tier because the task is design judgement | The signal permits the tier, it does not start you there. `../_shared/subagent-dispatch.md` still requires one tier at a time, on evidence.                          |
| Treating advisory recommendations as blockers                       | Recommendations are advisory. Only Issues block.                                                                                                                     |
| Dropping the recommendations because they are advisory              | The reviewer produced them from a fresh reading and they cost nothing to carry. Advisory means the caller decides, not that the output is discarded on the way back. |
| Returning Approved without re-dispatching after fixes               | The Approved status must come from a reviewer run against the updated summary, not the original.                                                                     |
