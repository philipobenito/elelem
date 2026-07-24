# Per-System Creation

**Load model**: this file is **not** always in context. `create-tickets/SKILL.md` loads it at
step 6, once `detect-ticketing-system` has resolved which system to create in. Read the section
for the detected system and skip the rest; the others describe APIs this run will not call.

Two rules bind every section below and are not repeated in each:

- **Tier markers are mandatory on every ticket, in every path, including degraded ones.**
  `resolve_epic_context` reads the marker instead of inferring tier from link topology, so a
  ticket created without one is unrecoverable by the skill that has to pick it up later. See
  the Tier Markers section of `../_shared/tickets.md`.
- **Tasks are created in global topological order of their dependencies**, across Stories
  rather than within them, so a `Depends on` reference always names a ticket that already has
  an identifier. Creating in presentation order leaves forward references pointing at nothing.

## GitHub Issues

With GitHub MCP tools (preferred):

1. Use `issue_write` to create the Epic, each Story (if any), and each Task. Apply tier labels
   at creation: `tier:epic`, `tier:story`, `tier:task` (use `get_label`, and create the label
   if it is missing).
2. Use `sub_issue_write` to attach children to their parent. **Decision rule for nesting**, in
   order:
   1. Try Epic to Story to Task using two `sub_issue_write` calls (Story as sub-issue of Epic;
      Task as sub-issue of Story).
   2. If the second-level nest is rejected by the API, attach Tasks as sub-issues of the Story
      but reference the Epic via body text (`Epic: #<epic>`).
   3. If the first-level nest is also rejected, fall back to fully flat: Stories and Tasks are
      labelled siblings of the Epic, and parent references go in body text
      (`Part of #<story>, Epic: #<epic>`).
3. Loose Tasks (those belonging to no Story) attach directly to the Epic as sub-issues.
4. Reference dependencies in the description: `Depends on #N`.

With `gh` CLI (fallback):

```bash
gh issue create --title "..." --body "..." --label "tier:epic"
```

The `gh` CLI cannot create native sub-issue links, so parent references **MUST** go in the Task
or Story body as text (`Part of #<parent>`, plus `Epic: #<epic>` for Tasks under Stories).

## Jira

With Atlassian MCP tools:

1. `getVisibleJiraProjects` to find the target project. If more than one is visible, use
   `AskUserQuestion` to ask the user which.
2. `getJiraProjectIssueTypesMetadata` to confirm the available issue types (Epic, Story, Task,
   Sub-task).
3. `createJiraIssue` for the Epic first, then each Story (if any), then each Task. The native
   issue type **is** the tier marker per `../_shared/tickets.md`, so no separate label is needed.
4. Use the native `epic` and `parent` fields to attach Stories to the Epic and Tasks to their
   parent Story or Epic. A loose Task takes the Epic as its parent.
5. `createIssueLink` for any cross-Task dependency beyond the parent relationship.

## GitLab Issues

With GitLab MCP tools if available; otherwise use `glab`:

```bash
glab issue create --title "..." --description "..." --label "tier:epic"
```

If group **Epics** are available (premium GitLab), use the native group Epic for the top tier
and create Stories and Tasks as Issues with `tier:story` and `tier:task` labels respectively.
Stories link to the Epic via the native Epic-Issue association; Tasks link to their parent Story
via `Part of #<story>` body text, and loose Tasks link to the Epic via the Epic-Issue
association.

If group Epics are **not** available, the top tier becomes a labelled Issue (`tier:epic`) and
the rest cascades the same way: a Story is a labelled Issue carrying `Part of #<epic>`, a Task
is a labelled Issue carrying `Part of #<story>, Epic: #<epic>`, and a loose Task carries
`Epic: #<epic>` alone. Warn the user explicitly in the step 8 report when degrading to no-Epic
mode. Silent flattening leaves the user believing they have a hierarchy they do not have.

## Linear

With Linear MCP tools. Use `AskUserQuestion` to ask the user for team and project context before
creating issues; Linear requires these upfront.

Use Issue plus sub-issue plus sub-issue with `tier:epic` / `tier:story` / `tier:task` labels.
**Do not** map Epic to a Linear Project: Project is a different lifecycle concept, and
conflating the two breaks recovery.

Attempt the two-level nest first. On rejection from Linear's API, **degrade to two-tier**:

- Each Task carries `tier:task` and a slugified Story label `story:<slug>`, where the slug is
  lowercase, hyphenated, ASCII, and derived from the Story theme statement.
- The Story grouping is preserved in the epic body's `## Design` under `### Story: <name>`.
- Recovery in degraded Linear walks Task to Epic in one hop and reads the Story theme from the
  epic body, using the `story:<slug>` label as the index.
- Document the degradation in the step 8 report.

## Markdown Fallback

When `detect-ticketing-system` returns "none", write a structured Markdown file to the project
root or a location the user specifies. One file per Epic. The file itself is the Epic, and
heading levels carry the tier markers for the Tasks and Stories inside `## Tickets`.

```markdown
# <Epic Title>

## Goal

[One-paragraph summary of what this epic delivers]

## Design

[The full approved design, the same content that would go in an epic body]

### Story: <name>

[One-sentence rationale for this grouping. Only present when Stories are introduced. This
 sub-heading belongs to the `## Design` block and is rationale, not a ticket.]

## Tickets

### Tasks

#### Task: <title>

**Type:** feature | infrastructure | testing | documentation
**Dependencies:** none | Task N

**Description:**

[What to build, the technical decisions from the design relevant to this Task, and any
 constraints]

**Acceptance Criteria:**

- [ ] ...
- [ ] ...
- [ ] ...

### Story: <name>

Theme: [one-sentence theme statement]

#### Task: <title>

[same body shape as above]
```

### Reading the Structure Back

`## Goal`, `## Design` and `## Tickets` are document structure, not tier markers. Only headings
**inside `## Tickets`** identify tickets, which is what keeps the `### Story:` rationale under
`## Design` from being mistaken for a grouping.

Within `## Tickets`:

| Heading        | Meaning                                                      |
|----------------|--------------------------------------------------------------|
| `### Tasks`    | Bucket for Tasks belonging to no Story. Not a ticket itself. |
| `### Story: X` | A Story. Carries a theme statement, never design content.    |
| `#### Task: Y` | A Task. Its parent is the nearest preceding H3.              |

A Task's parent is therefore decided by the **type** of the nearest preceding H3 rather than by
its position in the file: under `### Tasks` it is a direct child of the Epic, and under
`### Story: X` it is a child of that Story. Emit the `### Tasks` bucket before any Story so the
file reads in implementation order (cross-cutting foundations first, per
`../../rules/common/workflow.md`), but note that ordering is for the human reader; correctness
does not depend on it.

Omit `### Tasks` entirely when every Task belongs to a Story, and omit all `### Story:` headings
when the epic is flat. The `####` level for a Task is invariant across both shapes.

The file becomes the epic equivalent, and `work-on-ticket` reads it directly when the user
references a Task.
