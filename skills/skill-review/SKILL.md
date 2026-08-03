---
name: skill-review
description: "Audits a Claude Code skill against eight binary criteria by dispatching six fresh reviewer subagents (trigger, ambiguity, reachability, redundancy, prose economy, load model), returns a SOUND or NOT SOUND verdict with cited evidence, then applies the fixes the user accepts. Use whenever a skill is being written, changed, or handed over, whenever someone asks whether a skill is any good, whether its description fires reliably, whether it is bloated or repeats itself, whether its instructions are ambiguous, or whether any of its branches are unreachable. Works against any directory containing a SKILL.md, in any repository. For a code diff use `work-review-request`; for a design summary use `design-review`."
---

# Skill Review

Audits one skill as a written artefact and returns a verdict with the evidence behind it. Six reviewers each read the skill with fresh context through a single lens, each is dispatched again against the unchanged text until it stops returning anything new, every criterion they own comes back with a PASS or FAIL and a citation, and the fixes the user accepts are applied here and then reviewed as a set of edits.

## The Target Is Not This Repository

This skill audits any directory containing a `SKILL.md`, whatever repository it sits in and whatever conventions that repository holds. The target's surroundings are not assumed, and nothing in the procedure may assume them.

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

**The severity floor.** Not everything a lens returns can fail a criterion. The bar a finding must clear is the severity floor in the Calibration section of the lens prompt below, which every lens applies at source; hold the merged list to that same bar when you reconcile at step 4. What does not clear it is Advisory: reported, and never counted against a criterion or the verdict. Without a floor, C5 and C7 can always yield one more finding on a branchy document, so a skill that is genuinely good never passes and the verdict stops carrying information.

NOT SOUND is a work list, not a condemnation. Most skills worth auditing fail at least one criterion, and a rubric that flatters is worth nothing to the person holding it.

## What This Skill May Change

The reviewers find issues; this skill applies the ones the user accepts. That makes it a skill that edits skills, so the boundary is what keeps it safe.

**In bounds:** files inside the target skill directory.

**Out of bounds:** every other file. A C2 finding often reads as though a sibling skill's description should change, and it may well be right, but editing a sibling to make the target pass is fixing the audit rather than the skill. Report it and let the user take it to that skill's own review. Renaming the target directory is out of bounds for a harder reason: the directory name is how the skill is invoked, so a rename breaks every caller that names it.

**The escape hatch.** If the fixes the user accepted would restructure the procedure rather than repair it, adding or removing steps, changing the control flow, or replacing the skill's approach, stop before editing and route to `design-grill-me` instead. That work needs a design, and this skill has not produced one.

Applying accepted fixes without a separate design session is deliberate, on the same footing as a bug fix's approval: the fix is a consequence of evidence this skill has gathered and put in front of the user, and the user approved each fix individually at step 7, which is exactly the seen-and-approved design that implementation requires. The escape hatch above is the line past which that argument stops holding.

## Applying Every Finding Is Not Automatically Correct

A fix is an edit to a procedure, and most fixes close a gap by adding an arm: another branch, another table row, another "otherwise". Every arm is new surface, so the fix that closes one finding is where the next two come from, and a fix can cost more than the finding it closed. Prefer a fix that deletes or consolidates over one that adds an arm. Where only an added arm will do, say so when you present the finding at step 6, so the user reaches the step 7 gate with that cost visible rather than accepting a list.

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

3. **Dispatch the six lenses, and keep dispatching each one until it goes dry**, using the lens prompt below. Every dispatch receives the full text of the skill, the mechanical inventory from step 2, and its own lens brief, and nothing else: no session history, no author explanation, and nothing an earlier round returned.

   One dispatch returns a lens's most salient findings rather than a census of them, so a lens that reported five defects has not necessarily run out of them. Re-dispatch it against the same unchanged text with the same prompt. The prompt stays identical on purpose: telling a lens what an earlier round found anchors it onto that list, and since the text has not changed, an unanchored reading is a fresh sample rather than a repeat.

   **Rounds.** Round 1 dispatches all six lenses. Each later round re-dispatches only the lenses that were not dry in the round before it. Issue every `Agent` call belonging to one round in the same message: a dispatch issued in a later turn runs only after the previous one has returned, which is sequential however it was described. Reconcile a round through step 4 before deciding who is re-dispatched, because dryness is a judgement about the merged list rather than about one report.

   **Dry** means the round returned no finding that clears the severity floor and that you have not already recorded. The deduplication is yours and not the lens's, which cannot know what its predecessors said: two reports of one defect in different words are one finding.

   **The bound is three rounds per lens.** A lens still returning new findings in its third round is not dispatched a fourth time. Its criteria carry the verdicts its last round returned, its outstanding findings are reported like any others, and the report records the bound as reached with that lens still producing. A lens that cannot be exhausted in three readings of unchanged text is evidence the skill needs restructuring rather than repair, which is the escape hatch in step 8 and not a fourth round.

   Resolve the model per "Selecting the Model" below, at dispatch time and every time.

4. **Reconcile before concluding.** Read every report in the round before acting on any of them, and check for two failures:

   - **Overlap.** Two lenses often find the same defect from different angles. Merge them into one finding rather than reporting it twice, and keep it under the lower-numbered criterion.
   - **Systematic error.** Six agents reading the same text can share a blind spot, and convergence is as often that as it is proof. Convergence on a finding you can see is wrong in the text is your signal to re-dispatch that lens, not to report it.

   Also check for the failure specific to this skill: a finding that faults the target for a convention its repository never stated. Drop it and say you did.

5. **Assemble the criteria table** once every lens is dry or bounded. Each criterion carries the verdict its owning lens returned in its last round, with that lens's citation. This step is assembly, not adjudication. If you disagree with a verdict, re-dispatch that lens with the evidence you are relying on; overwriting it puts your own unreviewed judgement into the table under a reviewer's name.

6. **Present the verdict, the table, and the findings** in the format below. Every finding carries a proposed fix.

7. **Take accept or reject on each finding from the user.** Use `AskUserQuestion` when the list is short enough to fit, otherwise present the numbered list and ask which to apply. Do not apply anything before this gate.

8. **Apply the accepted fixes** to files inside the skill directory. Check the escape hatch first. Record against each edit the finding it closes: that is the intent step 9 hands to the delta reviewer, and recovering it afterwards from a list of accepted findings is guesswork about which edit served which.

9. **Verify with a delta review.** Re-run the mechanical pass over the edited skill and confirm every referenced path still resolves. Then dispatch one delta reviewer, using the delta prompt below. It receives the whole edited skill for context, the refreshed inventory, and every changed passage with the intent behind it, and it judges the edits rather than the file: whether each one did what it set out to do, whether it broke anything adjacent, and whether it contradicts anything else in the skill. A fresh full round would resample text the rounds in step 3 have already exhausted, while the edits are the only part nobody has read yet.

   The delta review runs once. Present what it finds, take accept or reject as at step 7, apply what the user accepts, and report those fixes as applied without reviewing them again. If a criterion the fixes targeted still fails, report it as still failing rather than dispatching its lens again.

   **A delta finding can reverse a criterion that already passed.** An accepted C7 fix that adds a branch can strand a table row, which is a C4 regression against a criterion step 5 recorded as PASS. Where a delta finding contradicts a PASS, flip that criterion to FAIL in the final table with the delta finding as its evidence. Do this whether the user accepts the further fix or rejects it: nothing reviews a fix applied after the delta review, so a flip back to PASS would rest on no reviewer's citation, which is the one thing step 5 forbids. This is a different case from the criteria the fixes targeted, which were already failing and stay that way.

10. **Report the final table**, what was applied, what the user rejected, and anything the escape hatch stopped. Commit nothing.

### When a Dispatch Fails

A lens that returns no usable verdict, reports BLOCKED, or errors has reviewed nothing. Retry it once, one tier up where a higher tier remains, otherwise at the same tier. A retry replaces the dispatch that failed and does not consume one of that lens's three rounds. If the retry also fails, the criteria that lens owns stay at FAIL with "not reviewed, dispatch failed" as their evidence, and the verdict is NOT SOUND. Report the dispatch failure as the reason. A criterion nobody reviewed has not passed.

A delta review that fails the same way is retried once on the same terms. If the retry fails, report the edits as applied but unverified rather than treating step 9 as passed.

## Selecting the Model

Reading a procedure for reachability, ambiguity and economy is design judgement, so lens and delta dispatches start at a high-capability tier; the inherited session model is an acceptable choice at that tier. Resolve the choice to a concrete value at dispatch time, every time: enumerate the values the `Agent` tool's `model` parameter accepts and pick from that enumeration; never construct an identifier from a remembered pattern, because recognising the shape of an identifier is not confirming it exists. If enumeration is impossible, let the dispatch inherit the session model and say so; never fall back silently.

## The Lens Prompt

Paste the block below once per lens, substituting the lens brief from the next section. Every lens receives the same preamble; only the brief changes.

```yaml
Agent (Plan):
  description: "Skill review: <lens name>"
  prompt: |
    You are reviewing one Claude Code skill through a single lens. Six reviewers are reading this skill in parallel, each through a different lens. Yours is the only one below. Stay inside it: another reviewer owns what you are tempted to stray into, and a finding filed under the wrong lens is dropped during reconciliation.

    **The skill under review:**

    [PASTE THE FULL TEXT OF EVERY FILE IN THE SKILL DIRECTORY, EACH UNDER ITS FILENAME. Never pass session history and never pass the author's explanation of what a step is meant to do.]

    **Mechanical inventory (already gathered, treat as fact):**

    [PASTE THE STEP 2 INVENTORY: file list, frontmatter, line counts, which referenced paths resolve and which do not, orphaned files, the names and descriptions of neighbouring skills, and any conventions the target repository's own CLAUDE.md or AGENTS.md states.]

    ## Your Lens

    [PASTE ONE LENS BRIEF FROM "THE SIX LENS BRIEFS" BELOW]

    ## Judge It Against Its Own Repository, Not Yours

    You may be running in a session carrying rules and conventions from the installation you were dispatched from. Those are not binding on the skill you are reading. It belongs to its own repository and follows whatever that repository states.

    Only two things can ground a convention finding: a convention the inventory reports from the target repository's own CLAUDE.md or AGENTS.md, or a property of Claude Code itself, such as frontmatter being required or a directory name being what invokes the skill. A rule you know from elsewhere is not evidence, however sound it is. Faulting this skill for not using RFC 2119 keywords, not citing a rules directory, or not matching a house style it never adopted is the single most common way this review goes wrong.

    ## Reading the Repository

    You receive the skill text and the inventory from the session, and that isolation is about the conversation rather than the code. The repository is shared ground truth, so read it where your lens needs it: to resolve a path, to check a neighbouring skill's description, to confirm a file the skill claims to read exists and says what the skill implies.

    Keep the reading to those checks. A tour of the wider codebase is not what you are for and will cost more than it finds.

    You are read-only. Do not edit, create, or delete any file. Propose fixes in your report; applying them is the orchestrator's job after the user has accepted them.

    ## Calibration

    Flag what changes what the model does when the skill runs. An instruction two competent readers would execute differently, a branch nothing reaches, a sentence whose deletion changes nothing: these are findings. Wording you would have phrased differently, a section shorter than its neighbours, and a structure you would have organised another way are not.

    **The severity floor.** A finding MUST carry a named failing scenario: the concrete input or run state that reaches the problem, and then the wrong outcome that follows from it. "This is vague" is not a finding, and neither is "step 4 gives no threshold for a large change". "Step 4 escalates when the change is large and gives no threshold, so a run against a three-file change escalates and a second run against the same three files does not" is. Anything you cannot ground that way is Advisory: it is still worth reporting, it fails no criterion, and it does not affect the verdict.

    For C7 the scenario a finding must name is what the deletion would cost: state what a competent model would do differently once the sentence is gone. The finding stands only where that answer is nothing at all, and a finding that does not state the answer is Advisory like any other.

    Uncertainty is not a finding either. If you cannot tell whether something is a defect, say so under Advisory rather than promoting it to a FAIL. Padding a report with maybes is worse than a short one.

    ## Verdicts

    Return PASS or FAIL for every criterion your lens owns, and nothing for the criteria it does not.

    A criterion starts at FAIL. PASS is earned by a specific observation you can cite from the text, not by your having found nothing to say about it. If you checked and it holds, say what you checked and what held. If you could not check it, return FAIL and say why, because a criterion nobody verified has not passed.

    ## Output Format

    ## Skill Review: <your lens name>

    **Criterion verdicts**
    - C<n>: PASS | FAIL - <the observation that grounds this verdict>

    **Findings** (one per defect, grouped under the criterion it fails; an entry without a failing scenario belongs under Advisory)
    - C<n> <file>:<line> - <what is wrong>
      Failing scenario: <the input or run state that reaches it, then the wrong outcome>
      Proposed fix: <the specific edit>

    **Advisory** (fails no criterion, does not block)
    - <observation>
```

## The Six Lens Briefs

### Trigger, Owning C1 and C2

You are checking whether the `description` in the frontmatter makes this skill fire on the prompts it should and stay quiet on the prompts it should not. The description is all the model sees before deciding whether to load the skill, so anything about triggering that lives in the body instead is invisible at the moment it is needed.

**C1: the description states both what the skill does and the concrete situations that fire it.** A description naming only the capability leaves the model to infer the trigger. Look for situations stated as things a user would actually say or do, not as abstractions.

**C2: no neighbouring skill wins the prompts it claims, and it claims none of theirs.** Work from the neighbour descriptions in the inventory. Ask, for each overlap, which skill should win and whether the descriptions as written would produce that. Overlap is not automatically a defect: a skill that hands off to another will name it, and that is correct. The defect is two descriptions competing for one prompt with nothing to separate them, or a description claiming territory another skill actually owns.

### Ambiguity, Owning C3

You are checking whether every instruction can be executed without a judgement the skill supplies no criterion for. The test is two competent readers: where they would do different things and both be following the text, that is a finding.

Look for: terms used as though defined that the skill never defines; thresholds stated in words with no number or rule behind them ("large", "complex", "significant", "when appropriate"); steps with no stated actor; conditionals whose condition cannot be evaluated from anything the skill provides; pronouns and references whose antecedent is genuinely unclear; and instructions that depend on knowing something only the author knows.

A word like "significant" is not automatically a finding. It is a finding when the skill branches on it. Ask what the model does differently depending on the answer, and if nothing does, leave it.

### Reachability, Owning C4 and C5

You are checking the skill as a piece of control flow. Trace every path from entry to exit.

**C4: every branch, table row, mode and return arm has an input that reaches it.** Look for: table rows describing a case no earlier step can produce; return statuses nothing generates; modes offered but never selected; steps a jump refers to that no step performs; conditions that earlier steps have already excluded; and preconditions whose failure arm is documented but which an earlier gate has already made impossible.

**C5: every path ends in a hand-off, a return, a halt or an escalation.** Look for paths that simply run out: a branch with no instruction on what happens next, a failure case detected with no stated response, a loop with no bound, a step whose "otherwise" is never written. Report the specific input that reaches the dead end.

Give the reaching input for a C4 finding and the terminating gap for a C5 one. "Row three looks unreachable" is not usable; "no step returns Not Consolidated, so the row handling it never fires" is.

### Redundancy, Owning C6

You are checking whether content sits in one place. Three things look alike and only one is a defect.

**Duplication is the defect:** the same content in two places, whether or not notes link the copies. It drifts, and then two files disagree.

**A fill-at-dispatch placeholder is legitimate:** the mechanism for giving a dispatched agent content from another file or section is a placeholder in the prompt template naming the canonical source to paste from at dispatch time. Check that the placeholder names a real source and that no second copy is kept alongside it.

**Shared structure is not duplication:** two sections with the same heading layout or table skeleton carrying different content need no reconciling.

Check the skill against the files it references (read them) and against itself. Self-repetition counts: the same constraint restated in the procedure, the red flags and the mistakes table is one constraint in three places, and it is a finding unless each restatement does different work.

### Prose Economy, Owning C7

You are checking whether every sentence changes what the model does. The test is deletion: remove the sentence, and would a competent model behave differently?

This is not a request to make the skill short. Rationale is often load-bearing. A sentence explaining why a constraint exists lets the model apply it to a case the skill never enumerated, and deleting it narrows the skill to its examples. Keep that. What to find instead:

- Restatement: a point already made, made again in different words
- Throat-clearing: sentences announcing what the next section will cover
- Motivation repeated after it has already landed
- Examples that demonstrate nothing the earlier example did not
- Hedging and softening that leaves the instruction unchanged
- Emphasis added to a rule already stated as a rule

For every finding, name what would be lost by the deletion and why nothing is. Deleting a constraint because it reads as filler is the failure mode of this lens, and it is worse than leaving prose in place. If you are unsure whether a sentence carries a constraint, it does; put it under Advisory.

### Load Model, Owning C8

You are checking that the skill loads the right files at the right time and nothing it does not need.

**Paths resolve.** Take the resolution results from the inventory. Any path that does not resolve is a FAIL with the path named. Check the inventory's findings yourself where a path looks ambiguous rather than trusting the extraction blindly.

**Loaded files are used.** Every file the skill instructs a read of should be depended on by a later step. A file read and never used costs context for nothing.

**Loaded before needed.** A file whose contents a step depends on must be read before that step, not after it and not conditionally on a branch that step can be reached without.

**Non-resident content is deferred.** A skill body loads in full whenever the skill triggers, so content needed only sometimes belongs in a bundled file the skill reads on demand. Look for long reference material inline that a pointer would serve, and for the reverse: a bundled file holding something every run needs, which pays two loads for one.

**Orphans.** Files in the directory nothing references, from the inventory. Either something should read them or they should not ship.

The inventory reports line counts. Treat size as a prompt to look, not as a finding: a long skill whose every section is reached on every run is fine, and a short one that defers what it always needs is not.

## The Delta Prompt

Dispatched once, at step 9, and its subject is the fixes that were just applied rather than the skill. It returns per-edit verdicts and no criterion verdicts, because the criteria table is already assembled by the time it runs. Resolve the model as for a lens: judging edits against a whole skill is design judgement, so it starts at a high-capability tier on the same terms.

```yaml
Agent (Plan):
  description: "Skill review: delta"
  prompt: |
    You are reviewing a set of edits to a Claude Code skill. The skill itself has already been reviewed lens by lens; the edits below were applied afterwards and are the only text nobody has read yet. Read the whole skill so you can judge the edits in place, then judge only the edits.

    **The skill as it now stands:**

    [PASTE THE FULL TEXT OF EVERY FILE IN THE SKILL DIRECTORY AS EDITED, EACH UNDER ITS FILENAME.]

    **The edits:**

    [FOR EACH EDIT: THE FILE AND LOCATION, THE TEXT BEFORE, THE TEXT AFTER, AND THE ONE-LINE INTENT IT WAS APPLIED TO SERVE. Never pass session history, and never pass the author's explanation of anything the edits did not change.]

    **Mechanical inventory (re-gathered after the edits, treat as fact):**

    [PASTE THE REFRESHED INVENTORY FROM STEP 9: file list, frontmatter, line counts, which referenced paths resolve and which do not, orphaned files, and any conventions the target repository's own CLAUDE.md or AGENTS.md states.]

    ## What to Check

    Answer three questions about each edit, in this order.

    1. **Did it do what it set out to do?** The intent is stated with the edit. An edit that misses its intent leaves the original defect in place in new wording, which is worse than leaving it alone, because the report records the fix as applied.
    2. **Did it break something adjacent?** An added branch changes what reaches the steps around it, an added term changes what earlier uses of that term mean, and a renumbered step orphans every reference to the old number.
    3. **Does it contradict anything?** Compare each edit against the rest of the skill and against the files it references. Two instructions that cannot both be followed are what this question exists to catch.

    Report nothing about a passage no edit touched: those were reviewed before the edits were applied, and raising them again restarts a loop that has already terminated. A passage an edit did not touch but did change the meaning of is in scope, under question 2.

    ## Judge It Against Its Own Repository, Not Yours

    [PASTE THAT SECTION FROM THE LENS PROMPT ABOVE, UNCHANGED.]

    ## Reading the Repository

    [PASTE THAT SECTION FROM THE LENS PROMPT ABOVE, UNCHANGED.]

    ## Calibration

    [PASTE THAT SECTION FROM THE LENS PROMPT ABOVE, UNCHANGED. The severity floor binds a delta finding exactly as it binds a lens finding; where that section says FAIL, read it as "finding", since you return no criterion verdicts.]

    ## Output Format

    ## Delta Review

    **Per edit**
    - Edit <n>: ACHIEVED | NOT ACHIEVED - <what you checked, and what holds or does not>

    **Findings** (one per defect the edits introduced or left behind)
    - <file>:<line> - <what is wrong> (question 1 | 2 | 3)
      Failing scenario: <the input or run state that reaches it, then the wrong outcome>
      Proposed fix: <the specific edit>

    **Advisory** (fails no criterion, does not block)
    - <observation>
```

## Reporting Format

```text
SKILL REVIEW: <skill-name>
VERDICT: SOUND | NOT SOUND (<n> of 8 criteria failed)
ROUNDS:  <lens>=<n> dry, <lens>=3 bound reached, ...
DELTA:   <n> edits reviewed, <n> findings, criteria flipped: <list | none>  (step 10 only)

| #  | Criterion       | Verdict | Evidence                          |
|----|-----------------|---------|-----------------------------------|
| C1 | ...             | PASS    | <cited observation>               |

FINDINGS
C4  <file>:<line>  <what is wrong>
    Failing scenario: <the scenario the lens gave, carried through unchanged>
    Proposed fix:     <the specific edit>

ADVISORY (fails no criterion, does not block)
    <observation>
```

Findings are grouped under the criterion they fail, in criterion order. Advisory observations are reported separately and never block the verdict, because a criterion is the only thing that can. The ROUNDS line carries one entry per lens, so a lens that stopped at the bound rather than at dryness is visible in the verdict rather than buried in the findings. The DELTA line does the same for step 9, and a criterion the delta review flipped carries that finding as its evidence in the table above it.

## Completion Gate

You **MUST NOT** report a verdict unless all of these are true:

- Every lens either returned a dry round or reached the three-round bound, or a failed dispatch is recorded against the criteria it owns.
- Every criterion carries a verdict and a citation, from its owning lens or, where step 9 flipped it, from the delta review.
- No criterion is marked PASS because no reviewer mentioned it.
- No finding fails a criterion without clearing the severity floor.
- Every accepted fix is applied, the mechanical pass has been re-run against the edited files, and the delta review has run against the edits.
- Every rejected finding is reported as rejected rather than dropped.

If any one is false, the gate has not been crossed.

## Red Flags

Every thought below means stop:

- "The description looks fine to me." You have read the skill. That is the condition under which its ambiguity becomes invisible, and it is why the lenses get fresh context.
- "This sentence reads nicely, keep it." C7 asks whether deleting it changes behaviour, not whether it is well written.
- "The reviewer missed the point, I will correct its verdict." Step 5 is assembly. Re-dispatch with your evidence instead.
- "That lens has reported, one reading is enough." One dispatch samples a lens's findings; it does not exhaust them. Step 3 stops on a dry round, not on a round.
- "This is clearly a defect, I just cannot say what goes wrong." Then it does not clear the floor, so it is Advisory. Your confidence is not the bar.
- "Only one criterion failed, that is basically SOUND." SOUND is all eight.
- You are rewriting the skill rather than applying the fixes the user accepted. Step 8 has a boundary and the escape hatch is how you leave it.

## Common Mistakes

| Mistake                                                         | Why it is wrong                                                                                                                                                                                |
|-----------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Passing session history or the author's explanation to a lens   | Violates context isolation, and a skill that needs its author present to make sense is the C3 finding you have just suppressed.                                                                |
| Reviewing a skill you wrote this session without dispatching    | You cannot audit prose for ambiguity while holding the intent that resolves it. The dispatch is the whole mechanism.                                                                           |
| Marking a criterion PASS because nobody raised it               | PASS is earned by a citation. Silence is a lens that found nothing to say, or a lens that did not look.                                                                                        |
| Deleting prose that carries a constraint                        | The C7 failure mode. "Shorter" is not the goal; "every sentence load-bearing" is, and a deleted constraint changes behaviour by definition.                                                    |
| Editing a sibling skill so the target passes C2                 | Out of bounds. That skill has its own callers and its own review. Report the overlap instead.                                                                                                  |
| Renaming the skill directory                                    | The directory name is how the skill is invoked. A rename breaks every caller that names it.                                                                                                    |
| Faulting the target against your own installation's conventions | The target adopted its repository's conventions, not yours. Only what its `CLAUDE.md` or `AGENTS.md` actually states counts.                                                                   |
| Applying fixes before step 7                                    | The user's per-finding approval is what makes this skill's editing legitimate. Without it there is no approval.                                                                                |
| Dispatching the lenses of one round across separate messages    | That is sequential, whatever it was called. Parallelism comes from the message.                                                                                                                |
| Telling a re-dispatched lens what an earlier round found        | It anchors the lens to that list, so the round returns confirmations instead of the fresh sample you re-dispatched for.                                                                        |
| Running a fresh full round at step 9                            | Step 3's rounds already exhausted the unchanged text. The edits are the only text nobody has read, and they are what step 9 reviews.                                                           |
| Re-dispatching a lens because you dislike its verdict           | Re-dispatch on evidence, not on disagreement. Step 3's rounds re-run an identical prompt against unchanged text; correcting a verdict is a different act and carries the evidence you rely on. |
