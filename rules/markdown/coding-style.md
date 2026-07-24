---
# noinspection YAMLUnresolvedAlias
globs: **/*.md
---

# Markdown Coding Style

## Headings

You **MUST** structure headings consistently:

- Every non-partial file **MUST** have exactly one H1, as the first heading in the document
- Heading levels **MUST** increase by exactly one at a time; a document **MUST NOT** skip a level (`H1` -> `H2` -> `H3`, never `H1` -> `H3`)
- Headings **MUST** use Title Case
- A heading **MUST** be surrounded by a single blank line above and below
- A `#` inside a fenced code block or inline code span is not a heading and is not subject to these rules

## Partials

A partial is a Markdown file that is not meant to be read standalone: it is sourced, included, or loaded on demand by another file, rather than being an independent entry point. This is the Markdown equivalent of this repository's own `_install-common.sh` convention (a library file marked "source it, do not execute directly").

A file **MUST** be treated as a partial when either of the following is true:

- It lives in a directory whose name begins with an underscore (e.g. `skills/_shared/`)
- It is a supplementary file loaded on demand by a sibling `SKILL.md` in the same skill directory rather than read standalone (e.g. `RULES.md`, `*-prompt.md`)

You **MUST NOT** classify a file as a partial by any other means, such as a comment or your own judgement on the day.

Partials are exempt from the single-H1 requirement only: a partial **MAY** omit an H1 entirely, or contain more than one, because its heading hierarchy exists to organise content for whatever loads it rather than to stand alone. Every other rule in this file, including table alignment, still applies to partials unchanged.

## Tables

You **MUST** keep table columns visually aligned in the raw source:

- Pad every cell with spaces so that every `|` in a column lines up vertically in the raw source. Counting by characters is sufficient; do not attempt to compute per-glyph terminal display width
- When a table is edited, adding, removing, or changing any row, you **MUST** re-pad every row so the whole table realigns. A partially re-padded table is a violation, not a partial fix
- An escaped pipe (`\|`) inside a cell **MUST NOT** be treated as a column separator when calculating alignment
- Do not carve out an exception for wide cells or long content; the column simply becomes as wide as its longest cell

Good:

```markdown
| Name  | Role      | Notes            |
|-------|-----------|------------------|
| Ada   | Architect | Founding member  |
| Grace | Advocate  | Joined later     |
```

Bad:

```markdown
| Name | Role | Notes |
|-------|-----------|------------------|
| Ada | Architect | Founding member |
| Grace | Advocate | Joined later |
```
