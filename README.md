# elelem

Rules and skills for Claude Code, OpenCode, and Cursor, with interactive installers for all three harnesses.

## Quick start

```sh
./install.sh
```

Pick your harness at the prompt; the front controller execs the matching installer. To skip the prompt for scripted installs, run `./install-claude.sh`, `./install-opencode.sh`, or `./install-cursor.sh` directly.

## Claude Code

The Claude Code installer prompts for scope (user `~/.claude/` or project `<project>/.claude/`) and selections for common rules, language packs, and skills. It installs:

- Rules under `~/.claude/rules/` or `<project>/.claude/rules/`
- Skills under `~/.claude/skills/` or `<project>/.claude/skills/`

Common rules (no frontmatter) load unconditionally. Language packs use `globs:` frontmatter and load when Claude reads matching files.

You can also run `./install-claude.sh` directly to skip the harness prompt.

After installing, verify inside Claude Code with `/memory`.

### User-scope caveat

User-scope path-scoped rules have a known issue ([claude-code#21858](https://github.com/anthropics/claude-code/issues/21858)) where `globs:` frontmatter is not honoured under `~/.claude/rules/`. Common rules (no frontmatter) are unaffected. Prefer project scope if you rely on language packs.

## OpenCode

The OpenCode installer prompts for scope (user `~/.config/opencode/` or project `<project>/.opencode/`) and selections for common rules, language packs, and skills. It installs:

- Rules under `~/.config/opencode/rules/` or `<project>/.opencode/rules/`
- Skills under `~/.config/opencode/skills/` or `<project>/.opencode/skills/`

Unlike Claude Code, OpenCode loads selected language packs in every session, not just when matching files are opened. The installer also writes two generated files:

- `opencode.json` contains an `instructions` glob array listing every installed rule directory (e.g. `rules/common/*.md`, `rules/python/*.md`)
- `AGENTS.md` is a human-readable preamble describing OpenCode-specific behaviour and differences from Claude Code

You can also run `./install-opencode.sh` directly to skip the harness prompt.

### Disable the Claude Code fallback

OpenCode has a built-in Claude Code fallback that reads rules from `~/.claude/` alongside its own config. If you have also run the Claude installer, OpenCode will load the Claude-substituted rules from there, which gives you Claude tool names like `Read` and `Agent` in an OpenCode session instead of OpenCode's `read` and `task`. The rules still parse, but the instructions refer to tools the OpenCode assistant does not recognise by those names.

Set `OPENCODE_DISABLE_CLAUDE_CODE=1` in your shell environment to disable the fallback. Recommended if you use both harnesses on the same machine.

```sh
export OPENCODE_DISABLE_CLAUDE_CODE=1
```

Add that line to `~/.zshrc` or `~/.bashrc` to persist it across shell sessions.

## Cursor

The Cursor installer prompts for scope (user `~/.cursor/` or project `<project>/.cursor/`) and selections for common rules, language packs, and skills. It installs:

- Rules under `~/.cursor/rules/` or `<project>/.cursor/rules/`
- Skills under `~/.cursor/skills/` or `<project>/.cursor/skills/`

Rule files are renamed from `.md` to `.mdc` on copy and have Cursor-specific frontmatter applied. Common rules become Always Apply rules (`alwaysApply: true`). Language packs become Auto Attached rules with their `globs:` patterns preserved and `alwaysApply: false` added.

All rules install flat under `<base>/rules/` with an `elelem-<group>-` filename prefix (e.g. `elelem-common-coding-style.mdc`, `elelem-python-testing.mdc`). Cursor does not load `.mdc` files from nested subdirectories of `~/.cursor/rules/` at user scope, so the flat layout is required for the rules to be detected. The `elelem-` prefix prevents collisions with rules you author yourself in the same directory and makes installed files easy to grep for.

**Settings UI visibility caveat.** Installed rules may not appear in Cursor Settings, Rules. This is a known Cursor bug ([forum thread](https://forum.cursor.com/t/rules-in-subdirectories-of-cursor-rules-not-visible-in-mentions-or-settings-ui/155148)) where the Settings rule list and the `@` autocomplete menu skip files Cursor still loads at runtime. To verify rules are working, open a Cursor chat and ask a question whose answer is gated on a rule (for example, "What does the elelem coding-style rule say about emojis?"). If Cursor cites the rule, it is loaded; the missing entries in Settings are cosmetic.

Skills install to `<base>/skills/<name>/SKILL.md` and Cursor auto-discovers them via their `description:` field. SKILL.md files keep their original `name:` and `description:` frontmatter; no additional frontmatter is generated.

The installer writes `.elelem-manifest-cursor` and prunes stale entries on re-install, using the same model as the Claude and OpenCode manifests.

You can also run `./install-cursor.sh` directly to skip the harness prompt.

### Disable third-party config loading

Cursor has a cross-loader that reads rules from `~/.claude/`, `~/.codex/`, and other harness directories. If you have also run the Claude Code installer, Cursor will load the Claude-substituted rules from there, which gives you Claude tool names like `Read` and `Edit` in a Cursor session instead of Cursor's `Read` and `StrReplace`. The rules still parse, but the instructions refer to tools the Cursor assistant does not recognise by those names.

Disable this by navigating to Cursor Settings, then Rules, Skills, Subagents, and toggling off "Include third-party Plugins, Skills, and other configs". Recommended if you use both Claude Code and Cursor on the same machine. This is the Cursor counterpart to the OpenCode `OPENCODE_DISABLE_CLAUDE_CODE` recommendation above.

## Layout

```
.
├── install.sh            Front controller; prompts which harness to install
├── install-claude.sh     Claude Code installer (also runnable directly)
├── install-opencode.sh   OpenCode installer (also runnable directly)
├── install-cursor.sh     Cursor installer (also runnable directly)
├── _install-common.sh    Common functions sourced by every installer
├── rules/
│   ├── common/           Always-on rules (no frontmatter)
│   │   ├── language.md
│   │   ├── coding-style.md
│   │   ├── code-organisation.md
│   │   └── ...
│   └── python/           Path-scoped rules (with `globs:` frontmatter)
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

The source layout deliberately matches the installed layout: `rules/` in this repo installs to `~/.claude/rules/` (Claude) or `~/.config/opencode/rules/` (OpenCode), and `skills/` installs to `~/.claude/skills/` or `~/.config/opencode/skills/`. Cross-references between files use **relative paths from the citing file's location** (e.g. `../../rules/common/debugging.md` from inside `skills/debugging/SKILL.md`) so that they resolve correctly both in the source repo and on disk after install.

- `rules/common/` rules have **no frontmatter** and load unconditionally.
- Language packs (`rules/python/`, future `rules/typescript/`, etc.) use `globs:` frontmatter and load only when Claude reads a matching file (or in every OpenCode session if selected).
- Each skill folder has a `SKILL.md` that defines the procedure. Skill folders may also contain a `RULES.md` (procedural rules read at the start of the skill), prompt-template files (paste-filled into subagent dispatches), or other supporting files.
- `skills/_shared/` holds files referenced by more than one skill (for example, `subagent-dispatch.md` is read by every skill that dispatches a subagent).

## Writing a new language pack

Create `rules/<language>/<topic>.md` and start the file with the **only** frontmatter format that is known to work reliably:

```yaml
---
globs: pattern1, pattern2, pattern3
---
```

**Critical rules** (per [claude-code#17204](https://github.com/anthropics/claude-code/issues/17204)):

- Field name **MUST** be `globs`, not `paths`
- Value **MUST** be a single unquoted string of comma-separated glob patterns
- Do **NOT** use a YAML list (`- "**/*.ts"`), quoted strings, or JSON array syntax. They silently fail to match
- A single-pattern value is fine: `globs: **/*.php`

**Working:**

```yaml
---
globs: **/*.ts, **/*.tsx, **/*.js
---
```

**Broken** (parses but never matches):

```yaml
---
paths:
  - "**/*.ts"
  - "**/*.tsx"
---
```

## Rule authoring conventions

- British English (see `rules/common/language.md`)
- No emojis, no em/en-dashes in prose
- `MUST` / `MUST NOT` / `SHOULD` / `MAY` used in the RFC 2119 sense
- Keep rules concise. If a rule needs a long explanation, it is probably two rules
- Cross-references use relative paths from the citing file (e.g. `../../rules/common/X.md` from a skill, `./Y.md` or just `Y.md` between siblings in the same directory)

## Tool-name placeholders

Placeholders of the form `{{TOOL_NAME}}` are substituted in every `.md` file under `rules/` and `skills/` at install time. Each installer declares its own placeholder map: the Claude map lives in `install-claude.sh` (near the top of the file, `CLAUDE_PLACEHOLDERS` and `CLAUDE_SUBSTITUTIONS` arrays); the OpenCode map lives in `install-opencode.sh` (`OPENCODE_PLACEHOLDERS` and `OPENCODE_SUBSTITUTIONS` arrays).

Claude Code uses PascalCase tool names (`Read`, `Write`, `Agent`), while OpenCode uses lowercase short names (`read`, `write`, `task`).

### Adding support for another LLM tool

If support is added for a second LLM agent harness, two things need attention:

1. **Tool-name map**: create a new `install-<harness>.sh` installer script with its own `<HARNESS>_PLACEHOLDERS` and `<HARNESS>_SUBSTITUTIONS` arrays. Any rule or skill file that hard-codes a tool name (e.g. `EnterPlanMode`) should be migrated to a `{{...}}` placeholder so the target-aware substitution can rewrite it.
2. **Harness selection**: add the new harness to the `harness_items` array in `install.sh` so the front controller can prompt for it.

When adding a new placeholder, audit existing files for hard-coded values that should now go through it.

## Verification

After any change to rules or skills:

1. Run `./install.sh` against a test project (or run `./install-claude.sh`, `./install-opencode.sh`, or `./install-cursor.sh` directly)
2. For Claude Code, open Claude Code in that project and run `/memory` to confirm expected files are listed
3. For OpenCode, confirm `opencode.json` exists in the install base and contains an `instructions` array
4. For Cursor, confirm rules are installed as `.mdc` files under `~/.cursor/rules/` or `<project>/.cursor/rules/` and skills are discoverable

## FAQ

<details>
<summary><strong>Why do you recommend disabling third-party config loading in Cursor and OpenCode?</strong></summary>

Each harness uses different internal tool names. Claude Code uses PascalCase names like `Read`, `Write`, `Edit`, `Bash`, `Grep`, `Glob`, `AskUserQuestion`, and `Task`. OpenCode uses lowercase names like `read`, `write`, `edit`, `bash`, `grep`, `glob`, and `task`. Cursor uses `Read`, `Write`, `StrReplace`, `Shell`, `Grep`, `Glob`, and `AskQuestion` (and has no native subagent or task-tracker primitives). At install time, elelem rewrites `{{TOOL_NAME}}` placeholders to the harness-specific name. If a second harness cross-loads the Claude-substituted rules from `~/.claude/`, the instructions refer to tool names the agent in that harness does not recognise, producing incoherent guidance. Disabling third-party config loading keeps each harness reading only its own rule tree.

</details>

<details>
<summary><strong>Can I install elelem for more than one harness on the same machine?</strong></summary>

Yes. The three installers maintain separate manifest files (`.elelem-manifest-claude`, `.elelem-manifest-opencode`, `.elelem-manifest-cursor`), install to separate directories (`~/.claude/`, `~/.config/opencode/`, `~/.cursor/`), and prune only their own targets on re-install. The recommendation above (disabling third-party config loading) makes coexistence safe by preventing cross-loading.

</details>

<details>
<summary><strong>Why does the Cursor installer not generate an <code>AGENTS.md</code> like the OpenCode installer?</strong></summary>

Cursor auto-discovers `.cursor/rules/*.mdc` (loaded directly, either Always Apply or by `globs:` matching) and `.cursor/skills/<name>/SKILL.md` (auto-discovered via the `description:` field). There is no OpenCode-style configuration manifest layer to reproduce; an `AGENTS.md` would be redundant. Setup advice (the third-party-includes toggle) belongs in this README rather than in a generated file, and harness-specific guidance is already substituted into the rules and skills themselves at install time.

</details>
