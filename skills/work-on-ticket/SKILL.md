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

3. **Fetch the parent epic.** Every ticket created via `create-tickets` has a parent epic whose body carries the design. Use the parent reference from step 2 to fetch it. See "Finding the parent" below.

4. **Recover the design context.** Per `skills/_shared/tickets.md`, the epic body **MUST** contain the approved design under a `## Design` heading. Extract that section. This becomes the approved design input for the implementation workflow.

   If the epic has no `## Design` section (tickets created manually or by an older workflow), follow the fallback in `skills/_shared/tickets.md`: read the epic body for whatever context is available, read sibling tickets for scope boundaries, present what you have to the user, and ask whether they can supply additional context before proceeding. You **MUST NOT** guess the design and proceed.

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

### GitHub Issues

With GitHub MCP tools: `issue_read` with the issue number. Response includes body, labels, and sub-issue or parent relationship fields.

With `gh` CLI:

```bash
gh issue view <number> --json title,body,labels,milestone,projectItems
```

### Jira

With Atlassian MCP tools: `getJiraIssue` with the issue key. Response includes the `parent` and `epic` fields natively.

### GitLab Issues

With GitLab MCP tools if available; otherwise:

```bash
glab issue view <number>
```

### Linear

With Linear MCP tools. Response includes the `parent` field.

## Finding the Parent

The parent relationship varies by system:

- **GitHub Issues**: `issue_read` returns a parent issue reference if one exists. Also scan the body for "Part of #N" or "Epic: #N" references, which are used when the `gh` CLI fallback created the ticket.
- **Jira**: the `parent` or `epic` field on `getJiraIssue`. Jira natively supports epic-to-story relationships.
- **Linear**: the `parent` field on the issue.
- **GitLab**: epic associations or "Part of #N" references in the body.

If no parent can be found, the ticket is either a standalone issue or was created outside the `create-tickets` workflow. In both cases you **MUST** ask the user whether a parent exists under a different reference before falling back to treating the ticket as standalone.

## Handling Multiple Tickets

If the user wants to work on multiple tickets, work on them one at a time in dependency order per `../../rules/common/workflow.md`. Complete one ticket through the full `subagent-driven-development` cycle (including reviews) before starting the next. If the user wants genuinely parallel work, suggest separate sessions rather than trying to parallelise in one.

## Edge Cases

- **Ticket already partially implemented**: read git history and current code state, present what exists to the user, and adjust the scope to cover only the remaining work before step 7.
- **Ticket depends on unfinished work**: flag the dependency. Ask the user whether to work on the dependency first or to proceed with stubs or interfaces for the missing pieces.
- **Ticket description is vague**: use the epic's design context to fill in gaps. If still unclear after that, ask the user targeted questions before proceeding. You **MUST NOT** guess at requirements.
- **No ticketing system detected**: if the user provides a ticket reference but `detect-ticketing-system` returns "none", ask the user to paste the ticket content (and the parent epic content if applicable) directly, then proceed from step 4 with the pasted content.
