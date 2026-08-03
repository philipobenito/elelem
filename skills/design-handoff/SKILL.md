---
name: design-handoff
description: "Persists an approved design into an artefact a future session can recover it from: tickets under a single parent whose body carries the full design, or a structured Markdown document when no ticketing system is available. Invoked by the design skills when the user chooses to create tickets after approving a design, and whenever the user asks to create tickets, file issues, break a design or plan into tickets, or set up a backlog. Handles GitHub Issues, Jira, GitLab and Linear. Requires an approved design already in hand; it does not invent one, and picking persisted work back up is the recovery skill's job, not this one's."
---

# Design Handoff

One invariant, everything else negotiated. The invariant: the artefact this skill leaves behind must let a future session recover the full approved design on its own, which means one parent, a ticket or a document, carrying the design in full in its own body. The negotiated part is every structural choice around that parent: how many tickets, whether they group, whether the work needs one parent or several. Those shapes are read off the design and settled with the user, never imposed from a fixed hierarchy.

## Preconditions

An approved design exists in conversation context: settled with the user and explicitly approved, recovered from an existing artefact, or carried by a specification the user has pointed to as approved. A design you have inferred from the request, or one the user has seen but not approved, does not qualify. With no approved design, stop and say so rather than inventing one, and do not start a design session on the user's behalf: whether to design now, and how involved to be, is their choice.

## Procedure

1. **Detect where the design can be persisted.** Run three checks in order and stop at the first unambiguous result:

   1. **MCP tools in the session**: `mcp__*Atlassian*__*JiraIssue*` means Jira, `mcp__*github*__issue_*` means GitHub Issues, `mcp__*linear*__*` means Linear, `mcp__*gitlab*__*` means GitLab Issues.
   2. **The git remote** (`git remote get-url origin`): `github.com` means GitHub Issues, `gitlab.com` means GitLab Issues. A self-hosted host may still match by substring; where it stays ambiguous, move on.
   3. **CLI binaries**: `gh` or `glab` on the path. A binary alone is a candidate, not a confirmation; a user can have `gh` installed without tracking work in GitHub Issues.

   Then resolve:

   | Result                                                    | Action                                                                                                                        |
   |-----------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------|
   | Exactly one supported system                              | Carry it forward. Its confirmation rides along with the step 5 gate rather than costing a separate question.                  |
   | More than one                                             | Resolve now with `AskUserQuestion`. Drafting does not depend on the answer, but creation does.                                |
   | A system with no section in `./per-system-persistence.md` | Tell the user the detected system is unsupported here, then take the None row.                                                |
   | None                                                      | Tell the user the output will be a structured Markdown document instead of tickets, then carry on. The drafted shape changes. |

2. **Propose the decomposition.** Read the shape off the design rather than applying a taxonomy to it:

   - Each ticket is sized to a single focused session, with acceptance criteria in three to five bullets. A component that does not fit is split before creation, not padded into a vaguer ticket.
   - Dependencies between tickets are stated where the design implies them: an integration ticket depends on the components it integrates, and cross-cutting foundations come before the work that stands on them.
   - Grouping mirrors structure the design itself names. Where the design names components or subsystems that each yield several tickets, offer that grouping; where it names none, the set stays flat, and flat is the ordinary shape rather than a degraded one. A single group wrapping every ticket adds a layer that tells the reader nothing the parent's title did not, so do not propose it.
   - Where one parent would carry an unwieldy design body, splitting into multiple parents along the design's own seams is on the table, each parent carrying in full the portion of the design its children need.

   Where two shapes are genuinely defensible, grouped or flat, one parent or several, put the choice to the user with `AskUserQuestion` rather than picking for them. The shape decides how the work reads for every future session, and two readers guessing separately produce trees that do not match.

3. **Draft the parent body.** The parent is the single source of truth for the design:

   ```markdown
   ## Goal

   [One-paragraph summary of what this parent delivers]

   ## Design

   [The full approved design: architecture, key components, interfaces, data flow,
    technical decisions and trade-offs, error handling, testing strategy, and anything
    else from the design conversation that affects how the children should be built]

   ## Tickets

   - [Ticket title] - [reference once created]
   ```

   List the `## Tickets` index in implementation order, grouped as the approved shape groups them. The index is a human convenience; the real parent-child relationships live in the ticketing system's native links. When step 1 resolved to None, read the Markdown Document section of `./per-system-persistence.md` now and draft that shape instead, so the user approves at step 5 the artefact they will actually get.

   Do not replace the `## Design` section with a link to an external file, a transcript, or a commit. Links rot and external context disappears; a future session opens the parent and must find everything it needs to build from.

4. **Draft each child ticket** with a title naming what it delivers, a description carrying the technical decisions from the design relevant to that ticket, acceptance criteria in three to five bullets, and its dependencies: a `Depends on` reference for each ticket that must exist first, plus its parent. A grouping ticket, where the user chose grouping, carries the group's one-sentence theme and its child references and no design content: the design lives once, in the parent, and a copy in a child is a second version waiting to drift.

5. **Order the set and gate before creating anything.** Build the global dependency order: foundations and cross-cutting concerns first, features next, integration after the things it integrates, polish last. A cycle in the dependency graph means no valid order exists; surface it and return to step 2 while everything is still a draft.

   Present the full set, then ask with `AskUserQuestion`, with three options: "Create them" (the decomposition, order and target are right), "Adjust first" (back to step 2 with the changes folded in), and "Change target" (back to step 1 to resolve the system; the decomposition survives, but the drafted bodies are redone against the new target's shape).

   This gate is the only cheap moment in the procedure. Creation writes to a system outside the repository and step 6 forbids rolling it back, so reshaping is free here and expensive or impossible afterwards. Nothing is created before "Create them".

6. **Create the parent first, then the children in global dependency order**, so a body saying `Depends on #N` is written after `#N` has an identifier. Use the calls for the resolved system in `./per-system-persistence.md`, reading only that section.

   | Failure                    | Response                                                                                                                                                                         |
   |----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
   | Parent creation fails      | Nothing exists yet. Report and stop.                                                                                                                                             |
   | A child creation fails     | Stop creating immediately. Back-fill the parent with the children that did get created, report the failed child and its intended position, and leave the partial state in place. |
   | The back-fill itself fails | Not fatal. Native links already carry recovery and the index is a convenience. Report the stale index and continue.                                                              |

   Do not silently continue past a creation failure, and do not roll back tickets that were created: rollback is a destructive operation against an external system, and whether to retry, fix and re-run, or keep the partial state is the user's call.

7. **Back-fill the parent's `## Tickets` index** with the real references, then **report**: what was created, the references and links, the implementation order, any degradation the system forced (each system's degradations are documented in `./per-system-persistence.md`), and any failure from step 6. This is a report, not a question; the moment to change the shape was step 5.

   Close with how to re-enter: referencing any of these tickets in a future session ("work on #42") recovers the design from the parent before implementation starts.

This skill is terminal. Do not start implementation after creating tickets: implementation from a ticket enters through recovery, which re-reads the code and confirms scope, and those checks matter even one minute after creation because the design was approved against the code as it was read, not as it is. If the user wants to begin immediately, the first ticket in the order is the one to reference.

## Completion Gate

Do not report the design as persisted until all of these hold:

- An approved design existed before anything was drafted
- The user approved the set, shape and target at the step 5 gate
- Every ticket in the approved set was created, or the failure was reported per step 6
- The parent body carries the full design under `## Design`, and no child does
- The report told the user how to pick the work back up

"Created" is a completion claim: it needs the actual API responses or the document on disk as evidence, not the memory of having sent the calls.

## Common Mistakes

| Mistake                                         | Why it is wrong                                                                                      |
|-------------------------------------------------|------------------------------------------------------------------------------------------------------|
| Creating tickets before the step 5 gate         | The gate is the only point where reshaping is free. See step 5.                                      |
| Imposing a grouping the design never named      | Structure is read off the design and settled with the user, not applied from a taxonomy. See step 2. |
| Wrapping every ticket in a single group         | It adds a hop to every future walk and says nothing the parent's title did not. See step 2.          |
| Linking to the design instead of embedding it   | Links rot; the parent body is the single source of truth. See step 3.                                |
| Copying design content into a child ticket      | A second copy of the design is a version conflict waiting for the session that reads the wrong one.  |
| Creating children in presentation order         | A `Depends on #N` reference needs `#N` to exist first. See step 6.                                   |
| Rolling back after a partial failure            | Destructive, and the user's decision to make. See step 6.                                            |
| Starting implementation straight after creation | Re-entry is recovery's job: it re-reads the code and re-confirms scope before any work starts.       |
