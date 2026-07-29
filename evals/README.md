# Triggering Evals

Query sets for measuring whether a skill's `description` fires when it should, and stays quiet when it should not. A skill's description is the only thing the model sees before deciding to load it, so description quality is what decides which skill wins when several could plausibly apply.

This directory sits outside `skills/` on purpose. `install.sh` installs every file it finds under `skills/` with no extension filter, so anything placed inside a skill folder ships to the user's `~/.claude/skills/`. Eval fixtures are development artefacts and must not be installed.

The same applies to run outputs, and more urgently, because a run creates them without being asked. `skill-creator` defaults to writing results into `<skill-name>-workspace/` as a sibling of the skill directory, which here would resolve to `skills/brainstorming-workspace/` and put a full transcript archive into the install payload. Always point runs at `evals/workspace/` instead. That path and any `*-workspace/` directory are gitignored.

The query sets (`evals/*.json`) are source and belong in version control. Everything a run generates (transcripts, `benchmark.json`, `feedback.json`, per-iteration output directories) is regenerable and does not.

## Format

Each file is a JSON array consumed by the `skill-creator` plugin's description optimiser:

```json
[
  {"query": "what a user would actually type", "should_trigger": true}
]
```

Aim for 8 to 10 of each polarity. The useful negatives are near-misses, queries that share vocabulary or intent with the skill but should route elsewhere, because those are what the description has to discriminate against. Obviously irrelevant negatives measure nothing.

## Running an optimisation pass

From the `skill-creator` plugin directory, with the model ID of the session you want to match:

```sh
python -m scripts.run_loop \
  --eval-set <repo>/evals/brainstorming-trigger.json \
  --skill-path <repo>/skills/brainstorming \
  --model <model-id> \
  --max-iterations 5 \
  --verbose
```

It splits the set 60/40 into train and held-out test, runs each query three times for a stable trigger rate, and selects the winning description by test score rather than train score. Take `best_description` from the JSON output into the skill's frontmatter.

## Current sets

| File                                    | Skill                      | Discriminates against                                                                                                     |
|-----------------------------------------|----------------------------|---------------------------------------------------------------------------------------------------------------------------|
| `brainstorming-trigger.json`            | `brainstorming`            | `debugging`, `work-on-ticket`, `receiving-code-review`, read-only questions                                               |
| `brainstorming-skip-trigger.json`       | `brainstorming-skip`       | `brainstorming` itself, `work-on-ticket`, `create-tickets`, unrelated uses of the word "skip"                             |
| `brainstorming-standard-trigger.json`   | `brainstorming-standard`   | `brainstorming` itself, the other three mode skills, unrelated uses of the word "standard"                                |
| `design-review-trigger.json`            | `design-review`            | `requesting-code-review`, visual and UI design critique, ADR review, `brainstorming` itself                               |
| `fast-path-implementation-trigger.json` | `fast-path-implementation` | `complexity-triage`, `orchestrated-implementation`, "fast path" as a code-level term, a user asserting a change is simple |
| `requesting-code-review-trigger.json`   | `requesting-code-review`   | `receiving-code-review`, reviewing somebody else's PR, `design-review`, `debugging`, reading unfamiliar code              |
| `receiving-code-review-trigger.json`    | `receiving-code-review`    | `requesting-code-review`, `debugging` a red PR, code review as a process question, "review" and "feedback" outside code   |

`brainstorming-skip` and `brainstorming-standard` are hand-off targets rather than self-triggering skills, so their sets invert the usual polarity: the positives are queries where the user has *named* that mode themselves, and the negatives include every phrasing that merely implies it. "I already know what I want" must reach the router rather than skip, and "I know this codebase well" must reach the router rather than standard, because picking a mode on the user's behalf is exactly what `rules/common/workflow.md` forbids.

`design-review` inverts the polarity for a different reason: it is a step inside a design mode and has no standing on its own, because it needs a consolidated summary a caller produced and a caller to return its verdict to. Its positives are therefore all mid-flow, and its hardest negatives are the two collisions its name invites. "Give the checkout flow a design review" is visual critique and belongs to `frontend-design`; "review this ADR I wrote" is a design nobody consolidated through a mode, so it belongs to the router. The set also carries one behavioural negative: a user asking for a fourth dispatch after the three-dispatch budget is spent must not reach the skill, because the Return Contract forbids exactly that re-invocation.

`fast-path-implementation` inverts the polarity for the same structural reason as `design-review` and carries a harder negative set than either. Its positives are all mid-flow, because reaching it requires a SIMPLE verdict from `complexity-triage` and a commit preference the caller already asked for, neither of which a user can supply by asking. Its negatives split three ways. Two are collisions of vocabulary: "fast path" is an ordinary term for a code-level hot path, so both an optimisation request and a security review of one appear in the set. The third and most important is behavioural. A user saying "this is dead simple, skip the ceremony" is asserting the very verdict the skill exists downstream of, and a description that lets that phrasing through hands the user's change to a path that skipped triage entirely, which is exactly the guarantee the six criteria are there to provide.

The two code review sets are the only pair in this directory that have to discriminate against each other, and the boundary between them is not the vocabulary, which is identical, but the direction of travel. `requesting-code-review` fires when a change is finished and needs looking at; `receiving-code-review` fires when somebody has already looked and said something. Each therefore carries the other's positives as its hardest negatives, phrased as closely as they realistically get: "can you review my branch before I open the PR" against "the reviewer left six comments, work through them".

Their other negatives split three ways. Reviewing code that is not the user's change is the first: somebody else's pull request belongs to the `review` command, a candidate's take-home is a hiring judgement, and a dependency's source is an adoption question. The second is the surrounding process, where asking how to speed up review turnaround or how to reply to an inline comment from the CLI is a question about the practice rather than a request to perform it. The third is pure vocabulary collision, which is why both sets carry a performance review and a design doc: "review" and "feedback" are among the most overloaded words a user can type, and a description matching on them alone will fire on a conversation about somebody's manager.

`requesting-code-review` also carries two behavioural positives that no keyword would catch. "Task 4 is implemented and committed, moving on to task 5" names no review at all, but `rules/common/code-review.md` makes one mandatory at exactly that point, and a description that waits to be asked hands the user an unreviewed task. "Nothing committed yet because I wasn't sure about the approach" is the uncommitted-work case the skill's range handling exists for, and it has to reach the skill rather than be turned away for having no commit to point at.

`brainstorming-standard` is the harder of the two to get right. Its name is the closest of the four to the plain English of "brainstorming", so a description that only says what the skill does will pull generic design requests ("let's design X") away from the router, which silently costs the user their mode choice. That failure is what its negative set is built to catch.
