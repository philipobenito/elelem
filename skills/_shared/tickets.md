# Tickets

**Load model**: this file is **not** always in context. It lives next to the ticket skills and is loaded on demand when `create-tickets`, `work-on-ticket`, or `detect-ticketing-system` is invoked. The rules here apply to any workflow that creates tickets from a design or picks up tickets for implementation, regardless of the ticketing system in use (GitHub Issues, Jira, GitLab, Linear, or a Markdown fallback).

## Hierarchy Model

The hierarchy is fixed three-tier: **Epic / Story / Task**.

- **Epic**: the parent. Carries the full approved design under `## Design`. Every multi-ticket decomposition has exactly one Epic.
- **Story** (optional): groups related Tasks under a coherent named theme. Stories carry a one-sentence theme statement and a list of child Task references. They **MUST NOT** carry a `## Design` heading or any design content. Most epics do not need Stories.
- **Task**: the unit of implementation work. Carries acceptance criteria and is sized to one focused session.

There is no fourth Sub-task tier. If finer decomposition is needed inside a Task, use a checklist inside the Task body. Checklists are not tickets and are not recovered by `work-on-ticket`.

The Story tier is introduced by `create-tickets` only when the decomposition rule (in `create-tickets/SKILL.md`) is satisfied. Most epics stay two-tier (Epic plus flat Tasks), and that remains the default shape.

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

Stories **MUST NOT** carry a `## Design` heading or any design content. The epic body is the only place the design lives. A Story body that contains a `## Design` heading is a single-source-of-truth violation and is an error in both creation (rejected before the Story is created) and recovery (surfaced to the user). See "Validation" below.

## Tier Markers

Every ticket created from a design carries a tier marker so recovery does not need to inspect bodies or guess from link topology. The marker mechanism varies by system:

| System   | Tier marker mechanism                                            |
|----------|------------------------------------------------------------------|
| Jira     | Native issue type (Epic, Story, Task or Sub-task)                |
| GitHub   | Label: `tier:epic` / `tier:story` / `tier:task`                  |
| Linear   | Label: `tier:epic` / `tier:story` / `tier:task`                  |
| GitLab   | Native group Epic where available, otherwise label as for GitHub |
| Markdown | Heading level: `##` Epic, `###` Story, `####` Task               |

Tier markers are mandatory on every ticket the `create-tickets` skill produces. They are the primary discriminator used by `resolve_epic_context` (see "Recovery Before Implementation").

## Recovery Before Implementation

When picking up a ticket for implementation, you **MUST** run the `resolve_epic_context` procedure to recover the approved design before any implementation step. Implementing a ticket without the epic's design context is forbidden: per `../../rules/common/workflow.md`, implementation requires an approved design, and the epic's design section is the approved design in this workflow.

### `resolve_epic_context` procedure

1. Fetch the ticket. Read its tier marker.
2. If the ticket's tier is **Task**, fetch its parent and read the parent's tier marker.
   - If the parent's tier is **Story**, read the Story body for the theme statement (useful context, not the design), then fetch the Story's parent. Verify the grandparent's tier is **Epic**, and extract `## Design` from the Epic body.
   - If the parent's tier is **Epic**, extract `## Design` from the Epic body. Recovery completes in one hop. This is the legacy two-tier path.
3. If the ticket's tier is **Story**, fetch its parent (which **MUST** be an Epic), extract `## Design` from the Epic, plus the Story's own theme statement.
4. If the ticket's tier is **Epic**, extract `## Design` from its own body directly.

### Termination rule

A node is treated as the Epic when **either** of the following holds:

- It carries an explicit Epic tier marker (label `tier:epic`, native Jira Epic issue type, or markdown `##` heading level for the Epic), or
- (Legacy fallback) it has **no tier marker AND its body contains a `## Design` heading AND it has no resolvable parent reference**. All three conditions are required.

The walker **MUST NOT** read or use any `## Design` heading found in a Story body. If such a heading exists, it is a single-source-of-truth violation and recovery surfaces it as an error.

### Legacy fallback boundary

The legacy fallback applies **only** when a node has no tier marker AND no further parent reference. If a no-tier-marker node has a parent, the walker **MUST** continue walking and **MUST NOT** treat the no-tier-marker node as an Epic. Reaching a node with no tier marker, no `## Design` heading, and no parent is also an error.

If a parent reference cannot be resolved (the ticket was deleted, or permission is denied), this is an error, not a fallback trigger. Surface the unresolved reference to the user.

### Hard caps and guards

- **Maximum walk depth**: 2 hops. Exceeding this is an error.
- **Cycle guard**: track visited references; a cycle indicates malformed data and is an error. With the 2-hop cap, cycles are structurally rare; the guard exists for malformed input, not for depth.
- **Ambiguity guard**: if the legacy fallback finds more than one candidate with `## Design` along the walk, surface the ambiguity to the user.
- On any failure (missing parent, no Epic found, cycle, depth exceeded, design heading in a Story body), surface the **specific reference that could not be resolved** to the user. Do not silently continue with partial context.

### Decision tree

| Node state                                          | Result                                      |
|-----------------------------------------------------|---------------------------------------------|
| Explicit Epic tier marker                           | Treat as Epic. Extract `## Design`.         |
| Explicit Story tier marker, parent resolves to Epic | Read theme statement, walk one hop to Epic. |
| Explicit Story tier marker, parent does not resolve | Error: surface unresolved parent.           |
| No tier marker, body has `## Design`, no parent     | Treat as Epic (legacy fallback).            |
| No tier marker, body has `## Design`, has parent    | Keep walking. **Do not** treat as Epic.     |
| No tier marker, no `## Design`, no parent           | Error: cannot recover design.               |
| Any node with `## Design` in a Story body           | Error: single-source-of-truth violation.    |

**Tiebreaker.** An explicit Epic tier marker always wins over a legacy-fallback `## Design` candidate. If the walk passes through a no-marker node with `## Design` and a parent (per the "keep walking" row above), and then reaches an explicit Epic marker, the explicit marker is the Epic. The intermediate `## Design` is ignored and is not treated as an ambiguity error. Ambiguity only triggers when the legacy fallback finds two or more candidates AND no explicit marker resolves the walk.

If the recovered Epic has no `## Design` section at all (for example, because the tickets were created manually or by an older workflow that predates this rule), follow the manual fallback: read whatever context is in the epic body, read sibling tickets to understand scope boundaries, present what you have to the human partner, and ask whether they can provide additional context before proceeding. You **MUST NOT** guess the design and proceed.

## Ticket Sizing

Each ticket **MUST** be sized appropriately for its tier:

- **Epic**: no acceptance criteria. The body **MUST** contain `## Design`.
- **Story**: no acceptance criteria. A Story's "done" state is **computed** from child Task status and **MUST NOT** be authored. Reviewers **MUST NOT** look for an AC block on a Story. A Story **MUST** contain between 2 and 6 child Tasks. If a Story would need more than 6 Tasks, split the Story or escalate to the user before creation.
- **Task**: each Task **MUST** be achievable in a single focused session. Acceptance criteria **MUST** fit in three to five bullet points. If you cannot describe the acceptance criteria in that budget, the Task is too large and **MUST** be split before creation.

## Validation

The following conditions are validation errors and **MUST** be enforced by `create-tickets` (at creation time) and surfaced by `work-on-ticket` (at recovery time):

- A Story body containing a `## Design` heading. This is a single-source-of-truth violation. At creation, the skill **MUST** reject the Story before sending it to the ticketing system. At recovery, the walker **MUST** surface the violation to the user rather than reading the Story's design content.
- A Story containing fewer than 2 or more than 6 child Tasks. The decomposition step **MUST** split or escalate before creation.
- A single-Story epic (one Story wrapping every Task). This is forbidden because a single Story adds a grouping layer with no sibling. The decomposition rule in `create-tickets/SKILL.md` prevents this; if it occurs, treat as a creation-time error.

## Ordering

The implementation order of tickets follows the sequencing rule in `../../rules/common/workflow.md`: foundations and dependencies first, features next, integration after dependencies, polish last. You **MUST NOT** reorder tickets to make progress look faster or to avoid a harder ticket.

## Procedures

- To detect the ticketing system in use, invoke the `detect-ticketing-system` skill.
- To turn an approved design into tickets, invoke the `create-tickets` skill.
- To pick up an existing ticket for implementation, invoke the `work-on-ticket` skill.

All three skills cite this file. The rules here apply whether or not the skills have been invoked.
