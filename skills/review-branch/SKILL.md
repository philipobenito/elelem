---
name: review-branch
description: "Reviews a branch on behalf of a human reviewer and presents each finding twice: an explanation for the person who asked, then a concise, paste-ready comment for the branch's author, anchored to a file and line. Use this when the user invokes /review-branch, with or without a branch or ticket key, or asks for review comments to leave on a branch, whether it is their own or a colleague's. Resolves the review range against the primary branch, confirms a stacked parent before using it, dispatches one read-only reviewer, and checks every finding before presenting it. It never fixes anything. Not for the agent's own pre-ship review with a fix loop, which is `work-review-request`, and not for acting on feedback already received, which is `work-review-receive`."
---

# Reviewing a Branch

Reviews the committed range of a branch and returns review comments a human can leave for the author, each paired with an explanation of why it matters.

The reader of this skill's output is a human reviewer, not the agent. The agent does not fix anything, does not loop, and does not decide what the author does next. It finds the problems, checks that they are real, and writes them up twice: once for the person who asked, with all the evidence, and once for the author, as a short comment that stands on its own in a pull request.

## Reading the Invocation

Arguments arrive as free text, for example `/review-branch VAN3-111 against release/2.4, focus on the retry logic`. Read three things from it:

| Part   | How to recognise it                                                         | Where it goes                                     |
|--------|-----------------------------------------------------------------------------|---------------------------------------------------|
| Target | A branch name, a fragment of one, or a ticket key such as `VAN3-111`        | "Resolve the Target" below                        |
| Base   | A ref introduced by "against", "base", "onto", or "from", or `--base <ref>` | Overrides stack detection and the primary default |
| Focus  | Anything else the user asks the review to look at                           | `[USER_FOCUS]` in the reviewer prompt             |

If a part is absent, the procedure below supplies it. If the text is genuinely ambiguous about which part a word belongs to, ask rather than guess.

## Establishing the Range

Every comment this skill produces is anchored to a line. A range that is stale, too wide, or taken from the wrong parent produces anchors that do not exist in the pull request the author is looking at, so a wrong range makes the whole output useless, not merely less accurate.

### Find the Primary Branch

Resolve the primary branch before anything else, because the steps below compare against it. Read it from `git symbolic-ref --short refs/remotes/origin/HEAD` and strip the `origin/` prefix it returns, falling back to a local `main` or `master`. If neither settles it, ask, and if the user cannot say, return **Range unknown**.

The names below hold for the rest of the procedure:

| Name          | Value                                                                                                       |
|---------------|-------------------------------------------------------------------------------------------------------------|
| `PRIMARY`     | The primary branch name, for example `main`                                                                 |
| `PRIMARY_REF` | `origin/$PRIMARY` where it exists, otherwise `$PRIMARY`, because a local primary branch is frequently stale |
| `HEAD_BRANCH` | The branch under review, without any `origin/` prefix                                                       |
| `HEAD_REF`    | The ref the range ends at, settled by "Local Against Remote"                                                |

### Resolve the Target

With a target in the invocation, resolve it to a branch, taking the first rule that matches:

1. An exact local branch
2. An exact `origin/<target>` branch
3. Local and `origin/` branches whose name contains the target, treating `feature/x` and `origin/feature/x` as one candidate

```bash
git for-each-ref --format='%(refname:short)' --exclude=refs/remotes/origin/HEAD \
  refs/heads/ refs/remotes/origin/ | grep -iF -- "$TARGET"
```

If more than one candidate remains, ask which one with `AskUserQuestion`. If none remains, run `git fetch origin` once and resolve again. If there is still none, stop and return **Target not found**.

With no target, the head is the checked-out branch. If HEAD is detached, or the checked-out branch is the primary branch, ask which branch to review. If the user does not name one, return **Range unknown**.

### Target Not Checked Out

If the resolved branch is not the checked-out branch, ask with `AskUserQuestion` before touching the working tree:

- **Fetch and switch (Recommended):** `git fetch origin <branch>`, then `git switch <branch>`. If only the remote branch exists, `git switch` creates a local tracking branch.
- **Review without switching:** fetch if the branch exists only on the remote, and read files at the head with `git show`.
- **Cancel.**

If `git status --porcelain` shows a dirty tree, say so in the question, because a switch carries uncommitted changes across or refuses. If `git switch` refuses, report its message and return **Switch refused**. Never stash, reset, restore, or discard anything to make a switch succeed.

### Local Against Remote

A local branch and its remote can disagree. A local copy of a colleague's branch can be behind what the pull request shows, and your own branch can carry commits the author's pull request does not have yet. Either way, the anchors would not match what the author sees.

When the branch has a local ref and `origin/<branch>` also exists, fetch and compare them:

```bash
git fetch origin "$HEAD_BRANCH"
git rev-list --left-right --count "$HEAD_BRANCH...origin/$HEAD_BRANCH"   # ahead, behind
```

- If both counts are zero, `[HEAD_REF]` is the local branch and nothing is asked.
- If either is non-zero, ask with `AskUserQuestion`: review the local ref (n ahead, m behind) or review `origin/<branch>`. Choosing `origin/<branch>` makes the head a ref that is not checked out.
- If no `origin/<branch>` exists, the local ref is the head, and the header states that the branch is not pushed.

### Find the Base

If the invocation named a base, that ref is the base ref and stack detection is skipped. Go straight to the merge-base at the end of this section.

Otherwise, look for a stacked parent. A candidate is a local branch whose tip is an ancestor of the head, is not the head's own commit, is not the primary branch, and is not already contained in the primary ref:

```bash
head_sha=$(git rev-parse "$HEAD_REF")
for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
  [ "$branch" = "$HEAD_BRANCH" ] || [ "$branch" = "$PRIMARY" ] && continue
  [ "$(git rev-parse "$branch")" = "$head_sha" ] && continue
  git merge-base --is-ancestor "$branch" "$HEAD_REF" || continue
  git merge-base --is-ancestor "$branch" "$PRIMARY_REF" && continue
  echo "$(git rev-list --count "$branch..$HEAD_REF") $branch"
done | sort -n | head -3
```

An upstream that points at some other branch, rather than at `origin/<primary>` or at the branch's own `origin/<branch>`, is also a candidate (`git rev-parse --abbrev-ref "$HEAD_BRANCH@{upstream}"`). Count its commits with `git rev-list --count <upstream>.."$HEAD_REF"` and rank it with the others.

- **A candidate exists:** ask with `AskUserQuestion` whether the branch is stacked on the nearest candidate, listing up to three, or measured against the primary. Put the commit count for each option in its label, for example "stacked on `feature/auth` (3 commits)" against "`origin/main` (11 commits)".
- **No candidate:** use `PRIMARY_REF` without asking. This is a weak default, so state the range in one line at the top of the output, where a wrong guess is easy to spot.

The base ref is the named base, the confirmed parent, or `PRIMARY_REF`. Whichever it is, `BASE_SHA` is `git merge-base "$HEAD_REF" <base ref>`, never the base ref's tip. A base branch that has moved on since the branch was cut would otherwise put its newer commits into the diff, reversed, as though this change removed them.

### Scope

The review covers the committed range `BASE_SHA..HEAD_REF` and nothing else. A pull request comment can land only on committed code, so an uncommitted line has nowhere to be commented on. If the tree is dirty, the output header says that uncommitted changes were excluded.

```bash
git log --oneline "$BASE_SHA..$HEAD_REF"
git diff --stat "$BASE_SHA" "$HEAD_REF"
```

If the range holds no commits, return **Nothing to review** and dispatch nothing.

## Procedure

1. **Read the invocation** per "Reading the Invocation".
2. **Establish the range** per "Establishing the Range". A stop there returns its state and dispatches nothing.
3. **Fill the reviewer prompt** below and dispatch it with `Agent`. Fill every placeholder and pass no session history. Let the dispatch inherit the session model: this is one dispatch that a human asked for, and a missed defect costs more than the dispatch does.
4. **If the dispatch fails**, returning no usable output, reporting BLOCKED, or erroring, retry it once. If the retry also fails, return **Review failed** with what the dispatch reported.
5. **Check every finding** per "Checking the Findings".
6. **Present the review** per "Output Format".

There is no fix loop and no re-review. The human decides what happens to each finding, and the author decides how to fix it.

## The Reviewer Prompt

| Placeholder        | What goes in it                                                                                                                                                              |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `[BRANCH]`         | The branch name being reviewed.                                                                                                                                              |
| `[HEAD_REF]`       | The ref the range ends at: the local branch or `origin/<branch>`, per "Local Against Remote".                                                                                |
| `[BASE_SHA]`       | The base established per "Find the Base".                                                                                                                                    |
| `[READ_FILES_VIA]` | `the working tree` only when the head is checked out and the tree is clean. Otherwise `git show [HEAD_REF]:<path>`.                                                          |
| `[COMMIT_LOG]`     | The output of `git log --format='%h %s%n%b' [BASE_SHA]..[HEAD_REF]`, pasted.                                                                                                 |
| `[USER_FOCUS]`     | What the user asked the review to concentrate on, or `none`.                                                                                                                 |
| `[SEVERITY_TABLE]` | The severity table from the always-on code review rules in `../../rules/common/code-review.md`, pasted whole. That table is canonical, so this template does not restate it. |

`[READ_FILES_VIA]` is never the working tree when the tree is dirty. The reviewer would then read uncommitted text, and its line numbers would drift away from the committed head that the comments have to land on.

```yaml
Agent (general-purpose):
  description: "Branch review: [BRANCH]"
  prompt: |
    You are reviewing a branch on behalf of a human reviewer, who will turn your findings into comments for the branch's author.

    ## The Change

    Branch: [BRANCH]
    Base commit: [BASE_SHA]
    Head: [HEAD_REF]

    ```bash
    git diff --stat [BASE_SHA] [HEAD_REF]
    git diff [BASE_SHA] [HEAD_REF]
    ```

    Read files as they are at the head through [READ_FILES_VIA]. Every line number you report must be a line at [HEAD_REF], except a `deleted` anchor, which is a line at [BASE_SHA].

    ## What the Author Says It Does

    [COMMIT_LOG]

    This is the author's account of the change. It may be incomplete or optimistic. Verify it against the code, and treat anything the commits claim but the code does not do, or the code does but the commits never mention, as worth raising.

    ## Where the Reviewer Asked You to Look

    [USER_FOCUS]

    Look there first, but do not stop there.

    ## What You May and May Not Do

    Read whatever you need to judge the change: the diff, the files it touches, their callers, the tests that cover them, and the conventions of the surrounding code.

    You may not change anything. Do not edit files, switch branches, stage, or commit, and do not run the test suite or the build. Judge the tests by reading them.

    ## What To Check

    Scale this to the change. Skip areas that do not apply and say nothing about them.

    | Area              | What to look for                                                                                    |
    |-------------------|-----------------------------------------------------------------------------------------------------|
    | Correctness       | Bugs, unhandled edge cases, errors caught and swallowed, race conditions, off-by-one boundaries     |
    | Intent            | Behaviour the commits promise and the code does not deliver, and changes the commits never explain  |
    | Tests             | New behaviour without a test, tests that mock the code they claim to test, tests that cannot fail   |
    | Design            | Complexity the problem does not need, responsibilities in the wrong place, duplication worth naming |
    | Consistency       | Naming, structure, and idiom that differ from the surrounding code                                  |
    | Security and data | Untrusted input reaching a boundary unvalidated, secrets in the diff, destructive or lossy paths    |
    | Compatibility     | Breaking changes to a published interface, schema changes without a migration                       |

    ## Calibration

    Report what a careful human reviewer would raise in a pull request. Minor findings are welcome, because small points are a normal part of human review. Wording preferences and structures you would merely have chosen differently are not findings.

    Assign severity with these tests:

    [SEVERITY_TABLE]

    Inflation is the failure to guard against. If an issue would leave you comfortable merging, it is Minor.

    ## Anchoring

    Anchor each finding to the single line an author would expect a comment on. That line must be inside a hunk of the diff above, because a pull request accepts inline comments only there. Where the problem is caused elsewhere, anchor it to the changed line that exposes it, and put the other location in the evidence.

    If the finding is about a removed line, give the line number at the base commit and mark it `deleted`. If no single line fits, for example a missing test file, mark it `general`.

    ## Output Format

    Return every finding in this shape, most severe first. If there are no findings, return exactly `No findings.`

    ### Finding N
    - Severity: Critical | Important | Minor
    - Summary: one line
    - Anchor: path/to/file:line | path/to/file:line (deleted) | general
    - Kind: defect | question
    - Evidence: what is wrong and why it matters, concretely, citing any other file:line that proves it

    Use `defect` when the code alone shows the problem. Use `question` when whether it is a problem depends on context the code does not show, such as an intended behaviour, a caller outside the repository, or a product decision.
```

## Checking the Findings

A comment that turns out to be wrong costs the human reviewer credibility with a colleague, and it costs the author time they spend proving it wrong. So no finding reaches the output on the reviewer's word alone. For each one:

1. **Read the anchored line and the evidence** at the head, using `git show "$HEAD_REF:<path>"` when the head is not the clean, checked-out tree. Read a `deleted` anchor at the base instead, with `git show "$BASE_SHA:<path>"`. If the problem is not there, drop the finding and record a one-line reason.
2. **Confirm that the anchor is inside a hunk** of the same diff the reviewer read, `git diff "$BASE_SHA" "$HEAD_REF" -- <path>`, context lines included. A `deleted` anchor is checked against the base-side (`-`) range of the hunk, every other anchor against the head-side (`+`) range. If it is outside every hunk, move it to the changed line that exposes the problem, or mark it general.
3. **Keep the reviewer's severity and kind** unless the check itself showed them to be wrong. If you change one, say so in the explanation.

This check is not a second review. Do not add findings of your own, because nothing would check them.

## Output Format

Open with a header, then the findings in severity order, then anything dropped.

```markdown
Reviewed `feature/retry-webhooks` against `origin/main` (a1b2c3d): 6 commits, 4 files.
Excluded: uncommitted changes in 1 file.

### 1. Retry loop never gives up on a 4xx [Important]

**For you:** `deliver()` retries on every non-2xx status, including 400 and 404.
`WebhookClient.post` (`src/webhooks/client.ts:31`) throws the same error type for
both, so a malformed payload retries until the queue TTL expires and holds up
that tenant's consumer the whole time.

**Comment on `src/webhooks/consumer.ts:58`**

~~~text
This retries on any non-2xx, so a 400 will keep retrying until the TTL
expires. Is that intended for client errors?
~~~

### 2. Backoff cap is an unexplained constant [Minor]

...

Dropped after checking: 1. The missing null check reported at `src/parser.ts:12`
is already handled on line 9.
```

For a deleted line, the anchor line reads **Comment on `<file>:<line>` (deleted line, base side)**. For a general finding, it reads **General comment**. If nothing survives the check, the output is the header followed by one line saying that no issues were found.

### For You

The explanation is for the person who asked for the review. Tell them what is wrong, why it matters, and the evidence, citing any file and line that proves it. Show the severity tier in the heading so that they can decide what is worth raising. Say plainly when a finding is a judgement call rather than a defect.

### Writing the Comment

The comment is for the author, and it will be read in a pull request without this review around it. It is one human writing to another about one line.

- **Keep it to one to three sentences.** Say what the problem is at this line, in terms visible at this line.
- **Point at the problem, not the fix.** How to fix it is the author's decision. Where a direction is unavoidable, ask it as a question.
- **Make it stand alone.** Do not mention other files, commits, severity tiers, the review, the reviewer, or AI. If the cause lives in another file, describe the consequence as it appears here: "What happens to callers that pass `null` here?"
- **Ask when the code cannot settle it.** Write the comment as a question when the finding's kind is `question`, or when the author probably knows something the reviewer does not.
- **Follow the always-on language and prose-style rules**, as for any other prose you write.

Put the comment in a fenced `text` block so that the human can copy it exactly.

## Return States

| State                 | Meaning                                                                                                  |
|-----------------------|----------------------------------------------------------------------------------------------------------|
| **Reviewed**          | The output above was presented, with findings or with an explicit statement that there were none.        |
| **Nothing to review** | The range holds no commits. Nothing was dispatched, and this says nothing about the quality of the code. |
| **Range unknown**     | The primary branch, the head, or the base could not be established, and the user did not supply one.     |
| **Target not found**  | No branch matched the target, even after a fetch.                                                        |
| **Switch refused**    | `git switch` refused, and its reason was reported. Nothing was stashed or discarded.                     |
| **Review failed**     | The reviewer dispatch failed twice. What it reported is passed on, and no clean verdict is implied.      |

## Worked Example

The user runs `/review-branch VAN3-111` while on `main`.

1. **Resolve.** No branch is called `VAN3-111`. The substring match finds `feature/VAN3-111-retry-webhooks` locally and on `origin`, which counts as one candidate.
2. **Switch.** The branch is not checked out and the tree is clean, so the question offers fetch and switch, review without switching, or cancel. The user picks fetch and switch.
3. **Local against remote.** After the fetch, the local branch is 0 ahead and 2 behind `origin/feature/VAN3-111-retry-webhooks`. The question offers the stale local ref or the remote. The user picks the remote, so `[HEAD_REF]` is `origin/feature/VAN3-111-retry-webhooks` and files are read through `git show`.
4. **Base.** `origin/HEAD` points at `main`. The local branch `feature/VAN3-110-webhook-client` is an ancestor of the head and is not in `origin/main`, so the question offers "stacked on `feature/VAN3-110-webhook-client` (6 commits)" or "`origin/main` (14 commits)". The user confirms the stack.
5. **Review.** One dispatch returns four findings. The check drops one, because the reported missing null check exists two lines above the anchor, and re-anchors another from an unchanged helper to the changed call site.
6. **Present.** The header, three findings in severity order each with **For you** and a comment block, and the one dropped finding.

The skill does not offer to fix anything, and it does not re-review. The human takes it from there.

## Completion Gate

You **MUST NOT** present a review unless all of these are true:

- The range was established by the procedure, and every ambiguity it names was put to the user rather than guessed.
- The reviewer read committed content at `[HEAD_REF]`, never a dirty working tree.
- Every finding presented was checked against the code at the head, and its anchor is inside a hunk, marked deleted, or marked general.
- Every dropped finding is listed with its reason.
- No comment prescribes a fix or mentions another file, a commit, a severity tier, the review, or AI.

## Red Flags

Every thought below means stop:

- "The branch name is close enough, I will use it." Resolve it, and ask when more than one branch matches.
- "The local branch is probably current." Fetch and compare. A stale local ref produces anchors the author cannot find.
- "I will stash their changes so that the switch works." Never. Report the refusal and stop.
- "This finding looks right, no need to check it." The check is what makes the comment safe to post under the human's name.
- "I will fix this while I am here." This skill fixes nothing. The author owns the fix.
- "The comment needs the other file to make sense." Describe the consequence at this line instead, or make it a question.

## Common Mistakes

| Mistake                                        | Why it is wrong                                                                                                        |
|------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| Measuring a stacked branch against the primary | The review then covers the parent branch's commits too, and the comments land on code this pull request never touched. |
| Using a stacked parent without asking          | Stack detection is a heuristic. A branch that merely contains another is not necessarily stacked on it.                |
| Reading the dirty working tree                 | Line numbers drift away from the committed head, so the comments point at the wrong lines.                             |
| Anchoring outside a diff hunk                  | Pull requests reject inline comments on unchanged lines, so the human cannot post the comment where it says.           |
| Prescribing the fix in the comment             | The author owns the change. A comment that names the problem leaves them room to solve it their own way.               |
| Writing the comment for the requester          | The comment's reader is the author, who has not seen the explanation, the other files, or this review.                 |
| Presenting the reviewer's findings unchecked   | A wrong comment costs the human credibility and the author time. Every finding is read against the code first.         |
| Adding your own findings during the check      | The check confirms what the reviewer found. A finding added there has had no check at all.                             |
