# elelem

Claude Code rules and skills, authored here and installed into `~/.claude/` (user scope) or `<project>/.claude/` (project scope).

## Layout

```
.
├── install.sh            Interactive installer for rules and skills
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

The source layout deliberately matches the installed layout: `rules/` in this repo installs to `~/.claude/rules/`, and `skills/` installs to `~/.claude/skills/`. Cross-references between files use **relative paths from the citing file's location** (e.g. `../../rules/common/debugging.md` from inside `skills/debugging/SKILL.md`) so that they resolve correctly both in the source repo and on disk after install.

- `rules/common/` rules have **no frontmatter** and load unconditionally.
- Language packs (`rules/python/`, future `rules/typescript/`, etc.) use `globs:` frontmatter and load only when Claude reads a matching file.
- Each skill folder has a `SKILL.md` that defines the procedure. Skill folders may also contain a `RULES.md` (procedural rules read at the start of the skill), prompt-template files (paste-filled into subagent dispatches), or other supporting files.
- `skills/_shared/` holds files referenced by more than one skill (for example, `subagent-dispatch.md` is read by every skill that dispatches a subagent).

## Installation

```sh
./install.sh
```

The script prompts for:

1. **Scope**: project (`<project>/.claude/`) or user (`~/.claude/`).
2. **Project path**, if project scope.
3. **Common rules** to install.
4. **Language packs** to install, if any.
5. **Skills** to install (all or none).

Common rules and skills are selected by default. Language packs are opt-in.

After installing, verify inside Claude Code with `/memory`.

### User-scope caveat

User-scope path-scoped rules have a known issue ([claude-code#21858](https://github.com/anthropics/claude-code/issues/21858)) where `globs:` frontmatter is not honoured under `~/.claude/rules/`. Common rules (no frontmatter) are unaffected. Prefer project scope if you rely on language packs.

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

## Tool-name and path placeholders

`install.sh` substitutes a small set of placeholders in every `.md` file under `rules/` and `skills/` at install time. Placeholders of the form `{{TOOL_NAME}}` are mapped to the corresponding Claude Code tool name (`{{READ_FILE_TOOL}}` becomes `Read`, `{{ASK_USER_QUESTION_TOOL}}` becomes `AskUserQuestion`, and so on). The full map lives in the `substitute_tool_names` function in `install.sh`.

### Adding support for another LLM tool

If support is added for a second LLM agent harness (Cursor, Codex, OpenCode, etc.), two things need attention:

1. **Tool-name map**: extend `substitute_tool_names` in `install.sh` with the alternate tool's names, or fork the function per target tool. Any rule or skill file that hard-codes a Claude-specific tool name (e.g. `EnterPlanMode`) should be migrated to a `{{...}}` placeholder so the target-aware substitution can rewrite it.
2. **Path conventions**: relative cross-references in this repo assume the installed layout matches the source layout (`rules/` and `skills/` as siblings). If a target harness uses a different layout (e.g. flat `~/.cursor/rules/`), the relative paths will not resolve. Either the installer needs to flatten and rewrite paths at install time, or the references need to be expressed via `{{RULES_DIR}}` / `{{SKILLS_DIR}}` placeholders that the installer expands per target.

When adding a new placeholder of either kind, audit existing files for hard-coded values that should now go through it.

## Verification

After any change to rules or skills:

1. Run `./install.sh` against a test project
2. Open Claude Code in that project
3. Read a file that should trigger a path-scoped rule
4. Run `/memory` and confirm the expected files are listed
