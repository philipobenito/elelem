---
name: create-tickets
description: Turns an approved design into tickets under a single parent epic whose body carries the full design, so a future session can recover it. Invoked by the brainstorming mode skills once a design is approved, and whenever the user asks to create tickets, file issues, break a plan or design into tickets, or set up a backlog. Handles GitHub Issues, Jira, GitLab and Linear, and falls back to a structured Markdown document when no ticketing system is available.
---

# Create Tickets

## Load the Ticketing Rules First

This skill depends on the rules in `../_shared/tickets.md`. Those rules are **not** always in
context; they live next to the ticket skills and load only when a ticket skill is invoked.
Before running the procedure below, read `../_shared/tickets.md` using the Read tool if you have
not already read it in this session.

Detection of which ticketing system is in use lives in the `detect-ticketing-system` skill. This
skill is the procedure that decomposes an approved design into tickets and creates them.

## Preconditions

An approved design must already exist in conversation context. "Approved" means one of the forms
listed under "What Counts as an Approved Design" in `../../rules/common/workflow.md`: a design
produced by the `brainstorming` router and explicitly approved, an epic or ticket the user wrote
or previously approved, or a specification committed to the repository and pointed to as the
source of truth.

A design you have inferred from the request, or one the user has seen but not approved, does not
qualify. If there is no approved design, stop and surface that rather than inventing one, and do
not invoke `brainstorming` on the user's behalf: which mode to use is the user's choice, per the
router's own rules.

## Procedure

1. **Detect the ticketing system.** Invoke the `detect-ticketing-system` skill. This skill is
   that skill's caller, so confirming the result is this skill's job and does not pass further
   up the chain.

   | Result             | Action                                                                                                                                     |
   |--------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
   | Exactly one system | Carry it forward. Its confirmation rides along with the step 5 gate rather than costing a separate question.                               |
   | More than one      | Resolve now with `AskUserQuestion`. Drafting does not depend on the answer, but creation does, and asking later means asking mid-creation. |
   | None               | Tell the user the output will be a structured Markdown file instead of tickets, then carry on. The shape of what you draft changes.        |

2. **Decompose the design into ticket shapes.** Map design elements to ticket types:

   | Design Element                                | Ticket Type                          |
   |-----------------------------------------------|--------------------------------------|
   | Overall goal plus full design                 | Epic                                 |
   | Coherent named theme grouping related Tasks   | Story, per The Story Tier Rule below |
   | Independent component                         | Task                                 |
   | Cross-cutting concern (auth, logging, config) | Task                                 |
   | Integration between components                | Task, depends on the component Tasks |

   Per `../_shared/tickets.md`, each Task must fit in a single focused session with acceptance
   criteria in three to five bullets. If a component does not fit, split it before creation.

3. **Draft the epic body.** Per `../_shared/tickets.md`, the epic body is the single source of
   truth and must contain the full approved design under a `## Design` heading:

   ```markdown
   ## Goal

   [One-paragraph summary of what this epic delivers]

   ## Design

   [The full approved design, including architecture, key components, interfaces, data flow,
    technical decisions and trade-offs, error handling, testing strategy, and anything else
    that emerged from the design conversation]

   ### Story: <name>

   [One-sentence rationale for this grouping. Only when Stories are introduced. This
    sub-heading belongs to the `## Design` block, not as a peer section.]

   ## Tickets

   - [Story or Task title] - [reference once created]
   ```

   List loose Tasks first in the `## Tickets` index, then each Story with its Tasks, so the
   index reads in the implementation order established at step 5.

   The `## Tickets` block is a human-readable index; the real parent-child relationships live in
   the ticketing system's native links. The Markdown fallback uses a different shape, described
   in `per-system-creation.md`.

   Do not replace the `## Design` section with a link to an external file, a transcript, or a
   commit. Links rot and external context disappears, so a future session opens the epic and
   finds nothing it can build from.

4. **Draft each child ticket.**

   **4a. Each Story** (only when Stories are introduced) carries a title naming the theme, a
   one-sentence theme statement, a parent reference to the Epic, and its child Task references
   once they exist. Nothing else.

   A Story must not carry a `## Design` heading or any design content, and you must check this
   before creating it. A second copy of the design diverges from the epic's copy the moment
   either is edited, and recovery has no way to tell which one is authoritative. If a drafted
   Story body contains a `## Design` heading, refuse to create it and surface the error.

   **4b. Each Task** carries:

   - **Title**: action-oriented, describing what the Task delivers
   - **Description**: what to build, the technical decisions from the design relevant to this
     Task, and any constraints
   - **Acceptance criteria**: three to five bullets, per `../_shared/tickets.md`
   - **Dependencies**: its parent (Story or Epic) and any Tasks that must exist before this work
   - **Labels**: work type (feature, infrastructure, testing, documentation) plus the tier
     marker, where the system uses labels for tier markers

5. **Order the tickets and get approval before creating anything.** Order per
   `../../rules/common/workflow.md`: foundations and dependencies first, features next,
   integration after dependencies, polish last. In practice that puts loose Tasks (typically
   cross-cutting concerns) ahead of the Stories, then Stories by dependency, then Tasks within
   each Story by dependency.

   Present the full set to the user, then ask:

   ```
   AskUserQuestion:
     question: "Create these tickets in <detected system>?"
     header: "Create"
     options:
       - label: "Create them"
         description: "The decomposition, order, and target system are right. Go ahead."
       - label: "Adjust first"
         description: "Something needs reordering, splitting, merging, or relabelling."
       - label: "Change target"
         description: "Create these somewhere other than <detected system>."
     multiSelect: false
   ```

   This gate is the only cheap moment in the procedure. Creating tickets writes to a system
   outside this repository, and step 7 forbids rolling them back, so reordering, splitting and
   merging are free here and expensive or impossible afterwards. Do not create anything before
   the user picks "Create them".

6. **Create the epic, then the children**, in this order so each level can reference its parent:

   1. The **Epic**.
   2. Each **Story**, attached to the Epic via the system's parent mechanism.
   3. Each **Task**, attached to its parent (its Story if grouped, the Epic if loose), created
      in **global topological order of dependencies** rather than grouped by Story. A Task whose
      body says `Depends on #N` needs `#N` to already have an identifier, and dependencies cross
      Story boundaries, so ordering within a Story is not enough.

   If the dependency graph contains a cycle, no valid creation order exists. That is a
   decomposition error rather than a creation error: surface it and return to step 2.

   Apply the tier marker at every tier. Use the API for the detected system, in
   `per-system-creation.md`.

7. **Back-fill the epic body.** Once the children exist and have real references, update the
   epic body's `## Tickets` index with the actual references and links at all tiers.

   **Failure semantics.**

   | Failure                      | Response                                                                                                                                                                                     |
   |------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
   | Epic creation fails          | Nothing exists yet. Report and stop.                                                                                                                                                         |
   | Story or Task creation fails | Stop creating immediately. Back-fill the epic with whatever children did get created, report the specific child that failed and its intended position, and leave the partial state in place. |
   | Back-fill itself fails       | Not fatal. Native parent links already carry recovery and the index is a human convenience. Report the stale index and continue to step 8.                                                   |

   Do not silently continue past a creation failure, and do not roll back tickets that were
   created successfully. Rollback means destructive operations against the ticketing system,
   which is out of scope and risky; the user decides whether to retry the failed child, fix the
   cause and re-run, or keep the partial state.

8. **Report to the user.** Summarise the number of tickets created at each tier, the references
   and links for each, the implementation order, the dependencies between them, any
   system-specific degradation applied (Linear two-tier flattening, GitLab no-Epic mode, GitHub
   fallback to labelled flat), and any failure from step 7.

   This is a report, not a question. The point at which the user could still change the shape
   was step 5.

## The Story Tier Rule

Introduce Stories when **at least 2 themes each hold 2 or more Tasks**. Every other Task attaches
directly to the Epic.

That one condition carries the whole rule. Two qualifying themes cannot exist without there
being two themes, and two themes at two Tasks each is already four Tasks, so the count and theme
minimums that would otherwise need stating are consequences rather than separate tests.

It also makes the single-Story epic that `../_shared/tickets.md` forbids **structurally
unreachable**: satisfying the condition produces at least two Stories by construction. The
validation error stays in `../_shared/tickets.md` to catch hand-authored tickets, but this
procedure has no check to run for a shape it cannot produce.

**Mixed epics are the normal case, not a degradation.** An Epic may hold Stories and loose Tasks
side by side. The decomposition table above already implies this by mapping cross-cutting
concerns to a bare Task, and those concerns are exactly the themes that yield one Task. Recovery
costs nothing: `../_shared/tickets.md` makes the Task-to-Epic hop a first-class path, so a loose
Task resolves in one hop. Do not pad a one-Task theme into a Story to make the epic look
uniform; Stories hold 2 to 6 Tasks, and a loose Task is the designed shape.

**A theme holding more than 6 Tasks must be split** into coherent sub-themes before creation, or
escalated to the user via `AskUserQuestion` if it will not split. This is the Story sizing cap in
`../_shared/tickets.md` and it is not negotiable, because a Story wide enough to lose track of is
the grouping failing at the one job it has.

That cap applies to Stories. A **flat** epic has no cap, since there is no Story to oversize.
Single-theme epics stay flat regardless of Task count. If a flat epic grows past roughly 6 Tasks,
it is worth asking the user whether to split it into multiple epics, but that is an ergonomics
prompt about epic size rather than a rule, and the answer is theirs.

## Per-System Creation

The creation calls for each system, and the Markdown fallback file format, live in
`per-system-creation.md`. Read the section for the system resolved at step 1 and skip the rest.

## Return Contract

This section is addressed to whichever skill or user invoked this one. It lives here rather than
in each caller because invoking this skill is what loads the file, so the text arrives at the
moment it is needed.

**Tickets created.** This skill is terminal. Report and stop. Do **not** invoke an orchestration
skill directly. Implementation from a ticket enters through `work-on-ticket`, which recovers the
epic's design, reads the current state of the code, and confirms scope before any work starts.
Those checks matter even one minute after creation, because the design was approved against the
codebase as it was read, not as it is. If the user wants to begin immediately, invoke
`work-on-ticket` against the first ticket in the order.

**Partial creation.** The user receives the named failure and the partial state. Do not proceed
to implementation against a partial tree: the tickets that failed are the ones whose absence the
remaining work would silently assume.

**No approved design.** Stop and surface it. Do not invent a design, and do not invoke
`brainstorming` on the user's behalf.

**Markdown fallback.** As for tickets created, except the artefact is a file. `work-on-ticket`
handles pickup through its no-system branch.

## Completion Gate

Do not report tickets as created until **all** of these hold:

- An approved design existed, in one of the forms listed in `../../rules/common/workflow.md`
- The user approved the ticket set at step 5
- Every ticket in the approved set was created, or the failure was reported per step 7
- The epic body contains `## Design`, and no Story body does
- Every created ticket carries a tier marker

Per `../../rules/common/verification.md`, "created" is a completion claim and needs the actual
API responses or the file on disk as evidence. Having sent the calls is not the same as having
read what came back.

## Worked Example: The Story Tier Fires

A design for an export feature decomposes into eight Tasks across three themes: authentication
(3 Tasks), the export pipeline (4 Tasks), and configuration (1 Task).

Two themes hold 2 or more Tasks, so Stories are introduced. Configuration holds one Task, so that
Task attaches directly to the Epic rather than becoming a one-Task Story.

```
Epic: Add customer data export
  Task: Add export configuration schema        (loose, cross-cutting, no Story)
  Story: Authentication flow
    Task: Add export scope to token claims
    Task: Add scope check middleware
    Task: Add scope denial audit logging
  Story: Export pipeline
    Task: Add record streaming reader
    Task: Add CSV writer
    Task: Add JSON writer
    Task: Add pipeline integration test
```

The configuration Task is created first: it is a foundation the others depend on, and
`../../rules/common/workflow.md` puts foundations first. Its identifier therefore exists before
any Task that declares `Depends on` against it.

## Worked Example: The Story Tier Does Not Fire

The same skill, a different design: five Tasks, all within one theme (migrating handlers to
structured logging).

One theme cannot satisfy a condition requiring two, so the epic stays flat: Epic plus five Tasks,
no Stories. Five Tasks is not near enough to the flat-epic ergonomics prompt to be worth raising
with the user.

The tempting error here is wrapping all five in a "Structured logging" Story to make the epic
look organised. That produces the single-Story epic `../_shared/tickets.md` forbids: a grouping
layer with no sibling to be grouped against, adding a hop to every recovery walk and telling the
reader nothing the epic title did not.

## Common Mistakes

| Mistake                                              | Why it is wrong                                                                                                                                        |
|------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| Creating tickets before the step 5 gate              | Creation writes outside this repository and step 7 forbids rollback. Step 8 cannot undo what step 6 did.                                               |
| Leaving the system confirmation to "the caller"      | This skill **is** the caller of `detect-ticketing-system`. The obligation stops here, and a chain where each end points at the other confirms nothing. |
| Padding a one-Task theme into a Story                | Stories hold 2 to 6 Tasks. A loose Task is the designed shape, not a failure to group.                                                                 |
| Wrapping every Task in a single Story                | The Story Tier Rule makes this unreachable, so arriving at it means the rule was not applied.                                                          |
| Copying the design into a Story body                 | Two copies diverge on the first edit and recovery cannot tell which is authoritative.                                                                  |
| Creating Tasks in presentation order                 | A `Depends on #N` reference needs `#N` to exist. Dependencies cross Story boundaries, so only a global topological order is safe.                      |
| Treating a failed back-fill as fatal                 | Native parent links already carry recovery. The index is a convenience, and abandoning a correct ticket tree over it helps nobody.                     |
| Handing off to an orchestration skill after creating | Implementation from a ticket enters through `work-on-ticket`, which confirms scope against the code as it is now.                                      |

## Closing the Loop

After reporting, remind the user: "To pick up any of these tickets in a new session, reference it
(for example, 'work on #42') and the `work-on-ticket` skill will fetch the ticket, run
`resolve_epic_context` to recover the design from the parent Epic, and start implementation."
