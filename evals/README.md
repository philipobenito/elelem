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

| File                          | Skill           | Discriminates against                                              |
|-------------------------------|-----------------|--------------------------------------------------------------------|
| `brainstorming-trigger.json`  | `brainstorming` | `debugging`, `work-on-ticket`, `receiving-code-review`, read-only questions |
