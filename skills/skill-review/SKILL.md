---
name: skill-review
description: "Audits a Claude Code skill against eight binary criteria by dispatching six fresh reviewer subagents (trigger, ambiguity, reachability, redundancy, prose economy, load model), returns a SOUND or NOT SOUND verdict with cited evidence, then applies the fixes the user accepts. Use whenever a skill is being written, changed, or handed over, whenever someone asks whether a skill is any good, whether its description fires reliably, whether it is bloated or repeats itself, whether its instructions are ambiguous, or whether any of its branches are unreachable. Works against any directory containing a SKILL.md, in any repository. For a code diff use `requesting-code-review`; for a design summary use `design-review`."
---

# Skill Review

Audits one skill as a written artefact and returns a verdict with the evidence behind it. Six reviewers each read the skill with fresh context through a single lens, every criterion they own comes back with a PASS or FAIL and a citation, and the fixes the user accepts are applied here.

The iron laws on subagent dispatch (context isolation, the git ban, the worktree ban, the privilege ban, and the ban on writing an identifier you have not confirmed the environment exposes) live in `../../rules/common/subagents.md`. The rule that implementation needs an approved design lives in `../../rules/common/workflow.md`, and the section below on what this skill may change explains how the approval gate in step 7 satisfies it.

Before running the procedure below, read `../_shared/subagent-dispatch.md` with the Read tool if you have not already read it this session. It holds the agent type lookup and the model resolution procedure this skill depends on, and a dispatch made without them in context is a guess.

## The Target Is Not This Repository

This skill audits any directory containing a `SKILL.md`, whatever repository it sits in and whatever conventions that repository holds. Its own dependencies (the rule files and `_shared/` files named above) come from its own installation and are always present. The target's surroundings are not, and nothing in the procedure may assume them.

The distinction matters most in the dispatch. A reviewer running in a session that has this repository's rules in context will fail a foreign skill for not following conventions its authors never adopted. The prompt template forbids that, and step 4 is where you catch it if the forbidding did not take.

## Preconditions

**A target skill.** A path to a directory containing `SKILL.md`. If the user named a skill without a path, resolve it against the skill directories available in this session before starting. If no `SKILL.md` is there, stop and say so; there is nothing to audit.

**No explanation from the author.** The reviewers receive the skill as written and nothing else. If the user offers what a step is meant to do, note it for yourself and do not pass it on. A skill that only works once its author has explained it is criterion 3 failing, and forwarding the explanation hides the finding this skill exists to produce.

## The Eight Criteria

Each criterion is binary and starts at FAIL. PASS is earned by a specific cited observation from the reviewer that owns it, never by nobody having raised the matter. The verdict is **SOUND** only when all eight pass, and **NOT SOUND** otherwise.

| #  | Criterion                                                                                                                                | Owned by      |
|----|------------------------------------------------------------------------------------------------------------------------------------------|---------------|
| C1 | The description states both what the skill does and the concrete situations that fire it                                                 | trigger       |
| C2 | No skill discoverable alongside it wins the prompts it claims, and it claims none of theirs                                              | trigger       |
| C3 | Every instruction is executable without a judgement the skill supplies no criterion for                                                  | ambiguity     |
| C4 | Every branch, table row, mode and return arm has an input that reaches it                                                                | reachability  |
| C5 | Every path ends in a hand-off, a return, a halt or an escalation                                                                         | reachability  |
| C6 | Nothing restates a file it references, or another part of itself, without a sync note on both sides                                      | redundancy    |
| C7 | Every sentence changes what the model does, so deleting it would change behaviour                                                        | prose economy |
| C8 | Every referenced path resolves, every loaded file is used and is loaded before the step needing it, and non-resident content is deferred | load model    |

NOT SOUND is a work list, not a condemnation. Most skills worth auditing fail at least one criterion, and a rubric that flatters is worth nothing to the person holding it.

## What This Skill May Change

The reviewers find issues; this skill applies the ones the user accepts. That makes it a skill that edits skills, so the boundary is what keeps it safe.

**In bounds:** files inside the target skill directory.

**Out of bounds:** every other file. A C2 finding often reads as though a sibling skill's description should change, and it may well be right, but editing a sibling to make the target pass is fixing the audit rather than the skill. Report it and let the user take it to that skill's own review. Renaming the target directory is out of bounds for a harder reason: the directory name is how the skill is invoked, so a rename breaks every caller that names it.

**The escape hatch.** If the fixes the user accepted would restructure the procedure rather than repair it, adding or removing steps, changing the control flow, or replacing the skill's approach, stop before editing and route to `brainstorming` instead. That work needs a design, and this skill has not produced one.

Applying accepted fixes without going through the `brainstorming` router is deliberate, and it follows the precedent `../../rules/common/workflow.md` already sets for `debugging` Phase 6. The fix is a consequence of evidence this skill has gathered and put in front of the user, the user approved each fix individually at step 7, and the only router mode that could apply would be skip. The escape hatch above is the line past which that argument stops holding.

## Procedure

1. **Resolve the target and confirm `SKILL.md` exists.** Stop if it does not.

2. **Run the mechanical pass yourself, inline.** It is deterministic, it is cheap, and doing it once here means six reviewers share one set of facts instead of six guesses at them. Collect:

   - **The file inventory.** `find <skill-dir> -type f | sort`.
   - **Frontmatter.** The `name` field, whether it matches the directory name, and the full `description`.
   - **Size.** `wc -l` across every markdown file in the directory.
   - **Referenced paths.** Extract every path-like string, including bare ones with no `./` prefix, and resolve each against the skill directory and the repository root. Record which resolve and which do not.

     ```sh
     grep -rnoE '[A-Za-z0-9._-]*(/[A-Za-z0-9._-]+)+' <skill-dir> | sort -u
     ```

   - **Orphans.** Every file in the directory that nothing in the directory references.
   - **Neighbours.** The name and description of every skill discoverable alongside the target, for C2.
   - **Stated conventions.** If the target repository has a `CLAUDE.md` or `AGENTS.md`, read what it states about skills or markdown. Pass on only what it actually states. A convention your own installation holds is not a convention the target adopted.

3. **Dispatch six reviewers in one message**, following `../_shared/skill-reviewer-prompt.md`. Each receives the full text of the skill, the mechanical inventory from step 2, and its own lens brief. Pass no session history and no author explanation.

   Issue all six `Agent` calls in the same message. Per the parallel dispatch rule in `../_shared/subagent-dispatch.md`, a dispatch issued in a later turn runs sequentially however it was described.

   Resolve the model per `../_shared/subagent-dispatch.md`, at dispatch time and every time. Start at the Low-cost default tier. Reviewing a procedure for reachability and ambiguity is design judgement, which that file's tier table maps to High-capability, so escalation as far as that tier is available, one tier at a time and only on evidence.

4. **Reconcile before concluding.** Read all six reports before acting on any of them, and check for the two failures `../_shared/subagent-dispatch.md` names:

   - **Overlap.** Two lenses often find the same defect from different angles. Merge them into one finding rather than reporting it twice, and keep it under the lower-numbered criterion.
   - **Systematic error.** Six agents reading the same text can share a blind spot, and convergence is as often that as it is proof. Convergence on a finding you can see is wrong in the text is your signal to re-dispatch that lens, not to report it.

   Also check for the failure specific to this skill: a finding that faults the target for a convention its repository never stated. Drop it and say you did.

5. **Assemble the criteria table.** Each criterion carries the verdict its owning lens returned, with that lens's citation. This step is assembly, not adjudication. If you disagree with a verdict, re-dispatch that lens with the evidence you are relying on; overwriting it puts your own unreviewed judgement into the table under a reviewer's name.

6. **Present the verdict, the table, and the findings** in the format below. Every finding carries a proposed fix.

7. **Take accept or reject on each finding from the user.** Use `AskUserQuestion` when the list is short enough to fit, otherwise present the numbered list and ask which to apply. Do not apply anything before this gate.

8. **Apply the accepted fixes** to files inside the skill directory. Check the escape hatch first.

9. **Verify.** Re-run the mechanical pass over the edited skill and confirm every referenced path still resolves. Re-dispatch only the lenses whose criteria the fixes were meant to flip, once. If a criterion the fixes targeted still fails, report it as still failing rather than dispatching again.

10. **Report the final table**, what was applied, what the user rejected, and anything the escape hatch stopped. Commit nothing.

### When a Dispatch Fails

A lens that returns no usable verdict, reports BLOCKED, or errors has reviewed nothing. Retry it once, escalating one tier per `../_shared/subagent-dispatch.md`. If the retry also fails, the criteria that lens owns stay at FAIL with "not reviewed, dispatch failed" as their evidence, and the verdict is NOT SOUND. Report the dispatch failure as the reason. A criterion nobody reviewed has not passed.

## Reporting Format

```text
SKILL REVIEW: <skill-name>
VERDICT: SOUND | NOT SOUND (<n> of 8 criteria failed)

| #  | Criterion       | Verdict | Evidence                          |
|----|-----------------|---------|-----------------------------------|
| C1 | ...             | PASS    | <cited observation>               |

FINDINGS
C4  <file>:<line>  <what is wrong>
    Why it matters: <what goes wrong when the skill runs>
    Proposed fix:   <the specific edit>

ADVISORY (fails no criterion, does not block)
    <observation>
```

Findings are grouped under the criterion they fail, in criterion order. Advisory observations are reported separately and never block the verdict, because a criterion is the only thing that can.

## Completion Gate

You **MUST NOT** report a verdict unless all of these are true:

- All six lenses returned in this invocation, or a failed dispatch is recorded against the criteria it owns.
- Every criterion carries a verdict and a citation from its owning lens.
- No criterion is marked PASS because no reviewer mentioned it.
- Every accepted fix is applied, and the mechanical pass has been re-run against the edited files.
- Every rejected finding is reported as rejected rather than dropped.

If any one is false, the gate has not been crossed.

## Red Flags

Every thought below means stop:

- "The description looks fine to me." You have read the skill. That is the condition under which its ambiguity becomes invisible, and it is why the lenses get fresh context.
- "This sentence reads nicely, keep it." C7 asks whether deleting it changes behaviour, not whether it is well written.
- "The reviewer missed the point, I will correct its verdict." Step 5 is assembly. Re-dispatch with your evidence instead.
- "Only one criterion failed, that is basically SOUND." SOUND is all eight.
- You are rewriting the skill rather than applying the fixes the user accepted. Step 8 has a boundary and the escape hatch is how you leave it.

## Common Mistakes

| Mistake                                                         | Why it is wrong                                                                                                                                        |
|-----------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| Passing session history or the author's explanation to a lens   | Violates context isolation, and a skill that needs its author present to make sense is the C3 finding you have just suppressed.                        |
| Reviewing a skill you wrote this session without dispatching    | You cannot audit prose for ambiguity while holding the intent that resolves it. The dispatch is the whole mechanism.                                   |
| Marking a criterion PASS because nobody raised it               | PASS is earned by a citation. Silence is a lens that found nothing to say, or a lens that did not look.                                                |
| Deleting prose that carries a constraint                        | The C7 failure mode. "Shorter" is not the goal; "every sentence load-bearing" is, and a deleted constraint changes behaviour by definition.            |
| Editing a sibling skill so the target passes C2                 | Out of bounds. That skill has its own callers and its own review. Report the overlap instead.                                                          |
| Renaming the skill directory                                    | The directory name is how the skill is invoked. A rename breaks every caller that names it.                                                            |
| Faulting the target against your own installation's conventions | The target adopted its repository's conventions, not yours. Only what its `CLAUDE.md` or `AGENTS.md` actually states counts.                           |
| Applying fixes before step 7                                    | The user's per-finding approval is what makes this skill's editing legitimate under `../../rules/common/workflow.md`. Without it there is no approval. |
| Dispatching the six lenses across separate messages             | That is sequential, whatever it was called. Parallelism comes from the message.                                                                        |
| Re-dispatching a lens because you dislike its verdict           | Re-dispatch on evidence, not on disagreement. Step 9 allows one confirming round, and a criterion that still fails is reported as failing.             |
