# Per-System Persistence

**Load model**: this file is **not** always in context. `./SKILL.md` loads it at step 6, once detection has resolved which system to create in, and earlier at step 3 on the Markdown branch, where the parent's drafted shape depends on it. Read the section for the resolved system and skip the rest; the others describe APIs this run will not call.

One rule binds every section and is not repeated in each: children are created in global dependency order, per step 6 of `./SKILL.md`, so every `Depends on` reference names a ticket that already exists.

## GitHub Issues

With GitHub MCP tools (preferred):

1. Use `issue_write` to create the parent, any grouping tickets, and each child.
2. Use `sub_issue_write` to attach each ticket to its parent. If the API rejects a nesting level, fall back to body-text references (`Part of #<group>`, `Epic: #<parent>`) for the rejected level rather than retrying the call it just refused, and say so in the report.
3. Reference dependencies in the description: `Depends on #N`.

With `gh` CLI (fallback):

```bash
gh issue create --title "..." --body "..."
```

The `gh` CLI cannot create native sub-issue links, so every parent reference goes in the body as text: `Part of #<group>` where the shape has groups, `Epic: #<parent>` otherwise or in addition.

## Jira

With Atlassian MCP tools:

1. `getVisibleJiraProjects` to find the target project. If more than one is visible, ask the user which with `AskUserQuestion`.
2. `getJiraProjectIssueTypesMetadata` to confirm the available issue types, and map the approved shape onto them: the parent is an Epic, a grouping ticket is a Story where the project has one, and children are Tasks.
3. `createJiraIssue` for the parent first, then the rest in dependency order, attaching each via the native `epic` and `parent` fields.
4. `createIssueLink` for any dependency the parent relationship does not already express.

## GitLab Issues

With GitLab MCP tools if available; otherwise use `glab`:

```bash
glab issue create --title "..." --description "..."
```

If group Epics are available (premium GitLab), use a native Epic for the parent and attach children through the Epic-Issue association. If they are not, the parent becomes an ordinary Issue and children carry `Epic: #<parent>` in the body, with `Part of #<group>` where the shape has groups. Warn the user explicitly in the report when degrading: silent flattening leaves them believing they have a hierarchy they do not have.

## Linear

With Linear MCP tools. Ask the user for team and project context with `AskUserQuestion` before creating anything; Linear requires these upfront.

Use an Issue for the parent and sub-issues for the children via the `parent` field. Do **not** map the parent onto a Linear Project: Project is a different lifecycle concept, and conflating the two strands the design somewhere recovery will not look. If Linear rejects a nesting level the approved shape needs, fall back to body-text references for that level and document the degradation in the report.

## Markdown Document

When detection returns None, write a structured Markdown document to the project root or a location the user chooses. The file itself is the parent: its body carries the design, and its `## Tickets` section carries the children as headings.

```markdown
# <Title>

## Goal

[One-paragraph summary of what this delivers]

## Design

[The full approved design, the same content that would go in a parent ticket body]

## Tickets

### <Ticket title>

**Type:** feature | infrastructure | testing | documentation
**Dependencies:** none | <ticket title>

**Description:**

[What to build, the technical decisions from the design relevant to this ticket, and any
 constraints]

**Acceptance Criteria:**

- [ ] ...
- [ ] ...
- [ ] ...
```

Every ticket is an H3 inside `## Tickets`, in implementation order. Where the approved shape groups tickets, the group becomes the H3, carrying its one-sentence theme, and its tickets sit under it as H4s with the same body shape: the heading nesting is the parent link, which is how a future session reads the structure back. Dependencies reference ticket titles, since there are no system-issued identifiers to point at.
