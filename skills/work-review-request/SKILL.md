---
name: work-review-request
description: "Dispatches a code reviewer subagent against the work under review, applies severity discipline to its verdict, and owns the fix loop until no Critical or Important issue remains, sending only complex fixes back to the reviewer. Use this whenever a change is about to be committed to main, opened as a pull request, handed back as complete, or declared done, and whenever the user asks for a branch, a diff, or their changes to be looked over before shipping. Invoked by `work-swarm` for the feature-level review and by `debug-investigation` after a fix. No change is exempt for being small, simple, obvious, or locally tested."
---

# Requesting Code Review

Dispatches a reviewer against a concrete diff, drives the fixes its findings require, and returns an approved change or an escalation.

## Establishing the Review Range

The reviewer sees exactly the diff you point it at, and it cannot tell a diff that is empty or wrong from one that is right. A reviewer handed the wrong range reads code nobody asked about, finds nothing wrong with it, and returns a clean verdict that is indistinguishable from a real one. This is the highest-value step in the skill and the easiest to get wrong, because the obvious default is wrong most of the time.

### Find the Base

Take the first row that applies.

| Situation                                   | Base                                                                                                          |
|---------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| Orchestrated work                           | The `baseSha` the orchestrator recorded at launch, which is the commit the whole feature is measured against. |
| Branch work with an upstream                | `git merge-base HEAD <default-branch>`                                                                        |
| Neither, and the boundary is not observable | Ask the user which commit the work starts from, and return **Range unknown** until they answer.               |

Never fall back to `HEAD~1`. It is right only when the work is exactly one commit, it errors on a repository's first commit, and the rest of the time it is silently wrong: on a five-task feature it reviews task five and reports on the feature.

### Include the Working Tree

Work reaching this skill is frequently uncommitted. A bug fix arrives here before its completion gate has permitted a commit, and orchestrated work under "Ask me each time" may be draining tasks the user has not yet approved. A `BASE..HEAD` range excludes the working tree, so in both cases the reviewer would receive the previous commit and none of the work under review.

Diffing against the base alone rather than across a range solves this without a branch. `git diff <base>` compares the base to the working tree, so it covers committed and uncommitted changes together, and it is identical to `BASE..HEAD` when the tree is clean. Untracked files are the one thing it cannot show, which is what `git status --porcelain` is for.

```bash
git status --porcelain
git diff --stat "$BASE_SHA"
```

If the diff is empty and no untracked files are listed, there is nothing to review. Return **Nothing to review** rather than dispatching, because a reviewer given an empty diff returns an approval, and nothing downstream can tell that approval apart from one earned by real code.

## Selecting the Reviewer Model

Resolve the model at dispatch time, every time:

1. Enumerate the models the current environment actually exposes by reading the values the `Agent` tool's `model` parameter accepts. Never construct an identifier from a remembered pattern: recognising the shape of an identifier is not confirming it exists. If enumeration is impossible, let the dispatch inherit the session model and say so; never fall back silently.
2. Start at the tier whose task signal matches the change under review, and map it to a concrete value from that enumeration: a change confined to a few files with clear acceptance criteria reviews at a low-cost model, and a change whose correctness depends on how several files interact starts at a mid-tier one.
3. Never review below the tier that produced the work. The review is the last gate before the work is accepted, so a reviewer that misses a real defect is the most expensive failure this skill can produce, and no per-call saving covers it.
4. Escalate one tier at a time and only on evidence, such as a previous dispatch whose findings show it did not follow the change across file boundaries. A long diff is not by itself a signal; line count measures size, not judgement.

## Procedure

1. **Establish the range** per the section above. A precondition failure returns **Nothing to review** or **Range unknown** and spends no budget.

2. **Resolve the model** per "Selecting the Reviewer Model" above.

3. **Fill the prompt template** below and dispatch with `Agent`. The placeholder table names every placeholder; fill every one, and leave none unreplaced. Pass no session history: the reviewer reads the repository and the diff, and anything it needs from the conversation belongs in the template you fill.

4. **Read the status.**
   - **Approved** with no issues listed: go to step 7.
   - **Approved** with Minor issues listed, or **Issues Found**: go to step 5.
   - **Neither, or the dispatch failed**: see "When the Dispatch Fails" below.

5. **Process the findings through `work-review-receive`.** That skill verifies each item, pushes back where the reviewer is wrong, and implements what survives in severity order. Pushback is a legitimate outcome: an item the reviewer got wrong is closed by the reasoning, not by a change to the code.

   Minor issues go through that skill with the rest. Minor is a tier, not a verdict: each Minor item is fixed where the fix makes sense, or pushed back with a stated reason. An accepted Minor fix goes through the same classification in step 6 as every other fix. A simple Minor fix made after an Approved needs no dispatch, and the return lists it. A complex Minor fix made after an Approved needs a dispatch. Where no dispatch remains to cover it, the item is declined with that as its reason and the Approved stands.

   Only its **Applied** return continues this loop. **Clarification required** and **Escalated** both need a person, so carry them to the user and stop; re-dispatching a reviewer cannot supply what it never had. **Pushback pending** needs an answer from whoever produced the feedback before the batch closes.

6. **Decide which fixes go back to the reviewer.** Classify every fix from step 5 per "Deciding Which Fixes Go Back" below.
   - If step 5 changed no code, there is nothing new to review: go to step 7.
   - If every fix is simple, run the project's proving command fresh per `work-verification`. When it passes, go to step 7. No reviewer needs to read a fix that is mechanical, local and confidently correct.
   - If any fix is complex, run the proving command fresh, then re-dispatch against the updated range with the complex fixes named in the prompt, and return to step 4. The simple fixes in that round are covered by the proving command.

   At most three dispatches in this invocation. When the third returns anything other than Approved, stop and return **Issues outstanding**.

7. **Return** per the Return Contract.

The loop lives here rather than in the callers on purpose. A caller that reviews, fixes, and then decides for itself whether to re-review applies no shared criteria. It ends up either skipping a re-review that a complex fix needed, or running this whole cycle a second time around the outside. Neither is what the caller wanted, and both are invisible from inside the caller.

### Deciding Which Fixes Go Back

A fix is **simple** when all of these hold:

- It is mechanical and local. Examples are a rename, a named constant, a missing test, a removal, or a wording change.
- It adds no logic or behaviour beyond what the finding names.
- It leaves error handling, concurrency, security paths and public interfaces as they were.
- You are confident that it resolves the finding, and you can say why from the code.

A fix that fails any one of these is **complex**. If you are unsure, the fix is complex.

The proving command is the check on your confidence. A fix that fails it is not simple, whatever it looks like.

### Why Only Complex Fixes Go Back

A fresh review of the whole change tends to find something new each time. A loop that re-reviews every fix therefore rarely ends, and each round costs a dispatch and a round of fixes.

The risk that a re-review covers is code that was written under pressure to close a finding and that adds new behaviour, which is where a fix for one issue introduces another. A complex fix carries that risk. A simple fix does not, because it adds nothing new for a reviewer to find.

An Approved verdict from before a complex fix describes code that no longer exists. An Approved verdict from before a simple fix still describes the code that matters, and the return lists the simple fix so the caller can see it.

The re-dispatch is scoped to the complex fixes. The reviewer judges those fixes and does not re-open code that an earlier round cleared.

### When the Dispatch Fails

A dispatch that returns no usable status, reports BLOCKED, or errors has reviewed nothing, so it spends no budget. Retry it once, one tier up where a higher tier remains, otherwise at the same tier. If the retry also fails, return **Issues outstanding** with the dispatch failure as the outstanding item, so the decision reaches a human rather than a third attempt.

## The Reviewer Prompt

Fill every placeholder; leave none unreplaced in the dispatched prompt.

| Placeholder              | What goes in it                                                                                                                                                                                                                                     |
|--------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `[WHAT_WAS_IMPLEMENTED]` | One line naming what the change builds.                                                                                                                                                                                                             |
| `[DESCRIPTION]`          | A short paragraph: what it builds, and the design decisions that matter for review.                                                                                                                                                                 |
| `[PLAN_REFERENCE]`       | The approved design, ticket, or plan the work delivers against. Paste the acceptance criteria, do not link.                                                                                                                                         |
| `[BASE_SHA]`             | The base commit established per "Establishing the Review Range" above.                                                                                                                                                                              |
| `[REVIEW_TARGET]`        | `the working tree, which contains uncommitted changes` or `commit <sha>`.                                                                                                                                                                           |
| `[UNTRACKED_FILES]`      | Paths from `git status --porcelain` that the diff cannot show, or `none`.                                                                                                                                                                           |
| `[PREVIOUS_ROUND]`       | On a re-dispatch: your previous findings and what changed in response. Omit the section on the first review.                                                                                                                                        |
| `[FIXES_TO_REVIEW]`      | On a re-dispatch: each complex fix with its file:line and the finding it answers. Omit the whole section, heading and paragraph included, on the first review.                                                                                      |
| `[SEVERITY_TABLE]`       | The severity table from the always-on code review rules, pasted whole. That table is the canonical copy and this template deliberately does not restate it, so an edit there reaches every dispatched reviewer with no second copy to keep in sync. |

```yaml
Agent (general-purpose):
  description: "Code review: [WHAT_WAS_IMPLEMENTED]"
  prompt: |
    You are reviewing a change for production readiness.

    ## What Was Built

    [DESCRIPTION]

    ## What Was Asked For

    [PLAN_REFERENCE]

    ## Previous Review Round

    [PREVIOUS_ROUND]

    ## Fixes To Review

    [FIXES_TO_REVIEW]

    On a re-review, judge only the fixes listed above. The rest of the change was reviewed in an earlier round and cleared, and simple fixes that were not listed have been checked by other means. Do not raise findings on code outside the listed fixes unless a listed fix interacts with it and breaks it. Check that each listed fix resolves the finding it answers and does not introduce a new problem.

    ## The Change

    Base commit: [BASE_SHA]
    Reviewing: [REVIEW_TARGET]
    Untracked files not shown by the diff: [UNTRACKED_FILES]

    ```bash
    git diff --stat [BASE_SHA]
    git diff [BASE_SHA]
    ```

    Diffing against the base rather than across a commit range is deliberate: it includes uncommitted work, which is often where the change under review lives. Any untracked file listed above is part of this change and will not appear in the diff at all. Read those files directly.

    ## Do Not Trust This Description

    The summary above is what someone believes they built. It may be incomplete, inaccurate, or optimistic. Verify everything against the code: read what was actually written, compare it to the acceptance criteria line by line, look for requirements silently skipped and for work nobody asked for.

    ## What You May and May Not Do

    Read whatever you need to judge the change: the diff, the files it touches, their callers, the tests that cover them, and the conventions of the surrounding code. Understanding a change means reading beyond it.

    You may not change anything. Do not edit files, do not stage or commit, and do not run the test suite or the build. Whether the suite passes is the orchestrator's verification gate, not yours, and running it from here mutates state the orchestrator is about to measure. Judge the tests by reading them.

    ## What To Check

    Scale this to the change in front of you. A one-line bug fix does not have a migration strategy, and asking after one produces noise that costs the orchestrator real work to dismiss. Skip whole sections that do not apply and say nothing about them.

    | Area              | What to look for                                                                                                               |
    |-------------------|--------------------------------------------------------------------------------------------------------------------------------|
    | Correctness       | Bugs, unhandled edge cases, errors caught and swallowed, race conditions, off-by-one boundaries                                |
    | Spec compliance   | Requirements unmet, requirements misread, work delivered that nobody asked for                                                 |
    | Tests             | New behaviour covered, tests driving real code rather than mocks of it, a test that would actually fail if the behaviour broke |
    | Design            | Responsibilities separated, complexity the problem does not require, duplication worth naming                                  |
    | Consistency       | Naming, structure, and idiom matching the surrounding code rather than a different house style                                 |
    | Security and data | Untrusted input reaching a boundary unvalidated, secrets in the diff, destructive or lossy paths                               |
    | Compatibility     | Breaking changes to a published interface, schema changes without a migration, where these apply                               |

    ## Calibration

    Only report what would cause a real problem. A swallowed error, an unmet requirement, and new behaviour with no test are issues. Wording preferences, a structure you would have chosen differently, and optimisations with no measurement behind them are not.

    Severity is a commitment, not a description of how strongly you feel. Critical and Important both block: the orchestrator must fix them before the work advances at all. Assign them using these tests:

    [SEVERITY_TABLE]

    Inflation is the failure mode to guard against, because it looks conscientious while it stalls the work. If an issue would leave you comfortable shipping, it is Minor. Approve changes that are sound but imperfect: perfect is not the bar, and a review that never approves anything stops being read.

    Anything you want to suggest that is not an issue goes under Recommendations, which are advisory and do not block.

    ## Output Format

    ## Code Review

    **Status:** Approved | Issues Found

    Approved means no Critical and no Important issues. Minor issues are compatible with Approved; list them and still approve.

    **Strengths:**
    - [what is genuinely well done, specifically, with file:line]

    **Issues:**

    ### Critical
    ### Important
    ### Minor

    For each issue, under its severity heading:
    - **[one-line summary]**
      - Where: file:line
      - What: what is wrong
      - Why it matters: the consequence, concretely
      - Fix: how to resolve it, where that is not obvious

    Omit any severity heading that has no issues under it.

    **Recommendations (advisory, do not block approval):**
    - [suggestions the orchestrator may take or leave]
```

This skill is the template's only call site: per-task reviews inside orchestrated work are dispatched by that skill's own workflow script and do not use it.

## Return Contract

This section is addressed to whichever skill or user invoked this one. It lives here because invoking this skill is what loads the file, so the caller has the text at the moment it needs it.

**Approved.** The most recent dispatch found no Critical or Important issues. The caller receives the range reviewed, every simple fix that was not re-reviewed with the reason it was judged simple, every Minor issue that was declined with its reason, and the reviewer's recommendations. The caller continues. Accepted Minor fixes are either inside the reviewed range or listed as simple fixes. Recommendations travel unapplied by design: acting on them here would expand a change the review had already cleared.

**Issues outstanding.** The three-dispatch budget is spent with Critical or Important issues remaining, or the reviewer could not be dispatched. The caller receives those issues and **MUST NOT** invoke this skill again in the hope of a better verdict. The budget exists so that a change which will not converge reaches a human rather than a fourth reviewer. The caller stops and puts it to the user.

**Nothing to review.** The range is empty. Nothing was reviewed and no budget was spent. This is a precondition failure, not an approval, and the caller **MUST NOT** treat it as one: the mandatory review has not happened. The caller establishes where the work actually is and invokes this skill again.

**Range unknown.** The base could not be established and the user has not supplied one. Nothing was reviewed. The caller obtains the base and invokes this skill again.

**Invoking again after the code changes.** Approved covers the diff that was reviewed, plus the simple fixes the return lists. If the code then changes in any other way, the Approved no longer describes what the caller is holding, and the caller invokes this skill again against the new range with a full budget. That is a first review of code no reviewer has seen, not budget evasion. The distinction that matters is what prompted the new invocation: new code, or an unwelcome verdict on unchanged code.

## Worked Example

Task 2 of an orchestrated flow is complete: verification and repair functions for a conversation index. The user chose "Ask me each time" for commits and has not been asked yet, so the work is in the tree and uncommitted.

```bash
BASE_SHA=a7981ec          # base_sha recorded on the task board for Task 2
git status --porcelain    # M src/index.ts, ?? src/repair.ts
git diff --stat "$BASE_SHA"
```

The diff is non-empty and `repair.ts` is untracked, so the reviewer is told to read it directly rather than expect it in the diff. Dispatch the reviewer at a low-cost tier resolved per "Selecting the Reviewer Model".

**Dispatch 1** returns Issues Found:

- Strengths: clean separation, real tests, no mocks of code under test
- Important: `repairIndex()` swallows a write failure and reports success (`repair.ts:64`)
- Minor: magic number (100) for the reporting interval; no progress indicator on long runs
- Status: Issues Found

`work-review-receive` verifies the Important item, confirms the swallowed failure is real, and fixes it. It assesses the two Minor items in the same round. The magic number is accepted: the interval is read in two places, so a named constant is fixed alongside the Important item. The progress indicator is pushed back: Task 2 did not ask for one, so it is a feature request on a change that did not include it.

Classify the fixes. The named constant is simple: it is mechanical, local and adds no behaviour. The fix to `repairIndex()` is complex: it changes error handling.

Run the proving command fresh. It passes, so the named constant is checked.

**Dispatch 2** names only the `repairIndex()` fix. It reads that fix and returns Approved with a recommendation about logging the repair count. Return **Approved**, carrying the named constant as a simple fix not re-reviewed, the declined Minor item with its reason, and the recommendation. Task 3 may begin.

Note what each item did. The constant was fixed and listed, and cost no dispatch. The progress indicator was declined with a reason that travels in the return. Neither blocked. Note also that the second dispatch was necessary. The fix to `repairIndex()` was new, unreviewed code touching an error path, which is where a fix for one issue most often introduces another. Had the only finding been the named constant, the loop would have ended after the first dispatch.

## Completion Gate

You **MUST NOT** return Approved unless all of these are true:

- The most recent dispatch **in this invocation** returned Approved. A previous Approved from earlier in the session, or your own reading of the fixes, does not count.
- That dispatch reviewed a range that included every complex fix made during this invocation.
- Every simple fix that was not re-reviewed is listed in the return with the reason it was judged simple, and the proving command passed fresh after the last of them.
- Every Critical and Important issue raised across every dispatch is either fixed in the code you are returning, or was pushed back through `work-review-receive` with technical reasoning the reviewer did not contest.
- Every Minor issue raised across every dispatch is either fixed (inside the reviewed range, or listed as a simple fix) or enumerated in the return with the reason it was declined.
- The reviewer's recommendations travel with the return.

If any one is false, one of the other three return states is the honest one.

## Red Flags

Every thought below means stop:

- "The diff came back empty, so the change must be clean." An empty diff means you are pointing at the wrong place. Nothing was reviewed.
- "The fix was small, so I will call it simple." Size is not the test. A three-line change to an error path is complex. Apply the criteria in "Deciding Which Fixes Go Back".
- "I will re-dispatch to be safe." A re-dispatch for a simple fix is the loop this skill exists to end. The criteria decide, not caution.
- "This is close enough to Approved." The verdict comes from a dispatch, not from you.
- "One more dispatch and it will converge." The budget is the answer to that thought, not an obstacle to it.
- "The dispatch said Approved, so I will quietly fix this Minor one and ship." A fix applied after Approved is code no reviewer has read. Re-dispatch if the fix is complex. If it is simple, list it in the return. Never apply it silently.
- "It is only Minor, so it travels deferred." Minor is a tier, not a verdict. Each Minor item is fixed where the fix makes sense or declined with a stated reason.
- You are reading the diff and forming your own verdict rather than dispatching. That is the orchestrator reviewing its own work, which is what the second pair of eyes exists to prevent.

## Common Mistakes

| Mistake                                                       | Why it is wrong                                                                                                                                                 |
|---------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Defaulting the base to `HEAD~1`                               | Right only for single-commit work. On a multi-task feature it reviews the last task and reports on the whole thing.                                             |
| Reviewing `BASE..HEAD` when the tree is dirty                 | Excludes the working tree, so the reviewer reads the previous commit and none of the work. A bug fix reaches this skill in exactly that state.                  |
| Forgetting untracked files                                    | A new file that was never added shows in `git status` but not in `git diff`. The reviewer will report on a change with its main file missing.                   |
| Treating **Nothing to review** as an approval                 | The mandatory review has not happened. The empty range is a bug in the range, not evidence about the code.                                                      |
| Returning Approved on the verdict that preceded a complex fix | That verdict described code that no longer exists.                                                                                                              |
| Re-dispatching after a simple fix                             | It restarts a loop that the criteria say is finished, and a fresh full review tends to find something new.                                                      |
| Skipping the re-dispatch without a fresh proving command      | The proving command is the check on your confidence. A simple fix is only simple if it passes.                                                                  |
| Re-dispatching without naming the complex fixes               | The reviewer re-reads the whole change and re-opens findings that were already cleared.                                                                         |
| Letting the caller decide whether to re-review                | The loop belongs to this skill. Callers that own it either skip it or run it twice.                                                                             |
| Passing session history to the reviewer                       | Violates context isolation. Anything the reviewer needs from the conversation goes in the template.                                                             |
| Fixing the reviewer's findings yourself in this context       | Patching a subagent's output in the orchestrator context destroys the isolation that makes the evidence trustworthy. Findings go through `work-review-receive`. |
| Accepting every finding because a reviewer produced it        | Pushback is mandatory where the reviewer is wrong. An unverified fix to a non-issue is a change nobody asked for.                                               |
| Counting a failed dispatch against the budget                 | A dispatch that errored reviewed nothing. Retry once, a tier up where one remains; spending budget on it burns a review the change never got.                   |
| Pre-escalating to a high tier because the change feels big    | Size is not the signal. Escalate one tier at a time, on evidence a lower tier missed something.                                                                 |
