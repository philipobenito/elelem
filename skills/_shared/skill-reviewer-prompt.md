# Skill Reviewer Prompt Template

Use this template when dispatching the six reviewer lenses from `../skill-review/SKILL.md`, and its delta-review variant at the end of this file when dispatching that skill's step 9.

**Purpose:** Return a PASS or FAIL with a citation for each criterion one lens owns, plus the findings behind any FAIL. The delta-review variant judges a set of applied edits instead, and returns no criterion verdicts.

**Dispatch after:** The mechanical pass in step 2 has produced the inventory. Every dispatch belonging to one round goes out in a single message, and step 3 re-dispatches a lens against unchanged text until the lens goes dry or reaches its third round.

## Selecting the Model

Resolve the model per `subagent-dispatch.md`. Start at the Low-cost default tier. Reading a procedure for reachability and ambiguity is design judgement, which that file's tier table maps to High-capability, so escalation as far as that tier is available for these dispatches, one tier at a time and only on evidence. Do not pre-escalate because a skill looks long.

## The Prompt

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

    [PASTE ONE LENS BRIEF FROM THE SECTION BELOW]

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

**A fill-at-dispatch placeholder is legitimate:** the mechanism for giving a dispatched agent content from another file is a placeholder in the prompt template naming the canonical file to paste from at dispatch time. Check that the placeholder names a real file and that no second copy is kept alongside it.

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

## The Delta Review Prompt

Dispatched once, at step 9 of `../skill-review/SKILL.md`, and its subject is the fixes that were just applied rather than the skill. It returns per-edit verdicts and no criterion verdicts, because the criteria table is already assembled by the time it runs.

Resolve the model as for a lens. Judging edits against a whole skill is design judgement, so it starts at High-capability on the same terms.

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
