# elelem

Claude Code rules and skills, authored here and installed into `.claude/rules/` either at project or user scope.

## Layout

```
.
├── install.sh            Interactive installer for rules
├── instructions/
│   ├── common/           Always-on rules (no frontmatter)
│   │   ├── language.md
│   │   ├── coding-style.md
│   │   ├── code-organisation.md
│   │   └── ...
│   └── python/           Path-scoped rules (with `globs:` frontmatter)
│   │  ├── coding-style.md
│   │   ├── testing.md
│   │   └── tooling.md
│   └── php/
│   │   └── ...
└── skills/               Skills (pending review)
```

- `common/` rules have **no frontmatter** and load unconditionally.
- Language packs (`python/`, future `typescript/`, etc.) use `globs:` frontmatter and load only when Claude reads a matching file.

## Installation

```sh
./install.sh
```

The script prompts for:

1. **Scope**: project (`<project>/.claude/rules/`) or user (`~/.claude/rules/`).
2. **Project path**, if project scope.
3. **Language packs** to install, if any.

Common rules are always installed. Language packs are opt-in.

After installing, verify inside Claude Code with `/memory`.

### User-scope caveat

User-scope path-scoped rules have a known issue ([claude-code#21858](https://github.com/anthropics/claude-code/issues/21858)) where `globs:` frontmatter is not honoured under `~/.claude/rules/`. Common rules (no frontmatter) are unaffected. Prefer project scope if you rely on language packs.

## Writing a new language pack

Create `instructions/<language>/<topic>.md` and start the file with the **only** frontmatter format that is known to work reliably:

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

- British English (see `instructions/common/language.md`)
- No emojis, no em/en-dashes in prose
- `MUST` / `MUST NOT` / `SHOULD` / `MAY` used in the RFC 2119 sense
- Keep rules concise. If a rule needs a long explanation, it is probably two rules

## Skills

The `skills/` directory is present but pending a full review. Do not rely on its current contents.

## Verification

After any change to rules:

1. Run `./install.sh` against a test project
2. Open Claude Code in that project
3. Read a file that should trigger a path-scoped rule
4. Run `/memory` and confirm the expected rule files are listed
