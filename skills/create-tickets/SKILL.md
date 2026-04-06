---
name: create-tickets
description: Turns an approved design into tickets in the project's ticketing system, or into a structured Markdown document when no ticketing system is available. Decomposes the design into right-sized child tickets under a single parent epic whose body carries the full design for future sessions to recover.
---

# Create Tickets

## Load the Ticketing Rules First

This skill depends on the rules in `skills/_shared/tickets.md`. Those rules are **not** always in context; they live next to the ticket skills and are loaded only when a ticket skill is invoked. Before running the procedure below, you **MUST** read `skills/_shared/tickets.md` using the {{READ_FILE_TOOL}} tool if you have not already read it in this session.

The detection of which ticketing system is in use lives in the `detect-ticketing-system` skill. This skill is the procedure that decomposes an approved design into tickets and creates them.

**Precondition**: this skill assumes there is an approved design already in conversation context, either from the `brainstorming` skill, from an existing committed specification, or written by the human partner. If there is no approved design, you **MUST** stop and surface this rather than inventing one.

## Procedure

1. **Detect the ticketing system.** Invoke the `detect-ticketing-system` skill. The caller's job is to confirm the result with the user before creating anything.

2. **Decompose the design into ticket shapes.** Map design elements to ticket types using this table:

   | Design Element                                | Ticket Type                                       |
   |-----------------------------------------------|---------------------------------------------------|
   | Overall goal plus full design                 | Epic or parent issue                              |
   | Independent component                         | Individual ticket                                 |
   | Cross-cutting concern (auth, logging, config) | Individual ticket                                 |
   | Integration between components                | Individual ticket, depends on component tickets   |

   Per `skills/_shared/tickets.md`, each child ticket **MUST** fit in a single focused session with acceptance criteria in three to five bullets. If a component does not fit, split it before creation.

3. **Draft the epic body.** Per `skills/_shared/tickets.md`, the epic body is the single source of truth and **MUST** contain the full approved design under a `## Design` heading. Use this structure:

   ```markdown
   ## Goal

   [One-paragraph summary of what this epic delivers]

   ## Design

   [The full approved design, including architecture, key components,
    interfaces, data flow, technical decisions and trade-offs, error handling,
    testing strategy, and anything else that emerged from the design
    conversation]

   ## Tickets

   - [Ticket 1 title] - [reference once created]
   - [Ticket 2 title] - [reference once created]
   ```

   Do not link to external files, conversation transcripts, or commits in place of the `## Design` section. See `skills/_shared/tickets.md` on a single source of truth.

4. **Draft each child ticket.** Each child ticket **MUST** include:

   - **Title**: action-oriented, describes what the ticket delivers (e.g. "Add user authentication middleware")
   - **Description**: what to build, the technical decisions from the design that are relevant to this ticket, and any constraints
   - **Acceptance criteria**: three to five bullets per `skills/_shared/tickets.md`
   - **Dependencies**: explicit references to parent epic and any other tickets that must exist before this work
   - **Labels**: based on work type (feature, infrastructure, testing, documentation)

5. **Order the tickets.** Present the child tickets to the user in the implementation order required by `../../rules/common/workflow.md`: foundations and dependencies first, features next, integration after dependencies, polish last.

6. **Create the epic, then the children.** Use the API appropriate to the detected system (see "Per-system creation" below). Create the epic first so that child tickets can reference it as their parent.

7. **Back-fill the epic body.** Once all child tickets exist and have real references (issue numbers, Jira keys, Linear IDs), update the epic body's `## Tickets` section with the actual references and links.

8. **Report to the user.** Summarise:

   - Number of tickets created (epic plus children)
   - Links or references for each
   - Implementation order
   - Dependencies between tickets

   Then use `{{ASK_USER_QUESTION_TOOL}}` to ask whether they want to adjust anything (reorder, split, merge, relabel) before closing out.

## Per-System Creation

### GitHub Issues

With GitHub MCP tools (preferred):

1. Use `issue_write` to create the epic and each child issue
2. Use `get_label` to check for existing labels and create new ones as needed
3. Use `sub_issue_write` to attach children to the epic
4. Reference dependencies in the description: "Depends on #N"

With `gh` CLI (fallback):

```bash
gh issue create --title "..." --body "..." --label "..."
```

GitHub's native sub-issue relationship is not available from `gh` CLI; use "Part of #N" in the body as the parent link.

### Jira

With Atlassian MCP tools:

1. `getVisibleJiraProjects` to find the target project. If more than one is visible, use `{{ASK_USER_QUESTION_TOOL}}` to ask the user which.
2. `getJiraProjectIssueTypesMetadata` to confirm available issue types (Epic, Story, Task, etc.)
3. `createJiraIssue` for the epic first, then each story or task
4. `createIssueLink` to create dependency links and to link stories to the epic

### GitLab Issues

With GitLab MCP tools if available; otherwise use `glab`:

```bash
glab issue create --title "..." --description "..."
```

Reference the parent epic or issue in the description with "Part of #N".

### Linear

With Linear MCP tools. Use `{{ASK_USER_QUESTION_TOOL}}` to ask the user for team and project context before creating issues; Linear requires these upfront.

### Markdown Fallback

When `detect-ticketing-system` returns "none", write a structured Markdown file to the project root or a location the user specifies:

```markdown
# [Feature Name] - Tickets

## Epic

**Goal:** [one-paragraph summary]

**Design:**

[The full approved design, the same content that would go in an epic body]

## Ticket 1: [Title]

**Type:** feature | infrastructure | testing
**Dependencies:** none | Ticket N

**Description:**
...

**Acceptance Criteria:**
- [ ] ...
- [ ] ...
- [ ] ...
```

The file becomes the epic equivalent; `work-on-ticket` can read it directly when the user references a ticket number.

## Closing the Loop

After reporting, remind the user: "To pick up any of these tickets in a new session, reference it (for example, 'work on #42') and the `work-on-ticket` skill will fetch the epic, recover the design, and start implementation."
