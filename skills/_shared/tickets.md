# Tickets

**Load model**: this file is **not** always in context. It lives next to the ticket skills and is loaded on demand when `create-tickets`, `work-on-ticket`, or `detect-ticketing-system` is invoked. The rules here apply to any workflow that creates tickets from a design or picks up tickets for implementation, regardless of the ticketing system in use (GitHub Issues, Jira, GitLab, Linear, or a Markdown fallback).

## Epic Design Embedding

When a design is broken into multiple tickets, there **MUST** be an epic or parent ticket, and the epic body **MUST** contain the full approved design under a `## Design` heading. The design section is the bridge between the brainstorming session and every future implementation session that picks up a child ticket.

The epic body **MUST** include, at minimum:

- The architecture and key components
- The interfaces and data flow
- Technical decisions and the trade-offs behind them
- The error handling approach
- The testing strategy
- Anything else that emerged from the design conversation and affects how the children should be built

## Single Source of Truth

The epic body **MUST** be the single source of truth for the design. You **MUST NOT** replace the design section with a link to an external file, a conversation transcript, a gist, a commit, or any other artefact outside the ticketing system. Links rot, external context disappears, and future sessions will open the epic and find nothing usable.

If the epic is too large for the ticketing system's body limit, split the design across multiple headings in the same body, not across multiple documents.

## Recovery Before Implementation

When picking up a ticket for implementation, you **MUST** fetch the parent epic and extract its `## Design` section before any implementation step. Implementing a ticket without the epic's design context is forbidden: per `workflow.md`, implementation requires an approved design, and the epic's design section is the approved design in this workflow.

If the epic has no `## Design` section (for example, because the tickets were created manually or by an older workflow), you **MUST**:

1. Read whatever context is in the epic body
2. Read sibling tickets to understand scope boundaries
3. Present what you have to the human partner and ask whether they can provide additional context before proceeding

You **MUST NOT** guess the design and proceed.

## Ticket Sizing

Each ticket **MUST** be achievable in a single focused session. Each ticket's acceptance criteria **MUST** fit in three to five bullet points. If you cannot describe the acceptance criteria in that budget, the ticket is too large and **MUST** be split before creation.

## Ordering

The implementation order of tickets follows the sequencing rule in `workflow.md`: foundations and dependencies first, features next, integration after dependencies, polish last. You **MUST NOT** reorder tickets to make progress look faster or to avoid a harder ticket.

## Procedures

- To detect the ticketing system in use, invoke the `detect-ticketing-system` skill.
- To turn an approved design into tickets, invoke the `create-tickets` skill.
- To pick up an existing ticket for implementation, invoke the `work-on-ticket` skill.

All three skills cite this file. The rules here apply whether or not the skills have been invoked.
