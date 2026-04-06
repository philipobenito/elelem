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
   | Overall goal plus full design                 | Epic                                              |
   | Coherent named theme grouping related Tasks   | Story (only if D2 rule below is satisfied)        |
   | Independent component                         | Task                                              |
   | Cross-cutting concern (auth, logging, config) | Task                                              |
   | Integration between components                | Task, depends on component Tasks                  |

   Per `skills/_shared/tickets.md`, each Task **MUST** fit in a single focused session with acceptance criteria in three to five bullets. If a component does not fit, split it before creation. Stories **MUST** contain between 2 and 6 child Tasks per `skills/_shared/tickets.md`'s sizing rule.

   **Decide whether to introduce a Story tier (D2 rule).** A Story is introduced **only when all** of the following hold:

   1. The design contains **2 or more coherent named themes** (e.g. "authentication flow", "data export pipeline"), AND
   2. **At least 2 of those themes** decompose into **2 or more Tasks** each, AND
   3. The total Task count is **at least 4**.

   Single-theme epics **always** stay flat regardless of Task count, even if the count exceeds 6. Single-Story epics (one Story wrapping every Task) are forbidden because a single Story adds a grouping layer with no sibling. If a single theme grows large (more than 6 Tasks), the skill **SHOULD** escalate to the user via {{ASK_USER_QUESTION_TOOL}} and ask whether the epic should be split into multiple epics rather than introducing a vestigial Story.

   When the rule is satisfied, group children under named Stories and record a **one-sentence rationale per Story** for inclusion in the epic body's `## Design` section under a `### Story: <name>` sub-heading.

3. **Draft the epic body.** Per `skills/_shared/tickets.md`, the epic body is the single source of truth and **MUST** contain the full approved design under a `## Design` heading. Use this structure:

   ```markdown
   ## Goal

   [One-paragraph summary of what this epic delivers]

   ## Design

   [The full approved design, including architecture, key components,
    interfaces, data flow, technical decisions and trade-offs, error handling,
    testing strategy, and anything else that emerged from the design
    conversation]

   ### Story: <name>            <!-- only if Stories are introduced -->

   [one-sentence rationale for this grouping]

   ## Tickets

   - [Story or Task title] - [reference once created]
   ```

   Do not link to external files, conversation transcripts, or commits in place of the `## Design` section. See `skills/_shared/tickets.md` on a single source of truth.

4. **Draft each child ticket.** Split this into drafting Stories (when introduced) and Tasks.

   **4a. Draft each Story (only when Stories are introduced).** Each Story body **MUST** contain only:

   - **Title**: action-oriented, names the theme (e.g. "Authentication flow")
   - **Theme statement**: one sentence describing the coherent theme
   - **Parent reference**: pointer to the parent Epic (e.g. "Part of EPIC-N")
   - **Child Task references**: filled in during back-fill

   Stories **MUST NOT** carry a `## Design` heading or any design content. The skill **MUST** validate this before creating each Story per the Validation section in `skills/_shared/tickets.md`. If a drafted Story body contains a `## Design` heading, refuse to create it and surface the error to the user.

   **4b. Draft each Task.** Each Task **MUST** include:

   - **Title**: action-oriented, describes what the Task delivers
   - **Description**: what to build, the technical decisions from the design that are relevant to this Task, and any constraints
   - **Acceptance criteria**: three to five bullets per `skills/_shared/tickets.md`
   - **Dependencies**: explicit references to parent (Story or Epic) and any other Tasks that must exist before this work
   - **Labels**: based on work type (feature, infrastructure, testing, documentation), plus the tier marker (`tier:task`) per `skills/_shared/tickets.md`'s Tier Markers section, where the system uses labels for tier markers

5. **Order the tickets.** Present the tickets to the user in the implementation order required by `../../rules/common/workflow.md`: foundations and dependencies first, features next, integration after dependencies, polish last. When Stories are present, order Stories first by dependency, then Tasks within each Story by dependency.

6. **Create the epic, then the children.** Create in this order so each level can reference its parent:

   1. Create the **Epic** first.
   2. Create each **Story** next, attaching it to the Epic via the system's parent mechanism. Apply the tier marker per `skills/_shared/tickets.md`'s Tier Markers section.
   3. Create each **Task** next, attaching it to its parent (Story if grouped, Epic if flat). Apply the tier marker.

   Use the API appropriate to the detected system (see "Per-System Creation" below).

7. **Back-fill the epic body.** Once all child tickets exist and have real references (issue numbers, Jira keys, Linear IDs), update the epic body's `## Tickets` section with the actual references and links at all tiers.

   **Failure semantics.** If any Story or Task creation fails mid-run, the skill **MUST**:

   1. Stop further creation immediately.
   2. Back-fill the epic body with whatever children **did** get created, so the user can see the partial state.
   3. Report the failure to the user, citing the specific child that failed and its intended position in the hierarchy.
   4. Leave the partially-created tickets in place.

   The skill **MUST NOT** silently continue past a failure. The skill **MUST NOT** roll back successfully created tickets: rollback requires destructive operations against the ticketing system, which is out of scope and risky. The user decides whether to retry the failed child, fix the underlying issue and re-run, or abandon the partial state.

8. **Report to the user.** Summarise:

   - Number of tickets created at each tier (Epic, Stories if any, Tasks)
   - Links or references for each
   - Implementation order
   - Dependencies between tickets
   - Any system-specific degradations applied (e.g. Linear two-tier flattening, GitLab no-Epic mode, GitHub fallback to labelled flat)

   Then use {{ASK_USER_QUESTION_TOOL}} to ask whether they want to adjust anything (reorder, split, merge, relabel) before closing out.

## Per-System Creation

### GitHub Issues

With GitHub MCP tools (preferred):

1. Use `issue_write` to create the Epic, each Story (if any), and each Task. Apply tier labels at creation: `tier:epic`, `tier:story`, `tier:task` (use `get_label` and create labels if missing).
2. Use `sub_issue_write` to attach children to their parent. **Decision rule for nesting**, in order:
   1. Try Epic -> Story -> Task using two `sub_issue_write` calls (Story as sub-issue of Epic; Task as sub-issue of Story).
   2. If the second-level nest is rejected by the API, attach Tasks as sub-issues of the Story but reference the Epic via body text (`Epic: #<epic>`).
   3. If the first-level nest is also rejected, fall back to fully flat: Stories and Tasks are labelled siblings of the Epic, and parent references go in body text (`Part of #<story>, Epic: #<epic>`).
3. Tier labels are mandatory in **every** path.
4. Reference dependencies in the description: "Depends on #N".

With `gh` CLI (fallback):

```bash
gh issue create --title "..." --body "..." --label "tier:epic"
```

The `gh` CLI cannot create native sub-issue links, so parent references **MUST** go in the Task or Story body as text (`Part of #<parent>`, plus `Epic: #<epic>` for Tasks under Stories). Tier labels are still mandatory.

### Jira

With Atlassian MCP tools:

1. `getVisibleJiraProjects` to find the target project. If more than one is visible, use {{ASK_USER_QUESTION_TOOL}} to ask the user which.
2. `getJiraProjectIssueTypesMetadata` to confirm available issue types (Epic, Story, Task, Sub-task).
3. `createJiraIssue` for the Epic first, then each Story (if any), then each Task. The native issue type **is** the tier marker per `skills/_shared/tickets.md` (no separate label needed).
4. Use the native `epic` and `parent` fields to attach Stories to the Epic and Tasks to their parent Story or Epic.
5. `createIssueLink` for any cross-Task dependency links beyond the parent relationship.

### GitLab Issues

With GitLab MCP tools if available; otherwise use `glab`:

```bash
glab issue create --title "..." --description "..." --label "tier:epic"
```

If group **Epics** are available (premium GitLab), use the native group Epic for the top tier and create Stories and Tasks as Issues with `tier:story` and `tier:task` labels respectively. Stories link to the Epic via the native Epic-Issue association; Tasks link to their parent Story via "Part of #<story>" body text.

If group Epics are **not** available, the top tier becomes a labelled Issue (`tier:epic`) and the rest cascades the same way (Story is a labelled Issue with "Part of #<epic>", Task is a labelled Issue with "Part of #<story>, Epic: #<epic>"). The skill **MUST** warn the user explicitly via the report when degrading to no-Epic mode rather than silently flattening.

### Linear

With Linear MCP tools. Use {{ASK_USER_QUESTION_TOOL}} to ask the user for team and project context before creating issues; Linear requires these upfront.

Use Issue + sub-issue + sub-issue with `tier:epic` / `tier:story` / `tier:task` labels. **Do not** map Epic to Linear Project: Project is a different lifecycle concept and conflating it would break recovery.

If Linear's nesting caps at one level in practice, **degrade to two-tier in Linear**:

- Each Task carries `tier:task` and a slugified Story label `story:<slug>` where the slug is lowercase, hyphenated, ASCII, derived from the Story theme statement.
- The Story grouping is preserved in the epic body's `## Design` under `### Story: <name>`.
- Recovery in degraded Linear walks Task -> Epic in one hop and reads the Story theme from the epic body, using the `story:<slug>` label as the index.
- The skill **MUST** document the degradation in the Step 8 report to the user.

### Markdown Fallback

When `detect-ticketing-system` returns "none", write a structured Markdown file to the project root or a location the user specifies. Single file per Epic. Heading levels carry the tier markers per `skills/_shared/tickets.md` (`##` Epic, `###` Story, `####` Task).

```markdown
# <Epic Title>

## Goal

[one-paragraph summary]

## Design

[The full approved design, the same content that would go in an epic body]

### Story: <name>            <!-- only if Stories are introduced -->

[one-sentence rationale, see "When to introduce the Story tier"]

## Tickets

### Story: <name>            <!-- only if Stories are introduced -->

Theme: [one-sentence theme statement]

#### Task: <title>

**Type:** feature | infrastructure | testing
**Dependencies:** none | Task N

**Description:**
...

**Acceptance Criteria:**
- [ ] ...
- [ ] ...
- [ ] ...
```

When no Stories are introduced, `## Tickets` contains `#### Task:` entries directly. The Task heading level is invariant at `####` in both flat and grouped modes, so the heading level remains a stable tier marker for the `resolve_epic_context` walker.

The file becomes the epic equivalent; `work-on-ticket` can read it directly when the user references a Task and the heading-level tier marker is the discriminator for the `resolve_epic_context` walker.

## Closing the Loop

After reporting, remind the user: "To pick up any of these tickets in a new session, reference it (for example, 'work on #42') and the `work-on-ticket` skill will fetch the ticket, run `resolve_epic_context` to recover the design from the parent Epic, and start implementation."
