# elelem

Rules and skills for Claude Code and OpenCode, with an interactive installer.

### Codex support removed

This repository previously supported Codex as well. That support has been removed. If you have an existing Codex installation from an earlier version of this repo, the `.elelem-manifest-codex` manifest file and the files it lists are orphaned: `uninstall.sh` does not read them. Remove those files by hand (using the old manifest as a guide), or stay on an older tag of this repo if you still need Codex.

## Quick start

```sh
./install.sh
```

`install.sh` is the only entry point. It asks which harness to install for (Claude Code or OpenCode), then prompts for scope, language packs and skills.

Common rules always install in full. Language packs start unselected. Skills are chosen one by one and start selected; deselect any you do not want. Re-running the installer against the same target removes anything you previously installed but have now deselected.

## Claude Code

The installer prompts for scope (user `~/.claude/` or project `<project>/.claude/`), language packs and skills. It installs:

- Rules under `~/.claude/rules/` or `<project>/.claude/rules/`
- Skills under `~/.claude/skills/` or `<project>/.claude/skills/`

Common rules (no frontmatter) load unconditionally. Language packs use `globs:` frontmatter and load when Claude reads matching files.

After installing, verify inside Claude Code with `/memory`.

### User-scope caveat

User-scope path-scoped rules have a known issue ([claude-code#21858](https://github.com/anthropics/claude-code/issues/21858)) where `globs:` frontmatter is not honoured under `~/.claude/rules/`. Common rules (no frontmatter) are unaffected. Prefer project scope if you rely on language packs.

## OpenCode

The installer prompts for scope (user `~/.config/opencode/` or project `<project>/.opencode/`), language packs and skills. It requires `jq` and `perl`. It installs:

- Rules under `<base>/rules/`, listed in the `instructions` array of `<base>/opencode.json`
- Skills under `<base>/skills/`
- An `AGENTS.md` index of the installed rules at `<base>/AGENTS.md`

What differs from Claude Code:

- Tool names are rewritten as the files are copied: `AskUserQuestion` becomes `question`, `Agent` becomes `task`, and so on. The plan-mode steps become instructions to switch between the Plan and Build agents with Tab, because OpenCode has no plan-mode tools. The substitution table is in `install.sh`; a test fails if a Claude Code tool name survives it.
- OpenCode has no path-based rule activation, so a selected language pack loads in every session.
- `design-committee` and `work-swarm` call a `Workflow` tool that OpenCode does not have. Their existing fallback (sequential `task` dispatch) applies until an OpenCode equivalent exists.
- `opencode.json` is merged, never replaced: the installer adds and removes only its own `rules/...` entries and leaves every other key and instruction alone. It is not recorded in the manifest, so uninstalling never deletes it.
- An existing `AGENTS.md` that elelem did not write is left untouched.

OpenCode also reads `~/.claude/` as a fallback. If you have installed for Claude Code as well, set `OPENCODE_DISABLE_CLAUDE_CODE=1` in your shell so OpenCode does not load both copies.

## Layout

```text
.
├── install.sh            Installer; prompts for harness, scope and selections
├── uninstall.sh           Reads the manifests and removes the installs
├── _tests/                Test scripts and fixtures for the installers
├── rules/
│   ├── common/           Always-on rules (no frontmatter)
│   │   ├── language.md
│   │   ├── coding-style.md
│   │   ├── verification.md
│   │   └── ...
│   └── python/           Path-scoped rules (with `globs:` frontmatter)
│       ├── coding-style.md
│       ├── testing.md
│       └── tooling.md
├── skills/                Workflow skills with their own SKILL.md
│   ├── debug-investigation/
│   │   ├── SKILL.md      The procedure
│   │   └── ...
│   └── ...
├── .elelem-manifest-claude     Written by install.sh for Claude Code; read by uninstall.sh
└── .elelem-manifest-opencode   Written by install.sh for OpenCode; read by uninstall.sh
```

- `rules/common/` rules have no frontmatter and load unconditionally.
- Language packs (`rules/python/`, `rules/typescript/`, etc.) use `globs:` frontmatter and are auto-loaded by Claude Code when matching files are read.
- Each skill folder has a `SKILL.md` that defines the procedure and carries everything the skill needs, including any prompt templates it fills to dispatch agents. Some skills ship supporting files alongside it: reference material their `SKILL.md` reads on demand, or a workflow script it launches.

`rules/` and `skills/` keep the same internal structure once installed, which is what lets files reference each other across the tree. See `CLAUDE.md` for the cross-reference convention itself.

## Uninstalling

```sh
./uninstall.sh
```

`uninstall.sh` reads `.elelem-manifest-claude` and `.elelem-manifest-opencode`, whichever exist. Each records the install base and every file `install.sh` wrote there. For each one it shows the planned removal (files to delete and directories to prune if they end up empty), asks for confirmation, then deletes the listed files, prunes any directories left empty, and removes the manifest file itself. For OpenCode it also removes elelem's entries from `opencode.json`, keeping everything else in it. Files not recorded in the manifest are left untouched.

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
- Keep rules concise. If a rule needs a long explanation, it is probably two rules
- See `CLAUDE.md` for RFC 2119 keyword usage and cross-reference conventions

## Verification

After any change to rules or skills:

1. Run `./install.sh` against a test project.
2. For Claude Code, open it in that project and run `/memory` to confirm expected files are listed. For OpenCode, check that `<project>/.opencode/opencode.json` lists the rules and that the skills appear in a session.
