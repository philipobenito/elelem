# Authoring This Repository

This file governs how to author elelem's own content, the rules and skills under `rules/` and `skills/`. It is never installed by `install.sh` and never ships to a user's `~/.claude/` or `<project>/.claude/`. `README.md` covers using and installing elelem; this file covers building it.

## Two Audiences

`rules/` and `skills/` ship to, and govern, OTHER repositories once a user runs `install.sh` against them. This file governs authoring INSIDE elelem itself: it is what a human or Claude reads while adding or changing a rule, a skill, or a shared file in this tree. The two audiences are never the same repository at the same time. Do not blur them, for example by putting installer or authoring guidance into a rule file, or by putting authoring conventions into `README.md` where an installing user, not an authoring Claude, is the reader.

## The Load Model

Every file in this repository is in context under exactly one condition. Nothing is in context by default.

| File class                            | In context when                                      |
| ------------------------------------- | ---------------------------------------------------- |
| `CLAUDE.md`                           | Always, in this repository                           |
| `rules/common/*.md`                   | Always, once installed                               |
| `rules/<lang>/*.md`                   | A file matching its `globs:` frontmatter is read     |
| `skills/<name>/SKILL.md`              | That skill is invoked                                |
| `skills/<name>/RULES.md` and siblings | `SKILL.md` instructs a Read                          |
| `skills/_shared/*.md`                 | A skill instructs a Read                             |
| `skills/_shared/*-prompt.md`          | Never as instruction; pasted into a dispatched agent |

## Canonical Home and Duplication

Content has exactly one canonical home. Finding the same content in two or more places is one of two things:

- **Duplication**, the same content in two or more homes, is a defect whether or not sync notes link the copies. Fix it: pick the canonical home and make every other occurrence a reference to it.
- **Load-bearing structure**, two files sharing a shape (a heading layout, a table skeleton) but carrying different content, is not duplication at all and needs no reconciling.

Where canonical content must reach a dispatched agent, the prompt template carries a fill-at-dispatch placeholder naming the canonical source to paste from, never a synced copy. One cross-file placeholder works this way: `[SEVERITY_TABLE]` in the reviewer prompt embedded in `skills/work-review-request/SKILL.md`, pasted from the severity table in `rules/common/code-review.md`. The canonical source is an always-on rule file, in context by definition, so the paste can neither drift nor fail on an installed tree. "Contracted duplication", a synced second copy justified by dispatched agents being unable to read the first, is retired: both dispatch agent types carry the Read tool, so the premise was false, and the placeholder mechanism removes the drift surface regardless. A skill that ships its own workflow script embeds its prompts and calibration defaults in the script instead; self-containment outranks the placeholder mechanism for new and rebuilt skills, and a rebuilt skill that dispatches with `Agent` embeds its prompt template in its own `SKILL.md`, pasting shared content from a sibling section at dispatch (`design-review` does this with its category table), which leaves no second file to drift.

## Where New Content Belongs

| New content is...                                    | It belongs in...             |
| ---------------------------------------------------- | ---------------------------- |
| An iron law, binding on every repo that installs it  | `rules/common/`              |
| A procedure, the steps a skill runs                  | `skills/<name>/SKILL.md`     |
| Procedural rules that bind only while one skill runs | that skill's own `RULES.md`  |
| Anything shared by two or more skills                | `skills/_shared/`            |
| Text pasted verbatim into a dispatched agent         | `skills/_shared/*-prompt.md` |

## Installer Blast Radius

`install.sh` copies every file it finds under `skills/`, with no extension filter. Anything placed inside a skill folder ships to a user's install, whatever its name or purpose. This is why `evals/` sits outside `skills/`: eval fixtures exercise skills in this repository and MUST NOT be copied out alongside them.

## Verification

There is no test runner for markdown content; a change here is proven by a command, not a test suite.

- A change to a rule or a skill: run `_tests/run_reference_tests.sh`.
- A change to the installer: run `_tests/run_install_claude_tests.sh`.

The reference checker only resolves cross-references written as relative paths (`./` or `../`). A bare-prefix reference, for example `rules/common/code-review.md` written without a leading `../`, is invisible to it: a broken one passes silently. The checker is a guard against one class of broken reference, not a complete one.

## Authoring Conventions No Installed Rule Enforces

Two conventions apply to every file under `rules/` and `skills/`, and neither is enforced by anything a user installs; they hold only because this file states them.

- `MUST` / `MUST NOT` / `SHOULD` / `MAY` are used in the RFC 2119 sense.
- Cross-references are written as relative paths from the CITING file's own location, for example `../../rules/common/debugging.md` from inside `skills/debug-investigation/SKILL.md`, so they resolve both from this repository and from an installed tree.

These two conventions previously lived in `README.md`. They have moved here because `README.md` is read by a human setting up the project, not by Claude authoring it, and `CLAUDE.md` is the file that is always in context in this repository.
