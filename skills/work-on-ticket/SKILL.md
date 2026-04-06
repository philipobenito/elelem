---
name: work-on-ticket
description: Picks up a ticket from the project's ticketing system, fetches its parent epic, recovers the embedded design context, presents the scope to the user for confirmation, and hands off to subagent-driven-development with the recovered design as the approved input. The re-entry point for work planned in a previous session via brainstorming and create-tickets.
---

# Work on Ticket

## Load the Ticketing Rules First

This skill depends on the rules in `skills/_shared/tickets.md`. Those rules are **not** always in context; they live next to the ticket skills and are loaded only when a ticket skill is invoked. Before running the procedure below, you **MUST** read `skills/_shared/tickets.md` using the {{READ_FILE_TOOL}} tool if you have not already read it in this session.

The detection of which ticketing system is in use lives in the `detect-ticketing-system` skill. The downstream implementation workflow lives in the `subagent-driven-development` skill. This skill bridges the gap across session boundaries between a ticket that was created in a prior session and the implementation workflow that delivers it.

**Precondition**: the user has referenced a specific ticket to work on (for example, "work on #42", "pick up PROJ-123", "implement issue 7"). Without a specific reference, this skill does not apply; if the user is asking what to work on next, that is a triage question, not this skill.

## Procedure

You **MUST** complete these steps in order. Do not skip a step and do not reorder them.

1. **Detect the ticketing system.** Invoke the `detect-ticketing-system` skill to identify where the ticket lives.

2. **Fetch the ticket.** Retrieve its full content: title, description, labels, status, parent or epic relationship, child or sub-issue references, and linked tickets. See "Per-system fetch" below for the specific API calls.

3. **Run `resolve_epic_context`.** Per `skills/_shared/tickets.md`, this is the named procedure that walks from the fetched ticket up to its Epic and recovers the approved design. The procedure is tier-marker-driven: it reads each node's tier marker (Jira issue type, `tier:epic`/`tier:story`/`tier:task` label, or markdown heading level depending on the system), walks at most 2 hops, and terminates at the Epic. See `skills/_shared/tickets.md` "Recovery Before Implementation" for the full procedure, the termination rule, the legacy fallback boundary, and the decision tree.

   The walker **MUST**:
   - Identify the ticket's tier marker.
   - Walk to the Epic in at most 2 hops (Task -> Story -> Epic, or Task -> Epic for the legacy two-tier path).
   - Treat any `## Design` heading found in a Story body as a single-source-of-truth violation (an error, not preferred content).
   - Surface the **specific reference that could not be resolved** on any failure (missing parent, no Epic found, cycle, depth exceeded). Do not silently continue with partial context.
   - Apply the legacy fallback only when a node has no tier marker AND no further parent reference, per `skills/_shared/tickets.md`.

4. **Extract the design.** `resolve_epic_context` returns the Epic and (if walked through one) the Story's theme statement. Extract the Epic body's `## Design` section. This becomes the approved design input for the implementation workflow.

   If `resolve_epic_context` succeeds but the resolved Epic has **no** `## Design` section at all (tickets created manually or by an older workflow predating the rule), follow the manual fallback in `skills/_shared/tickets.md`: read whatever context is in the epic body, read sibling tickets to understand scope boundaries, present what you have to the user, and ask whether they can supply additional context before proceeding. You **MUST NOT** guess the design and proceed.

   If `resolve_epic_context` fails (any error condition above), surface the specific failure to the user and stop. You **MUST NOT** proceed to implementation with partial context.

5. **Explore the codebase.** Read the current state of files relevant to the ticket. Note anything that has changed since the design was written, anything already partially implemented, and anything the design assumes but does not actually exist yet.

6. **Present the scope.** Show the user a structured summary before asking for confirmation:

   - **Ticket**: title and reference
   - **Design context** (from epic): the recovered design section, or a note that none was found
   - **This ticket's scope**:
     - What to build (from the ticket description)
     - Acceptance criteria (from the ticket)
     - Dependencies (from linked tickets, what must exist before this work)
     - What is explicitly out of scope (from sibling tickets, things that belong to other tickets)
   - **Current codebase state**: relevant observations from step 5

7. **Get explicit user confirmation.** Use `{{ASK_USER_QUESTION_TOOL}}` to confirm scope. Plain-text confirmation is not sufficient.

   ```
   {{ASK_USER_QUESTION_TOOL}}:
     question: "Does this scope look right for implementation?"
     header: "Scope"
     options:
       - label: "Looks good, proceed"
         description: "The scope, design context, and acceptance criteria are correct. Start implementation."
       - label: "Adjust scope"
         description: "Something needs changing before implementation begins."
       - label: "Need more context"
         description: "Fetch additional tickets or explore the codebase further before deciding."
     multiSelect: false
   ```

   If the user selects "Adjust scope" or "Need more context", address the feedback and re-present with `{{ASK_USER_QUESTION_TOOL}}` again. Only proceed to step 8 after "Looks good, proceed".

8. **Hand off to subagent-driven-development.** Use `{{INVOKE_SKILL_TOOL}}` to invoke the `subagent-driven-development` skill. This **MUST** be an actual skill invocation, not a conceptual handoff; if you skip the invocation, the downstream skill's full instructions will not be loaded and implementation quality will suffer.

   ```
   {{INVOKE_SKILL_TOOL}}:
     skill: "subagent-driven-development"
   ```

   Before invoking, construct the approved design input by combining:

   1. The design context recovered from the epic (the architectural vision)
   2. The ticket scope (what specifically this ticket delivers)
   3. The acceptance criteria from the ticket (the spec that the spec reviewer will check against)
   4. Codebase observations from step 5

## Per-System Fetch

The fetch step is per-system, but the tier marker is read uniformly per `skills/_shared/tickets.md`'s Tier Markers section. For each system, fetching the ticket also retrieves enough metadata (issue type, labels, or heading level) for `resolve_epic_context` to identify the tier without an extra round trip.

### GitHub Issues

With GitHub MCP tools: `issue_read` with the issue number. Response includes body, labels, and parent or sub-issue relationship fields. The tier marker is the `tier:epic` / `tier:story` / `tier:task` label.

With `gh` CLI:

```bash
gh issue view <number> --json title,body,labels,milestone,projectItems
```

Read the `tier:*` label from the labels array.

### Jira

With Atlassian MCP tools: `getJiraIssue` with the issue key. Response includes the `parent` and `epic` fields natively. The tier marker is the native issue type (Epic, Story, Task, or Sub-task) returned in the issue payload.

### GitLab Issues

With GitLab MCP tools if available; otherwise:

```bash
glab issue view <number>
```

The tier marker is either the native group Epic association (top tier on premium GitLab) or the `tier:*` label.

### Linear

With Linear MCP tools. Response includes the `parent` field. The tier marker is the `tier:epic` / `tier:story` / `tier:task` label. In a workspace where Linear nesting is degraded to two-tier (per `create-tickets/SKILL.md`), the Story tier is recorded only as a `story:<slug>` label on the Task and reconstructed from the epic body during `resolve_epic_context`; the walker treats such Tasks as direct children of the Epic.

## Finding the Parent

`resolve_epic_context` finds parents using the system's native parent mechanism, not by inspecting body text where a native mechanism exists. The mechanisms by system are:

- **GitHub Issues**: `issue_read` returns a parent issue reference if one exists. For tickets created via the `gh` CLI fallback (or for legacy tickets), scan the body for `Part of #N` and `Epic: #N` references.
- **Jira**: the `parent` or `epic` field on `getJiraIssue`. Jira natively supports Epic-Story and Story-Sub-task relationships.
- **Linear**: the `parent` field on the issue.
- **GitLab**: epic associations (where group Epics are available) or `Part of #N` references in the body (where they are not).
- **Markdown fallback**: heading nesting in the single epic file. A Task's parent is the nearest preceding `### Story:` heading, or the file itself (the Epic) when there is no enclosing Story.

If `resolve_epic_context` cannot resolve a parent reference (the ticket is missing, deleted, or permission is denied), this is an **error**. Surface the unresolved reference to the user via `{{ASK_USER_QUESTION_TOOL}}` and stop. The legacy fallback documented in `skills/_shared/tickets.md` applies only when a node has no parent reference at all, not when a parent reference exists but cannot be fetched.

## Handling Multiple Tickets

If the user wants to work on multiple tickets, work on them one at a time in dependency order per `../../rules/common/workflow.md`. Complete one ticket through the full `subagent-driven-development` cycle (including reviews) before starting the next. If the user wants genuinely parallel work, suggest separate sessions rather than trying to parallelise in one.

## Edge Cases

- **Ticket already partially implemented**: read git history and current code state, present what exists to the user, and adjust the scope to cover only the remaining work before step 7.
- **Ticket depends on unfinished work**: flag the dependency. Ask the user whether to work on the dependency first or to proceed with stubs or interfaces for the missing pieces.
- **Ticket description is vague**: use the epic's design context to fill in gaps. If still unclear after that, ask the user targeted questions before proceeding. You **MUST NOT** guess at requirements.
- **No ticketing system detected**: if the user provides a ticket reference but `detect-ticketing-system` returns "none", ask the user to paste the ticket content (and the parent epic content if applicable) directly, then run `resolve_epic_context` against the pasted content using markdown heading levels as the tier marker.
