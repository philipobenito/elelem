---
name: requesting-code-review
description: "Dispatches a code reviewer subagent against the work under review, applies severity discipline to its verdict, and owns the fix-and-re-review loop until no Critical or Important issue remains. Use this whenever a change is about to be committed to main, opened as a pull request, handed back as complete, or declared done, and whenever the user asks for a branch, a diff, or their changes to be looked over before shipping. Invoked by `orchestrated-implementation` for the feature-level review and by `debugging` after a fix. No change is exempt for being small, simple, obvious, or locally tested."
---

# Requesting Code Review

Dispatches a reviewer against a concrete diff, drives the fixes its findings require, and returns an approved change or an escalation.

The iron-law rules (when reviews are mandatory, forbidden response phrases) live in `../../rules/common/code-review.md`. The procedural rules that bind once a review skill is running (verify before acting, severity discipline and how to assign tiers, when to push back, the GitHub inline reply procedure) live in `../_shared/code-review.md`. The iron laws on subagent dispatch (context isolation, the git ban, the worktree ban, the privilege ban, and the ban on writing an identifier you have not confirmed the environment exposes) live in `../../rules/common/subagents.md`.

Before running the procedure below, read `../_shared/code-review.md` and `../_shared/subagent-dispatch.md` with the Read tool if you have not already read them this session. The second holds the type selection and model resolution procedures this skill depends on, and a dispatch made without them in context is a guess.

## Establishing the Review Range

The reviewer sees exactly the diff you point it at, and it cannot tell a diff that is empty or wrong from one that is right. A reviewer handed the wrong range reads code nobody asked about, finds nothing wrong with it, and returns a clean verdict that is indistinguishable from a real one. This is the highest-value step in the skill and the easiest to get wrong, because the obvious default is wrong most of the time.

### Find the Base

Take the first row that applies.

| Situation                                   | Base                                                                                                                                       |
|---------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| Orchestrated work with a task board         | The `base_sha` recorded per `../_shared/task-board.md`: the task's own for a per-task review, the first task's for a feature-level review. |
| Branch work with an upstream                | `git merge-base HEAD <default-branch>`                                                                                                     |
| Neither, and the boundary is not observable | Ask the user which commit the work starts from, and return **Range unknown** until they answer.                                            |

Never fall back to `HEAD~1`. It is right only when the work is exactly one commit, it errors on a repository's first commit, and the rest of the time it is silently wrong: on a five-task feature it reviews task five and reports on the feature.

### Include the Working Tree

Work reaching this skill is frequently uncommitted. `debugging` reviews at Phase 7 step 3 and commits only after its Completion Gate. `orchestrated-implementation` offers "Ask me each time" as a commit preference, and a user may decline. A `BASE..HEAD` range excludes the working tree, so in both cases the reviewer would receive the previous commit and none of the work under review.

Diffing against the base alone rather than across a range solves this without a branch. `git diff <base>` compares the base to the working tree, so it covers committed and uncommitted changes together, and it is identical to `BASE..HEAD` when the tree is clean. Untracked files are the one thing it cannot show, which is what `git status --porcelain` is for.

```bash
git status --porcelain
git diff --stat "$BASE_SHA"
```

If the diff is empty and no untracked files are listed, there is nothing to review. Return **Nothing to review** rather than dispatching, because a reviewer given an empty diff returns an approval, and nothing downstream can tell that approval apart from one earned by real code.

## Procedure

1. **Establish the range** per the section above. A precondition failure returns **Nothing to review** or **Range unknown** and spends no budget.

2. **Resolve the model** per `../_shared/subagent-dispatch.md`, at dispatch time and every time. Start at the Low-cost default tier; a single-file change with a clear spec belongs there. Escalate one tier at a time and only on evidence: a change spanning several files whose correctness depends on how they interact, or a reviewer whose findings show it did not follow the change across files.

3. **Fill the template** in `../_shared/code-reviewer-prompt.md` and dispatch. The template names its own placeholders; fill every one, and leave none unreplaced. Pass no session history: the reviewer reads the repository and the diff, and anything it needs from the conversation belongs in the template you fill.

4. **Read the status.**
   - **Approved**: go to step 7.
   - **Issues Found**: go to step 5.
   - **Neither, or the dispatch failed**: see "When the Dispatch Fails" below.

5. **Process the findings through `receiving-code-review`.** That skill verifies each item, pushes back where the reviewer is wrong, and implements what survives, in the severity order set by `../_shared/code-review.md`. Pushback is a legitimate outcome: an item the reviewer got wrong is closed by the reasoning, not by a change to the code.

   Only its **Applied** return continues this loop. **Clarification required** and **Escalated** both need a person, so carry them to the user and stop; re-dispatching a reviewer cannot supply what it never had. **Pushback pending** needs an answer from whoever produced the feedback before the batch closes.

6. **Re-dispatch** against the updated range and return to step 4. At most three dispatches in this invocation. When the third returns anything other than Approved, stop and return **Issues outstanding**.

7. **Return** per the Return Contract.

The loop lives here rather than in the callers on purpose. A caller that reviews, fixes, and then decides for itself whether to re-review ends up either skipping the re-review, as a bug fix easily does once the fix looks obviously right, or running this whole cycle a second time around the outside. Neither is what the caller wanted, and both are invisible from inside the caller.

### Why Fixes Get Re-Reviewed

The dispatch that returns Approved must be one that read the fixes. Code written in response to a review is ordinary new code: it was not reviewed when it was written, it is written under pressure to close a finding, and it is exactly where a fix for one issue introduces another. An Approved verdict from before the fixes describes code that no longer exists.

### When the Dispatch Fails

A dispatch that returns no usable status, reports BLOCKED, or errors has reviewed nothing, so it spends no budget. Retry it once, escalating one tier per `../_shared/subagent-dispatch.md`. If the retry also fails, return **Issues outstanding** with the dispatch failure as the outstanding item, so the decision reaches a human rather than a third attempt.

## Return Contract

This section is addressed to whichever skill or user invoked this one. It lives here because invoking this skill is what loads the file, so the caller has the text at the moment it needs it.

**Approved.** The most recent dispatch found no Critical or Important issues. The caller receives the range reviewed, any Minor issues left deferred, and the reviewer's recommendations. The caller continues. Minor issues and recommendations travel unapplied by design: deferring them is permitted by `../_shared/code-review.md`, and acting on them here would expand a change the review had already cleared.

**Issues outstanding.** The three-dispatch budget is spent with Critical or Important issues remaining, or the reviewer could not be dispatched. The caller receives those issues and **MUST NOT** invoke this skill again in the hope of a better verdict. The budget exists so that a change which will not converge reaches a human rather than a fourth reviewer. The caller stops and puts it to the user.

**Nothing to review.** The range is empty. Nothing was reviewed and no budget was spent. This is a precondition failure, not an approval, and the caller **MUST NOT** treat it as one: the mandatory-review requirement in `../../rules/common/code-review.md` is unsatisfied. The caller establishes where the work actually is and invokes this skill again.

**Range unknown.** The base could not be established and the user has not supplied one. Nothing was reviewed. The caller obtains the base and invokes this skill again.

**Invoking again after the code changes.** Approved covers the exact diff that was reviewed. If the code then changes, the Approved no longer describes what the caller is holding, and the caller invokes this skill again against the new range with a full budget. That is a first review of code no reviewer has seen, not budget evasion. The distinction that matters is what prompted the new invocation: new code, or an unwelcome verdict on unchanged code.

## Worked Example

Task 2 of an orchestrated flow is complete: verification and repair functions for a conversation index. The user chose "Ask me each time" for commits and has not been asked yet, so the work is in the tree and uncommitted.

```bash
BASE_SHA=a7981ec          # base_sha recorded on the task board for Task 2
git status --porcelain    # M src/index.ts, ?? src/repair.ts
git diff --stat "$BASE_SHA"
```

The diff is non-empty and `repair.ts` is untracked, so the reviewer is told to read it directly rather than expect it in the diff. Dispatch the reviewer at the Low-cost default tier, resolved per `../_shared/subagent-dispatch.md`.

**Dispatch 1** returns Issues Found:

- Strengths: clean separation, real tests, no mocks of code under test
- Important: `repairIndex()` swallows a write failure and reports success (`repair.ts:64`)
- Minor: magic number (100) for the reporting interval; no progress indicator on long runs
- Status: Issues Found

`receiving-code-review` verifies the Important item, confirms the swallowed failure is real, and fixes it. The two Minor items are logged and deferred.

**Dispatch 2** reads the fix and returns Approved with a recommendation about extracting the interval as a named constant. Return **Approved**, carrying the two deferred Minor issues and the recommendation. Task 3 may begin.

Note what the Minor items did not do: they did not block, and they did not get fixed on the way past. Note also that the second dispatch was not optional. The fix to `repairIndex()` was new, unreviewed code touching an error path, which is where a fix for one issue most often introduces another.

## Completion Gate

You **MUST NOT** return Approved unless all of these are true:

- The most recent dispatch **in this invocation** returned Approved. A previous Approved from earlier in the session, or your own reading of the fixes, does not count.
- That dispatch reviewed a range that included every fix made during this invocation.
- Every Critical and Important issue raised across every dispatch is either fixed in the code you are returning, or was pushed back through `receiving-code-review` with technical reasoning the reviewer did not contest.
- Every deferred Minor issue is enumerated in the return.
- The reviewer's recommendations travel with the return.

If any one is false, one of the other three return states is the honest one.

## Red Flags

Every thought below means stop:

- "The diff came back empty, so the change must be clean." An empty diff means you are pointing at the wrong place. Nothing was reviewed.
- "The fix was small, so it does not need re-reviewing." The re-review is the dispatch that earns the Approved. Skipping it means no reviewer ever read the code you are shipping.
- "This is close enough to Approved." The verdict comes from a dispatch, not from you.
- "One more dispatch and it will converge." The budget is the answer to that thought, not an obstacle to it.
- "I will just fix this Minor one while I am here." Deferring is the permitted response. Fixing it expands a change that was already cleared, and nothing re-reviews it.
- You are reading the diff and forming your own verdict rather than dispatching. That is the orchestrator reviewing its own work, which is what the second pair of eyes exists to prevent.

## Common Mistakes

| Mistake                                                    | Why it is wrong                                                                                                                                  |
|------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| Defaulting the base to `HEAD~1`                            | Right only for single-commit work. On a multi-task feature it reviews the last task and reports on the whole thing.                              |
| Reviewing `BASE..HEAD` when the tree is dirty              | Excludes the working tree, so the reviewer reads the previous commit and none of the work. `debugging` reaches this skill in exactly that state. |
| Forgetting untracked files                                 | A new file that was never added shows in `git status` but not in `git diff`. The reviewer will report on a change with its main file missing.    |
| Treating **Nothing to review** as an approval              | The mandatory review has not happened. The empty range is a bug in the range, not evidence about the code.                                       |
| Returning Approved on the verdict that preceded the fixes  | That verdict described code that no longer exists.                                                                                               |
| Letting the caller decide whether to re-review             | The loop belongs to this skill. Callers that own it either skip it or run it twice.                                                              |
| Passing session history to the reviewer                    | Violates context isolation. Anything the reviewer needs from the conversation goes in the template.                                              |
| Fixing the reviewer's findings yourself in this context    | `../_shared/subagent-dispatch.md` forbids patching a subagent's output in the orchestrator context. Findings go through `receiving-code-review`. |
| Accepting every finding because a reviewer produced it     | `../_shared/code-review.md` makes pushback mandatory where the reviewer is wrong. An unverified fix to a non-issue is a change nobody asked for. |
| Counting a failed dispatch against the budget              | A dispatch that errored reviewed nothing. Retry once at the next tier; spending budget on it burns a review the change never got.                |
| Pre-escalating to a high tier because the change feels big | Size is not the signal. `../_shared/subagent-dispatch.md` requires one tier at a time, on evidence.                                              |

## Template

The reviewer prompt template lives at `../_shared/code-reviewer-prompt.md`. It is the single source of truth for its own placeholders; do not restate them here. The same template is shared by three call sites: this skill, the per-task review in `../orchestrated-implementation/SKILL.md`, and `../fast-path-implementation/SKILL.md`. This skill fills neither of the template's two optional blocks, Scope and Triage Re-Check; both stay omitted, heading included, for a dispatch made from here.
