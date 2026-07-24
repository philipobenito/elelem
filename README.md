# elelem

Rules and skills for Claude Code, with an interactive installer.

### Breaking change: OpenCode and Codex support removed

This repository previously supported OpenCode and Codex alongside Claude Code. That support has been removed; elelem now targets Claude Code only. If you have an existing OpenCode or Codex installation from an earlier version of this repo:

- It is no longer managed by this repo. The `.elelem-manifest-opencode` / `.elelem-manifest-codex` manifest files and the files they list are orphaned; `uninstall.sh` only reads `.elelem-manifest-claude` and will not touch them.
- Remove the orphaned files manually (using the old manifest as a guide to what was installed), or stay on an older tag of this repo if you still need OpenCode or Codex support.

## Quick start

```sh
./install.sh
```

`install.sh` is the only entry point; it prompts for scope and selections directly.

## Claude Code

The installer prompts for scope (user `~/.claude/` or project `<project>/.claude/`) and selections for common rules, language packs, and skills. It installs:

- Rules under `~/.claude/rules/` or `<project>/.claude/rules/`
- Skills under `~/.claude/skills/` or `<project>/.claude/skills/`

Common rules (no frontmatter) load unconditionally. Language packs use `globs:` frontmatter and load when Claude reads matching files.

After installing, verify inside Claude Code with `/memory`.

### User-scope caveat

User-scope path-scoped rules have a known issue ([claude-code#21858](https://github.com/anthropics/claude-code/issues/21858)) where `globs:` frontmatter is not honoured under `~/.claude/rules/`. Common rules (no frontmatter) are unaffected. Prefer project scope if you rely on language packs.

## Layout

```text
.
├── install.sh            Installer; prompts for scope and selections
├── uninstall.sh           Reads .elelem-manifest-claude and removes the install
├── _install-common.sh    Common functions sourced by install.sh and uninstall.sh
├── _tests/                Test scripts and fixtures for the installers
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
├── skills/                Workflow skills with their own SKILL.md
│   ├── _shared/          Files referenced by more than one skill
│   ├── debugging/
│   │   ├── SKILL.md      The procedure
│   │   ├── RULES.md      Procedural rules loaded when the skill runs
│   │   └── investigator-prompt.md
│   └── ...
└── .elelem-manifest-claude   Written by install.sh; read by uninstall.sh
```

- `rules/common/` rules have no frontmatter and load unconditionally.
- Language packs (`rules/python/`, `rules/typescript/`, etc.) use `globs:` frontmatter and are auto-loaded by Claude Code when matching files are read.
- Each skill folder has a `SKILL.md` that defines the procedure. Skill folders may also contain a `RULES.md`, prompt-template files, or other supporting files.
- `skills/_shared/` holds files referenced by more than one skill.

Cross-references between files use relative paths from the citing file's location (for example, `../../rules/common/debugging.md` from inside `skills/debugging/SKILL.md`) so that they resolve correctly in the source repo and in the installed directory tree.

## Uninstalling

```sh
./uninstall.sh
```

`uninstall.sh` reads `.elelem-manifest-claude`, which records the install base and every file `install.sh` wrote there. It shows the planned removal (files to delete and directories to prune if they end up empty), asks for confirmation, then deletes the listed files, prunes any directories left empty, and removes the manifest file itself. Files not recorded in the manifest are left untouched.

## Writing a new language pack

Create `rules/<language>/<topic>.md` and start the file with the only frontmatter format that is known to work reliably:

```yaml
---
globs: pattern1, pattern2, pattern3
---
```

Critical rules (per [claude-code#17204](https://github.com/anthropics/claude-code/issues/17204)):

- Field name MUST be `globs`, not `paths`
- Value MUST be a single unquoted string of comma-separated glob patterns
- Do NOT use a YAML list (`- "**/*.ts"`), quoted strings, or JSON array syntax; they silently fail to match
- A single-pattern value is fine: `globs: **/*.php`

Working:

```yaml
#file: noinspection YAMLUnresolvedAlias
---
globs: **/*.ts, **/*.tsx, **/*.js
---
```

Broken:

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
- Cross-references use relative paths from the citing file

## Verification

After any change to rules or skills:

1. Run `./install.sh` against a test project.
2. Open Claude Code in that project and run `/memory` to confirm expected files are listed.
