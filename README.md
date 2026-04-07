# elelem

Rules and skills for Claude Code and opencode, with interactive installers for both harnesses.

## Quick start

```sh
./install.sh
```

Pick your harness at the prompt (Claude Code or opencode); the front controller execs the matching installer. If you previously ran `./install.sh` directly and want to skip the harness prompt for scripted installs, run `./install-claude.sh` instead.

## Claude Code

The Claude Code installer prompts for scope (user `~/.claude/` or project `<project>/.claude/`) and selections for common rules, language packs, and skills. It installs:

- Rules under `~/.claude/rules/` or `<project>/.claude/rules/`
- Skills under `~/.claude/skills/` or `<project>/.claude/skills/`

Common rules (no frontmatter) load unconditionally. Language packs use `globs:` frontmatter and load when Claude reads matching files.

You can also run `./install-claude.sh` directly to skip the harness prompt.

After installing, verify inside Claude Code with `/memory`.

### User-scope caveat

User-scope path-scoped rules have a known issue ([claude-code#21858](https://github.com/anthropics/claude-code/issues/21858)) where `globs:` frontmatter is not honoured under `~/.claude/rules/`. Common rules (no frontmatter) are unaffected. Prefer project scope if you rely on language packs.

## opencode

The opencode installer prompts for scope (user `~/.config/opencode/` or project `<project>/.opencode/`) and selections for common rules, language packs, and skills. It installs:

- Rules under `~/.config/opencode/rules/` or `<project>/.opencode/rules/`
- Skills under `~/.config/opencode/skills/` or `<project>/.opencode/skills/`

Unlike Claude Code, opencode loads selected language packs in every session, not just when matching files are opened. The installer also writes two generated files:

- `opencode.json` contains an `instructions` glob array listing every installed rule directory (e.g. `rules/common/*.md`, `rules/python/*.md`)
- `AGENTS.md` is a human-readable preamble describing opencode-specific behaviour and differences from Claude Code

You can also run `./install-opencode.sh` directly to skip the harness prompt.

### Disable the Claude Code fallback

opencode has a built-in Claude Code fallback that reads rules from `~/.claude/` alongside its own config. If you have also run the Claude installer, opencode will load the Claude-substituted rules from there, which gives you Claude tool names like `Read` and `Agent` in an opencode session instead of opencode's `read` and `task`. The rules still parse, but the instructions refer to tools the opencode assistant does not recognise by those names.

Set `OPENCODE_DISABLE_CLAUDE_CODE=1` in your shell environment to disable the fallback. Recommended if you use both harnesses on the same machine.

```sh
export OPENCODE_DISABLE_CLAUDE_CODE=1
```

Add that line to `~/.zshrc` or `~/.bashrc` to persist it across shell sessions.

## Layout

```
.
├── install.sh            Front controller; prompts which harness to install
├── install-claude.sh     Claude Code installer (also runnable directly)
├── install-opencode.sh   opencode installer (also runnable directly)
├── _install-common.sh    Common functions sourced by both installers
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

The source layout deliberately matches the installed layout: `rules/` in this repo installs to `~/.claude/rules/` (Claude) or `~/.config/opencode/rules/` (opencode), and `skills/` installs to `~/.claude/skills/` or `~/.config/opencode/skills/`. Cross-references between files use **relative paths from the citing file's location** (e.g. `../../rules/common/debugging.md` from inside `skills/debugging/SKILL.md`) so that they resolve correctly both in the source repo and on disk after install.

- `rules/common/` rules have **no frontmatter** and load unconditionally.
- Language packs (`rules/python/`, future `rules/typescript/`, etc.) use `globs:` frontmatter and load only when Claude reads a matching file (or in every opencode session if selected).
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

Placeholders of the form `{{TOOL_NAME}}` are substituted in every `.md` file under `rules/` and `skills/` at install time. Each installer declares its own placeholder map: the Claude map lives in `install-claude.sh` (near the top of the file, `CLAUDE_PLACEHOLDERS` and `CLAUDE_SUBSTITUTIONS` arrays); the opencode map lives in `install-opencode.sh` (`OPENCODE_PLACEHOLDERS` and `OPENCODE_SUBSTITUTIONS` arrays).

Claude Code uses PascalCase tool names (`Read`, `Write`, `Agent`), while opencode uses lowercase short names (`read`, `write`, `task`).

### Adding support for another LLM tool

If support is added for a second LLM agent harness, two things need attention:

1. **Tool-name map**: create a new `install-<harness>.sh` installer script with its own `<HARNESS>_PLACEHOLDERS` and `<HARNESS>_SUBSTITUTIONS` arrays. Any rule or skill file that hard-codes a tool name (e.g. `EnterPlanMode`) should be migrated to a `{{...}}` placeholder so the target-aware substitution can rewrite it.
2. **Harness selection**: add the new harness to the `harness_items` array in `install.sh` so the front controller can prompt for it.

When adding a new placeholder, audit existing files for hard-coded values that should now go through it.

## Verification

After any change to rules or skills:

1. Run `./install.sh` against a test project (or run `./install-claude.sh` or `./install-opencode.sh` directly)
2. For Claude Code, open Claude Code in that project and run `/memory` to confirm expected files are listed
3. For opencode, confirm `opencode.json` exists in the install base and contains an `instructions` array
