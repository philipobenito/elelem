---
name: work-on-ticket
description: "Picks up a ticket the user has referenced by number or key (for example 'work on #42', 'pick up PROJ-123', 'implement issue 7', 'start on the export epic'), fetches its parent epic, recovers the embedded design context, presents the scope to the user for confirmation, and hands off to orchestrated-implementation with the recovered design as the approved input. The re-entry point for work planned in a previous session via a design skill and create-tickets; use this rather than a fresh design session when the design already exists on the ticket. Without a specific ticket reference this does not apply, and a question about what to work on next is triage rather than this skill."
---

# Work on Ticket

## Load the Ticketing Rules First

This skill depends on the rules in `../_shared/tickets.md`. Those rules are **not** always in context; they live next to the ticket skills and are loaded only when a ticket skill is invoked. Before running the procedure below, you **MUST** read `../_shared/tickets.md` using the Read tool if you have not already read it in this session.

The detection of which ticketing system is in use lives in `../_shared/ticketing-detection.md`, loaded at step 1. The per-system fetch calls live in `./per-system-fetch.md`, read at step 2 once detection has resolved. The downstream implementation workflow lives in `orchestrated-implementation`.

**Precondition**: the user has referenced a specific ticket to work on (for example, "work on #42", "pick up PROJ-123", "implement issue 7"). Without a specific reference, this skill does not apply; if the user is asking what to work on next, that is a triage question, not this skill.

## Procedure

You **MUST** complete these steps in order. Do not skip a step and do not reorder them.

1. **Detect the ticketing system.** Read `../_shared/ticketing-detection.md` and run its procedure to identify where the ticket lives.

   Detection resolves systems this skill has no fetch procedure for. If it returns "none", or returns a system with no section in `./per-system-fetch.md` (Azure DevOps and Bitbucket are both reachable results), go to the "No fetchable ticketing system" edge case below and follow it instead of continuing to step 2. Every other step assumes a fetchable ticket.

2. **Fetch the ticket.** Read the section of `./per-system-fetch.md` for the system step 1 resolved, and skip the rest. Retrieve the ticket's full content: title, description, labels, status, parent or epic relationship, child or sub-issue references, and linked tickets.

3. **Run `resolve_epic_context`.** Per `../_shared/tickets.md`, this is the named procedure that walks from the fetched ticket up to its Epic and recovers the approved design. The procedure is tier-marker-driven: it reads each node's tier marker (Jira issue type, `tier:epic`/`tier:story`/`tier:task` label, or markdown heading level depending on the system), walks at most 2 hops, and terminates at the Epic. See `../_shared/tickets.md` "Recovery Before Implementation" for the full procedure, the termination rule, the legacy fallback boundary, and the decision tree.

   Run the procedure as `../_shared/tickets.md` states it, including its termination rule, its hard caps and guards, its legacy fallback boundary, and its handling of any failure. Do not re-derive those conditions here: a local copy of the failure list drifts behind the canonical one. Where that procedure requires surfacing an unresolved reference, this skill surfaces it via `AskUserQuestion` and stops rather than continuing.

4. **Extract the design.** `resolve_epic_context` returns the Epic and (if walked through one) the Story's theme statement. Extract the Epic body's `## Design` section. This becomes the approved design input for the implementation workflow.

   If `resolve_epic_context` succeeds but the resolved Epic has **no** `## Design` section at all (tickets created manually or by an older workflow predating the rule), follow the manual fallback documented in `../_shared/tickets.md` under "Recovery Before Implementation", including its prohibition on guessing the design.

   That fallback asks the user for the missing context, and each answer has its own continuation. If they have none to give, stop here and recommend establishing a design through `design-grill` before the ticket is picked up again. Do not proceed to step 5 on the reduced context: an Epic with no design has nothing for the implementation workflow to treat as approved, and inferring one is the guess the paragraph above forbids.

   If they do supply it, carry it forward as the design and continue from step 5, presenting it at step 6 as user-supplied rather than recovered so they can see what they are ratifying. Step 7's confirmation is what approves it, which is why it cannot be skipped on this path. Recommend back-filling the Epic's `## Design` with what they gave you: per `../_shared/tickets.md` the epic body is the single source of truth, so an Epic left empty puts the next session through this same recovery.

   A `resolve_epic_context` failure reached here is still covered by step 3, and the missing-`## Design` branch above is not an exception to it.

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

7. **Get explicit user confirmation.** Use `AskUserQuestion` to confirm scope. Plain-text confirmation is not sufficient.

   ```
   AskUserQuestion:
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

   If the user selects "Adjust scope" or "Need more context", address the feedback and re-present with `AskUserQuestion` again. Only proceed to step 8 after "Looks good, proceed".

8. **Hand off to `orchestrated-implementation`.** Use `Skill` to invoke it. This **MUST** be an actual skill invocation, not a conceptual handoff; if you skip the invocation, the downstream skill's full instructions will not be loaded and implementation quality will suffer.

   ```
   Skill:
     skill: "orchestrated-implementation"
   ```

   Before invoking, construct the approved design input by combining:

   1. The design context recovered from the epic (the architectural vision)
   2. The ticket scope (what specifically this ticket delivers)
   3. The acceptance criteria from the ticket (the spec that the spec reviewer will check against)
   4. Codebase observations from step 5

## Per-System Fetch

The fetch calls, and the native parent mechanism `resolve_epic_context` follows for each system, live in `./per-system-fetch.md`. Read the section for the system resolved at step 1 and skip the rest.

A parent reference that cannot be resolved (the ticket is missing, deleted, or permission is denied) is handled by `resolve_epic_context`'s own rules; see step 3.

## Handling Multiple Tickets

If the user wants to work on multiple tickets, work on them one at a time in dependency order. Read that order from each ticket's own blocking or linked-ticket field, which is what `create-tickets` writes the `Depends on` references into; a ticket blocked by another in the set goes after it. Where no ticket in the set declares a dependency, order per `../../rules/common/workflow.md` (foundations first, features next, integration after dependencies, polish last), and where that leaves two tickets genuinely interchangeable, ask the user rather than picking for them. Complete one ticket through the full `orchestrated-implementation` cycle (including reviews) before starting the next. Parallelism belongs inside a ticket rather than across tickets: that skill already runs every ready task concurrently, so a second session buys nothing and puts two leads in one working tree.

## Edge Cases

- **Ticket already partially implemented**: read git history and current code state, present what exists to the user, and adjust the scope to cover only the remaining work before step 7.
- **Ticket depends on unfinished work**: flag the dependency. Ask the user whether to work on the dependency first or to proceed with stubs or interfaces for the missing pieces. Working the dependency first means invoking this skill afresh against that ticket and returning here once it is complete; proceeding with stubs means recording them as codebase observations in step 5 and continuing from step 6, so the user sees them in the scope before confirming it.
- **Ticket description is vague**: use the epic's design context to fill in gaps. If still unclear after that, ask the user targeted questions, then continue from step 5 with the answers folded in. You **MUST NOT** guess at requirements.
- **No fetchable ticketing system**: if the user provides a ticket reference and step 1 routed here, whether because detection returned "none" or because it resolved a system with no section in `./per-system-fetch.md`, ask the user to paste the ticket content (and the parent epic content if applicable) directly, then run `resolve_epic_context` against the pasted content using the markdown heading structure described in `../_shared/tickets.md`'s Tier Markers section as the tier marker.
