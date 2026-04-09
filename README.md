# elelem

Rules and skills for Claude Code, OpenCode, and Codex, with interactive installers for all three harnesses.

## Quick start

```sh
./install.sh
```

Pick your harness at the prompt; the front controller execs the matching installer. To skip the prompt for scripted installs, run `./install-claude.sh`, `./install-opencode.sh`, or `./install-codex.sh` directly.

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

## Codex

The Codex installer prompts for scope and selections for common rules, language packs, and skills. It installs:

- Rules into a managed elelem block inside `~/.codex/AGENTS.md` or `<project>/AGENTS.md`
- Skills under `~/.agents/skills/` or `<project>/.agents/skills/`

Codex does not have a Cursor-style rule directory. Instead, the installer assembles the selected rule files into a generated Markdown block inside `AGENTS.md`. Any content outside that block is preserved. Re-running the installer replaces only the elelem-managed block.

Unlike Claude Code, selected language packs are not path-scoped in Codex. If you install a language pack, its instructions apply in every Codex session for that scope because they are merged into `AGENTS.md`.

The installer writes `.elelem-manifest-codex` and prunes stale skill files on re-install. `AGENTS.md` is updated in place rather than pruned via the manifest.

You can also run `./install-codex.sh` directly to skip the harness prompt.

### Existing AGENTS.md content

If you already maintain your own `AGENTS.md`, the Codex installer appends or updates an elelem-managed block delimited by:

```md
<!-- elelem:codex:start -->
...
<!-- elelem:codex:end -->
```

Everything outside that block is left untouched.

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

The source layout deliberately mirrors the installer inputs: `rules/` is copied directly for Claude Code and OpenCode, while Codex assembles selected rule files into `AGENTS.md`. `skills/` installs to the harness-specific skills location:

- Claude Code: `~/.claude/skills/` or `<project>/.claude/skills/`
- OpenCode: `~/.config/opencode/skills/` or `<project>/.opencode/skills/`
- Codex: `~/.agents/skills/` or `<project>/.agents/skills/`

Cross-references between files use relative paths from the citing file's location (for example, `../../rules/common/debugging.md` from inside `skills/debugging/SKILL.md`) so that they resolve correctly in the source repo and in the directory-based installs.

- `rules/common/` rules have no frontmatter and load unconditionally.
- Language packs (`rules/python/`, future `rules/typescript/`, etc.) use `globs:` frontmatter. Claude Code keeps that path-scoped behaviour; OpenCode and Codex treat selected language packs as always-on for the chosen scope.
- Each skill folder has a `SKILL.md` that defines the procedure. Skill folders may also contain a `RULES.md`, prompt-template files, or other supporting files.
- `skills/_shared/` holds files referenced by more than one skill.

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

## Tool-name placeholders

Placeholders of the form `{{TOOL_NAME}}` are substituted in every `.md` file under `rules/` and `skills/` at install time. Each installer declares its own placeholder map:

- Claude Code: `install-claude.sh`
- OpenCode: `install-opencode.sh`
- Codex: `install-codex.sh`

Claude Code uses PascalCase tool names such as `Read`, `Write`, and `Agent`. OpenCode uses lowercase short names such as `read`, `write`, and `task`. Codex is less one-to-one: where Codex exposes a documented command such as `/plan`, `/skills`, or `Apply Patch`, the installer uses that literal form; otherwise it substitutes a Codex-safe capability phrase rather than inventing a fake native tool name.

### Adding support for another LLM tool

If support is added for another harness, two things need attention:

1. Create `install-<harness>.sh` with its own `<HARNESS>_PLACEHOLDERS` and `<HARNESS>_SUBSTITUTIONS` arrays.
2. Add the harness to the `harness_items` array in `install.sh`.

When adding a new placeholder, audit existing files for hard-coded values that should now go through it.

## Verification

After any change to rules or skills:

1. Run `./install.sh` against a test project, or run `./install-claude.sh`, `./install-opencode.sh`, or `./install-codex.sh` directly.
2. For Claude Code, open Claude Code in that project and run `/memory` to confirm expected files are listed.
3. For OpenCode, confirm `opencode.json` exists in the install base and contains an `instructions` array.
4. For Codex, confirm the target `AGENTS.md` contains the elelem managed block and skills are installed under `.agents/skills/`.

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
<summary><strong>Why do Codex language packs apply globally instead of by file path?</strong></summary>

The source rule format is path-scoped via `globs:` so that Claude Code can auto-attach the language pack when matching files are read. Codex's installed instruction surface is `AGENTS.md`, which is scope-based rather than path-based, so selected language-pack content is merged into the active instructions for that entire scope.

</details>
