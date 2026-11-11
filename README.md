# elelem

Rules and skills for Claude Code, OpenCode, and Codex, with interactive installers for all three harnesses.

## Quick start

```sh
./install.sh
```

Pick your harness at the prompt; the front controller execs the matching installer. To skip the prompt for scripted installations, run `./install-claude.sh`, `./install-opencode.sh`, or `./install-codex.sh` directly.

## Claude Code

The Claude Code installer prompts for scope (user `~/.claude/` or project `<project>/.claude/`) and optional common rules, workflow skills and agents. Every language pack and its activation policy are mandatory. It installs:

- Rules under `~/.claude/rules/` or `<project>/.claude/rules/`
- Skills under `~/.claude/skills/` or `<project>/.claude/skills/`

Selected common rules and `rules/elelem-language-packs.md` load unconditionally. Language bodies live in skills, not the auto-loaded rules tree. See [On-demand language packs](#on-demand-language-packs).

You can also run `./install-claude.sh` directly to skip the harness prompt.

After installing, verify inside Claude Code with `/memory`.

## OpenCode

The OpenCode installer prompts for scope (user `~/.config/opencode/` or project `<project>/.opencode/`) and optional common rules, workflow skills and agents. Every language pack and its activation policy are mandatory. It installs:

- Rules under `~/.config/opencode/rules/` or `<project>/.opencode/rules/`
- Skills under `~/.config/opencode/skills/` or `<project>/.opencode/skills/`

Language bodies are deferred skills. The installer also maintains:

- `opencode.json`: exact owned instruction entries for selected common rules and the mandatory activation policy, alongside unrelated user settings and instructions
- `.elelem-opencode-instructions.json`: ownership metadata for those exact entries
- `AGENTS.md`: a generated preamble linking selected common rules and the activation policy, without eager language links

`opencode.json` is shared configuration, never a whole-file uninstall target. Reinstall and uninstall preserve unrelated entries, settings and an existing config symlink. Even an originally installer-created config is retained.

You can also run `./install-opencode.sh` directly to skip the harness prompt.

### Disable the Claude Code fallback

OpenCode has a built-in Claude Code fallback that reads rules from `~/.claude/` alongside its own config. If you have also run the Claude installer, OpenCode will load the Claude-substituted rules from there, which gives you Claude tool names like `Read` and `Agent` in an OpenCode session instead of OpenCode's `read` and `task`. The rules still parse, but the instructions refer to tools the OpenCode assistant does not recognise by those names.

Set `OPENCODE_DISABLE_CLAUDE_CODE=1` in your shell environment to disable the fallback. Recommended if you use both harnesses on the same machine.

```sh
export OPENCODE_DISABLE_CLAUDE_CODE=1
```

Add that line to `~/.zshrc` or `~/.bashrc` to persist it across shell sessions.

## Codex

The Codex installer prompts for scope and optional common rules, workflow skills and agents. Every language pack and its activation policy are mandatory. It installs:

- Selected common rules and the activation policy into a managed elelem block inside `~/.codex/AGENTS.md` or `<project>/AGENTS.md`
- Skills under `~/.agents/skills/` or `<project>/.agents/skills/`

Codex does not use a separate rule directory. Instead, the installer assembles the selected rule files into a generated Markdown block inside `AGENTS.md`. Any content outside that block is preserved. Re-running the installer replaces only the elelem-managed block.

Language bodies are installed as deferred skills, not merged into `AGENTS.md`.

The installer writes `.elelem-manifest-codex` and prunes stale skill files on re-installation. `AGENTS.md` is updated in place rather than pruned via the manifest.

You can also run `./install-codex.sh` directly to skip the harness prompt.

### Existing AGENTS.md content

If you already maintain your own `AGENTS.md`, the Codex installer appends or updates an elelem-managed block delimited by:

```md
<!-- elelem:codex:start -->
...
<!-- elelem:codex:end -->
```

Everything outside that block is left untouched.

## Optional agent bundle

Each harness installer offers an optional bundle of 11 agents. Select the bundle during installation to install the native definitions for the chosen scope:

- Claude Code: `~/.claude/agents` or `<project>/.claude/agents`
- OpenCode: `~/.config/opencode/agents` or `<project>/.opencode/agents`
- Codex: `~/.codex/agents` or `<project>/.codex/agents`

Before writing the bundle, the installer checks applicable user and project file-backed agents and relevant configuration declarations. Competing files or declarations with the same agent identity block installation, as do applicable inputs that cannot be inspected safely. Existing canonical agent files and the sibling `agents.LICENSE` notice require replacement consent; refusal preserves them. If a refused notice differs from the bundled notice, the bundle installation stops.

An interrupted installation may leave partial bundle files that are not automatically rolled back. Inspect the affected paths and give them manual attention before retrying. The existing uninstall flow lists manifest-tracked agents and the notice for confirmation before removal.

## Layout

```text
.
├── install.sh            Front controller; prompts which harness to install
├── install-claude.sh     Claude Code installer (also runnable directly)
├── install-opencode.sh   OpenCode installer (also runnable directly)
├── install-codex.sh      Codex installer (also runnable directly)
├── _install-common.sh    Common functions sourced by every installer
├── rules/
│   ├── common/           Always-on rules (no frontmatter)
│   │   ├── language.md
│   │   ├── coding-style.md
│   │   ├── code-organisation.md
│   │   └── ...
│   └── python/           Canonical language topics and filename guidance
│       ├── coding-style.md
│       ├── testing.md
│       └── tooling.md
└── skills/               Workflow skills with their own SKILL.md
    ├── _shared/          Files referenced by more than one skill
    ├── debugging/
    │   ├── SKILL.md      The procedure
    │   ├── RULES.md      Procedural rules loaded when the skill runs
    │   └── investigator-prompt.md
    ├── ...
```

Selected `rules/common/` files are copied for Claude Code and OpenCode, while Codex assembles them into its managed block. Canonical `rules/<language>/` files generate language skills at install time. Workflow `skills/` remain optional. Both skill types use the harness-specific skills location:

- Claude Code: `~/.claude/skills/` or `<project>/.claude/skills/`
- OpenCode: `~/.config/opencode/skills/` or `<project>/.opencode/skills/`
- Codex: `~/.agents/skills/` or `<project>/.agents/skills/`

Cross-references between files use relative paths from the citing file's location (for example, `../../rules/common/debugging.md` from inside `skills/debugging/SKILL.md`) so that they resolve correctly in the source repo and in the directory-based installations.

- `rules/common/` rules have no frontmatter and load unconditionally.
- Language packs (`rules/python/`, `rules/typescript/`, etc.) use `globs:` as filename guidance for generated skills, not harness-native activation.
- Each skill folder has a `SKILL.md` that defines the procedure. Skill folders may also contain a `RULES.md`, prompt-template files, or other supporting files.
- `skills/_shared/` holds files referenced by more than one skill.

## Workflow skills

`workflow-coordinator` is the entry point for new work and resumptions. It owns phase transitions, explicit skips, approvals, state, artefact registration, baseline checks, and clean-up. Research and Planning are conversational by default and use a high-capability primary session. The user alone may skip a phase; complexity does not bypass preparation or review, and a skipped review is not approval. Independent Design Review and explicit user approval precede Wave Planning and readiness review. After approval and readiness, implementation waves can run autonomously through the implementation workflow, using lower-cost capable specialists where routing is available. Skill metadata alone does not switch the active model or verify routing.

`research` gathers bounded evidence and discusses findings. The existing `brainstorming` modes shape Planning. `design-review` independently reviews the design, `wave-planning` decomposes approved work and checks readiness, and `subagent-driven-development` executes approved tasks. `create-tickets` creates durable tickets only when requested, while `work-on-ticket` recovers ticket context and returns it to the coordinator for current-baseline validation. `skills/_shared/project-context-discovery.md` is a bounded, repository-first helper, not a substitute for conversational Research or Planning.

Wave planning places ready independent tasks in the earliest safe wave up to
verified harness and resource capacity, recording concrete reasons for
serialisation, including concurrency one. Cohesive bounded tasks may contain
multiple genuine sequential RED/GREEN cycles; related in-scope corrections may
be batched without skipping independent re-review or checks.

Active workflow state and temporary phase files live under `.elelem/workflows/<ticket-or-slug>/`: `workflow.md`, `research.md`, `plan.md`, and `waves.md`, created as needed. At workflow start, the coordinator adds the exact `/.elelem/workflows/` entry to the consuming project's root `.gitignore` and verifies the path is ignored. These files are local and uncommitted by default. Resumption uses local files, so deleting them or using another checkout loses that temporary state; durable ticket bodies retain the approved design. After successful requested work, the coordinator removes only registered workflow-created files. Paused or blocked workflows retain state for resumption. User-requested deliverables such as Markdown ticket fallback files are permanent and are never workflow cleanup targets. Installers do not modify arbitrary consuming projects to add this ignore rule.

### Implementation model selection

Implementation uses `low`, `medium` and `high`: assign the lowest capable tier
with a short task-specific rationale, then resolve the user's native mapping.
Choose the specialist independently of the model. Tier names do not prescribe
reasoning effort. The preparation and reviewer algorithms remain unchanged.

Setup is manual: choose concrete IDs from your own available catalogue and edit
only the intended native scope, preserving unrelated settings. There are no automatic
configuration, default or model writes, no new plugin and no implementation-only
top-level tier map. Existing installers still copy/substitute instructions, not
model configuration. Re-install updated instructions to migrate existing installs;
do not duplicate or change specialists to select their implementation models.
Every value in angle brackets below is a placeholder, not a selected model.

#### OpenCode

For OpenCode V2 (checked against 2.2.6, 2026-11-10), use
`providers.<provider>.models.low|medium|high.modelID`. User configuration is
`~/.config/opencode/opencode.json(c)` (or under `$XDG_CONFIG_HOME/opencode`).
Project discovery searches the current directory and ancestors through the
filesystem root, merging direct `opencode.json(c)` files farthest to closest,
then `.opencode/opencode.json(c)` files farthest to closest. All discovered
`.opencode` documents override direct documents; global files rank below them.
System/managed configuration has highest precedence, including managed macOS
preferences above the system directory. See the configuration reference for
platform-specific managed paths and policies.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "providers": {
    "<provider-id>": {
      "models": {
        "low": {
          "modelID": "<concrete-low-api-model-id>",
          "capabilities": { "tools": true, "input": ["text"], "output": ["text"] },
          "limit": { "context": 32768, "output": 4096 }
        },
        "medium": {
          "modelID": "<concrete-medium-api-model-id>",
          "capabilities": { "tools": true, "input": ["text"], "output": ["text"] },
          "limit": { "context": 32768, "output": 4096 }
        },
        "high": {
          "modelID": "<concrete-high-api-model-id>",
          "capabilities": { "tools": true, "input": ["text"], "output": ["text"] },
          "limit": { "context": 32768, "output": 4096 }
        }
      }
    }
  }
}
```

Use an already configured provider, or configure its native package/connection
separately. These capability flags and numeric example values are illustrative;
replace them with known actual metadata for each target before use. Each alias
needs its own accurate capabilities, limits and variants, not values assumed
inherited from its target. Unknown-model fallback metadata is not detection;
missing capability evidence is a blocker, not permission to infer support.
Add only verified native variants when needed: `#variant` is not a tier.

Selectors are `<provider-id>/low`, `<provider-id>/medium` and
`<provider-id>/high`, optionally with a verified `#variant`, independently of
the agent. `modelID` is an opaque provider-local API target, including slashes;
these are not cross-provider redirects or alias chains. Tiers may live under
different providers, but each tier must have one unique effective mapping.

For diagnostics, `GET /api/config` returns an array of `Config.Entry`
document/directory records, not a merged object. Inspect relevant records safely,
apply native precedence, and count effective provider+alias identities, not
repeated layers overriding one identity. Include disabled and inactive candidates
in ambiguity checks. Cross-check the alias in the current models catalogue and
its own full metadata via `GET /api/model`. Redact credentials and other secrets;
never paste complete configuration or catalogue payloads into task records.

#### Claude Code

The accepted slots are `low=haiku`, `medium=sonnet`, `high=opus`. Explicitly pin
each family through supported settings `env` or process environment, rather
than relying on changing native defaults. Settings locations are user
`~/.claude/settings.json`, shared project `.claude/settings.json` and personal
project `.claude/settings.local.json` (or the configured `CLAUDE_CONFIG_DIR`).

```json
{
  "env": {
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "<concrete-haiku-model-id>",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "<concrete-sonnet-model-id>",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "<concrete-opus-model-id>"
  }
}
```

Settings precedence, highest first, is managed, command-line settings, local,
shared project, then user. An `env` block follows settings precedence; process
environment is not another settings layer. In most sessions settings `env`
replaces an inherited shell value for the same variable. Check documented
exceptions and the effective environment, including managed/embedding-host
restrictions, rather than assuming a shell export wins. Project settings can also
depend on workspace trust. These are shared aliases affecting other native uses,
not isolated implementation settings.

Pass `haiku`, `sonnet` or `opus` only when allowed by the actual per-invoke model
enum, not arbitrary concrete IDs in that restricted argument. Check same-family
parent resolution, force settings, specialist overrides and separate reasoning
controls against the actual version/schema. Restrictions or native overrides
can change the resolved target: record the call alias and effective model, not
just the intended pin. Claude provider/deployment resolution is native, not an
OpenCode-style cross-provider alias mechanism. Official documentation was checked
2026-11-10; no local Claude runtime was available for routing acceptance.

#### Codex

Use `$CODEX_HOME/` (default `~/.codex/`) files `low.config.toml`,
`medium.config.toml` and `high.config.toml`, respectively:

```toml
model = "<concrete-low-model-id>"
model_reasoning_effort = "low"
```

```toml
model = "<concrete-medium-model-id>"
model_reasoning_effort = "medium"
```

```toml
model = "<concrete-high-model-id>"
model_reasoning_effort = "high"
```

Since Codex 0.134, native profile files use top-level keys, not `[profiles.low]`
tables in `config.toml`. Migrate legacy tables into the named files yourself.
The illustrated efforts are independent choices, not a tier-to-effort rule;
replace each with a value supported by the chosen model/provider.
For native launches, precedence increases from system/user base configuration
through the selected user profile, trusted project `.codex/config.toml` layers
(closest wins), and CLI overrides, subject to managed requirements.

In this workflow the files are a declarative source only: the coordinator reads
model, effort and provider compatibility. Never pass `--profile` to a child,
apply unrelated settings or change the parent session. Classic Codex 0.163.0
source exposes independent `agent_type`, `model` and `reasoning_effort` fields;
V2 exposure can be gated, so inspect the actual session tool schema before use.
Pass those independent native fields only when supported. The child's inherited
provider or custom specialist model/effort overrides may block the mapping.
Do not assume the source profile switches provider, duplicate a specialist, or
change its definition to disguise an unsupported route. Checked 2026-11-10;
installed classic 0.163.0 source/schema evidence is not live dispatch proof.

#### Faults, corrections and runtime boundary

A confirmed configuration-resolution fault (missing, malformed, ambiguous,
disabled/inactive or unavailable selected mapping) triggers a visible warning
naming the fault, source, requested tier and exact current-model fallback.
Continue without a routine prompt only after the current selection is available,
capable and explicitly routable to the same specialist. Preserve its applicable
effort/variant, and keep requested tier distinct from effective selection.
An illustrative warning, with placeholders rather than selected models:

```text
Warning: requested tier low is missing from <config-source>.
Using current-model fallback <current-provider>/<current-model>, with its existing effort/variant, for <same-specialist>; availability, capability and explicit routing checked.
```

Inability to inspect or enumerate is missing evidence, not a mapping fault.
A valid but incapable mapping, unsupported route or unusable current model
requires a user decision. No arbitrary defaults, working-model search, omitted
model inheritance or workflow tier escalation is allowed; an execution failure
is not a configuration fallback opportunity.

Before first dispatch record the source/revision, tier/rationale, independent
specialist, selector/provider/API target, effort/variant, fallback reason/warning
and evidence in the existing task record. In-scope corrections must reuse the
actual selected or fallback pin; do not reselect the then-current session model.
Relevant drift or a requested workflow model change requires explicit authorisation.

Existing external plugins' runtime retries and model-switch recovery are outside
this policy and remain unchanged. Do not block solely because of their mere
existence; workflow pins do not control external runtime changes. Requested
selection is not observed runtime proof. Native availability, catalogue/docs
and structural tests are not successful live-route evidence, nor is worker
self-report. Live runtime acceptance for this implementation was explicitly
waived and remains unverified, not passed. Optional future manual scenarios in
`_tests/workflow_scenarios.md` are not a completion gate for this change.

Native references (checked 2026-11-10):

- OpenCode [configuration](https://opencode.ai/docs/config), [models/aliases](https://opencode.ai/docs/models), [providers](https://opencode.ai/docs/providers) and [API](https://opencode.ai/docs/api).
- Claude Code [settings/precedence](https://code.claude.com/docs/en/settings), [environment precedence](https://code.claude.com/docs/en/env-vars#precedence), [model pins](https://code.claude.com/docs/en/model-config) and [subagent models](https://code.claude.com/docs/en/sub-agents#choose-a-model).
- Codex [profile files](https://developers.openai.com/codex/config-file/config-advanced.md), [subagents](https://developers.openai.com/codex/subagents) and version-pinned [classic field definitions](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/tools/handlers/multi_agents_spec.rs) / [registration gates](https://github.com/openai/codex/blob/rust-v0.163.0/codex-rs/core/src/tools/spec_plan.rs).

### Workflow verification

The shared phase-evidence contract is a procedural gate, not runtime enforcement.
At workflow boundaries the coordinator checks concise provenance in existing
`workflow.md` records, not a separate report or per-tool-call checklist. Loading
a skill or obtaining later approval does not prove omitted procedures ran.
Exact-source scoped user skips and currently valid prior evidence are supported;
gaps return to the earliest unsupported phase while preserving useful work.
Research dialogue or its separately chosen alternative remains distinct from
the Planning method. Structural tests check policy wiring and all three harness
copy/substitution paths, not live agent compliance or runtime prevention.

At actual coordinator-managed phase or assigned-task handoffs, the same active
coordinator validates the return and records the next action in existing
`workflow.md`. It proceeds to the next required phase without routine prompts,
while preserving approval, review, verification, TDD, debugging and skip gates.
This is not a per-tool-call loop and does not guarantee live harness compliance.
See `_tests/workflow_scenarios.md` for manual handoff scenarios in Claude Code,
OpenCode and Codex. Structural checks do not prove that a live agent follows the
rule.

Run the automated workflow checks with the existing shell tools and Python 3.11+
(standard-library JSON/TOML parsing in the focused suite, no packages to install):

```sh
bash _tests/run_implementation_model_selection_tests.sh
bash _tests/run_workflow_tests.sh
bash _tests/run_workflow_continuation_tests.sh
```

The existing automated installer suites can also be run with:

```sh
bash _tests/run_install_opencode_tests.sh
bash _tests/run_install_codex_e2e.sh
bash _tests/run_install_codex_tests.sh
```

The scenarios in `_tests/workflow_scenarios.md` are manual live-harness checks, not automated checks and not evidence that those scenarios have already been run. Harness-specific routing and actual model capability must be verified in the target harness.

### Test pruning

After all implementation tasks, task reviews/checks and integration barriers,
the cumulative final reviewer must return `PASS`. That verdict, not user
approval, triggers one separate final review-phase task through the invocable
`test-pruning` skill. Its thin entry delegates the single detailed procedure to
`skills/_shared/test-pruning.md`. Ordinary workers report changed paths and
rename mappings, not whole-file case inventories; task reviewers do not wait
for pruning evidence.

The coordinator preserves the immutable workflow baseline, relevant task
baselines/checkpoints and pre-existing dirty/untracked contents. It accumulates
actual touched-path history across tasks and reviewer corrections, including
reverted edits and renames. Once all writers stop, build one live inventory
across that union, including every older test and independent parameterised
case. Resolve renames to live destinations; missing or unexplained deleted
paths block. A broad HEAD diff cannot replace history or include unrelated user
work. The independent auditor receives
the complete canonical Meaningful Assertions rule and applicable project test
rules from the complete active instruction sources for Claude Code, OpenCode,
or Codex. Source identities and applicability are frozen and rechecked; an
uncertain or conflicting active source blocks weaker removal decisions.

The audit classifies scaffolding, implementation-detail, duplicate, and
timing-dependent cases, then returns `KEEP`, `REMOVE`, or `MERGE`. Under the
canonical rule, removal is permitted when the auditor cannot name a production
defect, without claiming that no defect exists. A duplicate may be removed
when one retained survivor detects a shared defect, even if other defects are
not preserved. A `MERGE` requires a small assertion with a named production
line, reachable path, and failure reason, added to a current-audit `KEEP`
survivor. Unsupported merges are withheld. Higher-priority instructions and
the canonical rule precede project rules, which precede generic categories;
project rules may relax generic category guards. Never delete a test file or
its last test.

The coordinator records full inventories, stable input identities, scoped
recovery, non-zero pre-prune and post-prune discovery counts, and the accepted
snapshot. Later survivor changes invalidate dependent decisions transitively;
removed sources are reassessed from preserved context and restored only through
scoped recovery when removal is no longer supported. An empty test-bearing
scope is recorded as not applicable, not as an audit. Automated workflow checks
verify policy and installation contracts; they do not establish live agent
compliance. The adversarial scenarios in `_tests/workflow_scenarios.md` are
manual and remain unrun unless explicitly reported otherwise.

Only actual pruning edits require independent bounded pruning-delta review of
those edits and affected coverage. No-change audits need no delta review. Final
verification follows the last pruning edit and review correction, then clean-up.
Do not automatically repeat cumulative review or restart pruning; invalidated
inputs require targeted evidence recovery. Failures block completion and
substantive corrections return to implementation/review, not production edits
inside pruning. An explicit pruning skip permits no pruning removals and skips
neither review nor verification. A cumulative-review skip is not `PASS` and
requires explicit sequencing authorisation before pruning. Source edits alone
do not activate installed policy or establish live compliance.

## On-demand language packs

Every install includes Go, JavaScript, PHP, Python, Rust and TypeScript packs, even when optional common rules and workflow skills are declined. Each generated `elelem-language-<language>/` directory contains a thin `SKILL.md` and `references/` copies of its canonical topics. Tool placeholders are substituted in wrappers and references.

The always-loaded policy directs the assistant to invoke applicable language skills before substantive reading, creating, editing or reviewing current-task files. The wrapper directs explicit reads of relative references: coding style for language work, testing for actual test work and tooling for applicable manifests/build configuration. Multiple packs may apply, and scope growth requires reassessment. Repository language inventories and incidental Markdown mentions do not activate packs. Shared JavaScript/TypeScript tooling needs task context; material ambiguity requires a question. Delegated briefs carry applicable skill requirements without bulk-preloading bodies. A missing required skill or reference blocks affected work visibly.

This is assistant-directed loading, not deterministic routing. It does not unload previously read context or promise measured performance improvements. Installer checks verify delivery, references and ownership, not live assistant compliance.

### Migration and uninstall

Rerun the matching installer from the checkout that holds its `.elelem-manifest-<harness>`. Existing manifests identify stale managed language rules to prune; all generated wrappers, references and policy files become managed. Unmanaged namespaced skill or policy collisions block installation with a remediation message rather than overwrite user files. Existing managed-file replacement behaviour remains unchanged. Keep the manifest for future migration and uninstall; changing its recorded scope is rejected.

For OpenCode, legacy exact instruction ownership is inferred only from installed rule paths in the old manifest, including manifests that formerly listed the whole config. Ambiguous custom eager inclusions are preserved with a warning, so review those manually if you want to remove old eager loading. Malformed config, missing parsing dependencies or uncertain ownership block safe cleanup and retain retry metadata. Correct the reported issue and rerun; do not delete ownership records to bypass the check. Codex preserves content outside its managed block during reinstall and uninstall.

Run `./uninstall.sh` from the installer checkout, select its manifests and confirm the listed removals. Unmanaged files are preserved. OpenCode cleanup removes identifiable owned instruction entries, not the shared config or its symlink.

## Writing a new language pack

Keep language bodies canonical under `rules/<language>/`, normally in `coding-style.md`, `testing.md` and `tooling.md`. Use a lowercase language directory name. Give each topic concrete filename guidance in a single comma-separated `globs:` line:

```yaml
---
globs: pattern1, pattern2, pattern3
---
```

The generator reads `globs:` lines as metadata, not a runtime matcher. Do not replace them with YAML lists or `paths:`. Include source, test and tooling filenames in their relevant topics. Installers discover language directories automatically; do not duplicate bodies under `skills/` or add eager imports. Use tool placeholders where needed, then run the packaging and integration suites below after changing a pack.

## Rule authoring conventions

- British English (see `rules/common/language.md`)
- No emojis, no em/en-dashes in prose
- `MUST` / `MUST NOT` / `SHOULD` / `MAY` used in the RFC 2119 sense
- Keep rules concise. If a rule needs a long explanation, it is probably two rules
- Cross-references use relative paths from the citing file

## Tool-name placeholders

Placeholders of the form `{{TOOL_NAME}}` are substituted in every `.md` file under `rules/` and `skills/` at install time. Each installer declares its own placeholder map:

- Claude Code: `install-claude.sh`
- OpenCode: `install-opencode.sh`
- Codex: `install-codex.sh`

Claude Code uses PascalCase tool names such as `Read`, `Write`, and `Agent`. OpenCode uses lowercase short names such as `read`, `write`, and `task`. Codex is less one-to-one: where Codex exposes a documented command such as `/plan`, `/skills`, or `Apply Patch`, the installer uses that literal form; otherwise it substitutes a Codex-safe capability phrase rather than inventing a fake native tool name.

Not every placeholder is a tool name. `MODEL_ENUMERATION` is a notable exception: it is a gerund phrase describing how the current harness enumerates available models. The mechanism differs per harness (Claude Code inspects the `model` enum on the Agent tool schema; OpenCode and Codex run shell commands to list models). Any new harness must supply its own `MODEL_ENUMERATION` value as a gerund phrase that flows after the word 'by' in context (for example, 'by running `opencode models`' or 'by reading the model enum').

### Adding support for another LLM tool

If support is added for another harness, two things need attention:

1. Create `install-<harness>.sh` with its own `<HARNESS>_PLACEHOLDERS` and `<HARNESS>_SUBSTITUTIONS` arrays.
2. Add the harness to the `harness_items` array in `install.sh`.

When adding a new placeholder, audit existing files for hard-coded values that should now go through it. When authoring substitution values for Claude Code and OpenCode, forward-slash (`/`) breaks the install with a perl syntax error, and dollar-sign (`$`) causes silent text corruption. (Codex is unaffected.)

## Verification

After any change to rules or skills:

1. Run `./install.sh` against a test project, or run `./install-claude.sh`, `./install-opencode.sh`, or `./install-codex.sh` directly.
2. For Claude Code, open Claude Code in that project and run `/memory` to confirm expected files are listed.
3. For OpenCode, confirm `opencode.json` instructions contain only selected common/bootstrap entries plus unrelated user entries, not managed language globs.
4. For Codex, confirm the target `AGENTS.md` contains the elelem managed block without language bodies and skills are installed under `.agents/skills/`.
5. For every harness, inspect generated language wrappers and relative references. In a safe fresh session, observe actual skill/reference reads for single-language, mixed-language, new TypeScript tests and later scope growth. Markdown/shell mentions alone should not load packs. Without observable reads, report behavioural checks unverified.

Automated isolated installer checks (Bash, Perl, jq and Expect, with Python 3 for broader workflow suites):

```sh
bash _tests/run_language_pack_helpers_tests.sh
bash _tests/run_opencode_instruction_ownership_tests.sh
ELELEM_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/elelem-tests.XXXXXX")" bash _tests/run_language_pack_install_tests.sh
bash _tests/run_language_pack_integration_tests.sh
```

## FAQ

<details>
<summary><strong>Can I install elelem for more than one harness on the same machine?</strong></summary>

Yes. The installers maintain separate manifest files (`.elelem-manifest-claude`, `.elelem-manifest-opencode`, `.elelem-manifest-codex`) and separate target trees (`~/.claude/`, `~/.config/opencode/`, `~/.codex/AGENTS.md` plus `~/.agents/skills/`). Re-installing one harness prunes only that harness's managed files.

</details>

<details>
<summary><strong>Why does the Codex installer write a managed block into <code>AGENTS.md</code> instead of copying rules into a separate directory?</strong></summary>

Codex consumes persistent repository instructions from `AGENTS.md`, not from a dedicated rule directory. The managed block lets elelem install and update its rules without overwriting unrelated instructions you may already keep in the same file.

</details>

<details>
<summary><strong>Are language packs automatically attached by file path?</strong></summary>

No. All three harnesses discover generated skills, while the mandatory policy directs the assistant to invoke the relevant packs and read applicable topics for current-task files. Source globs supply filename guidance only. Installed delivery does not prove a live assistant followed that policy.

</details>
