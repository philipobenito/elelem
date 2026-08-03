---
name: design-recovery
description: "Re-enters work from a persisted design: a ticket the user references by number or key ('work on #42', 'pick up PROJ-123', 'implement issue 7', 'start on the export epic'), or a design document they point at ('implement docs/export-design.md', 'pick up the backlog file'). Fetches the artefact, recovers the design from it or its parent, reads the current state of the code, presents the scope for confirmation, and starts implementation with the recovered design as the approved input. Use this rather than a fresh design session when the design already exists on the artefact. Without a specific reference it does not apply, and a question about what to work on next is triage rather than recovery."
---

# Design Recovery

Recovery reads what is there rather than checking what is there against a schema. Persisted work arrives in many shapes: tickets created by the handoff skill with the design embedded in a parent, tickets a human filed by hand, a design document in the repository, a backlog file. The job is always the same, find the design the work was approved against, confirm the scope against the code as it is now, and only then let implementation start. Where the artefact's structure does not answer a question, the user does, via `AskUserQuestion`; nothing here fails merely because the shape is unfamiliar, and nothing here guesses.

## Preconditions

The user has referenced a specific artefact: a ticket number or key, or a design document. Without a specific reference this skill does not apply, and "what should I work on next" is a triage question, not a recovery.

## Procedure

1. **Locate the artefact.** The reference usually identifies the system by itself: a `PROJ-123` key is Jira, a `#42` number belongs to the issue tracker of the current remote, a path or filename is a document in the repository. Where the reference alone is ambiguous, check which ticketing MCP tools the session carries and what the git remote is, and if more than one system could plausibly hold the reference, ask the user with `AskUserQuestion` rather than fetching from the most likely one. If no system is reachable at all, take the "No fetchable system" edge case below.

2. **Fetch it in full**: title, body, labels, status, parent relationship, child references, and linked tickets, using the calls for the resolved system in `./per-system-fetch.md` and reading only that section. For a document, read the file; its headings carry whatever structure it has.

3. **Recover the design.** The design is wherever the artefact's shape put it, so search outward from the reference:

   - If the referenced artefact's own body carries the design, typically under a `## Design` heading, recovery is done.
   - Otherwise, walk parent references: the system's native parent mechanism first, body-text references (`Part of #N`, `Epic: #N`) second, as `./per-system-fetch.md` describes per system. Collect anything that reads as design content along the way, and note each intermediate body's own context (a grouping ticket's theme statement frames its children even though it is not the design).
   - Stop when a node carries the design, when there is no parent left to walk, or after three hops, whichever comes first. Track visited references; revisiting one means the links are malformed, which is a finding to surface, not a loop to follow.

   Then resolve what the walk found:

   | The walk found                           | Action                                                                                                                                          |
   |------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
   | Exactly one body carrying the design     | Extract it and continue.                                                                                                                        |
   | Design content in more than one place    | Present the candidates and where each lives, and ask the user which governs, with `AskUserQuestion`. Do not merge them or pick the newest.      |
   | No design anywhere reachable             | Take step 4's missing-design path.                                                                                                              |
   | A parent reference that does not resolve | Say which reference failed and ask the user whether to continue on what was gathered or to supply the missing content. Do not silently walk on. |

   A design document referenced directly is its own design; the walk collapses to reading it.

4. **Handle a missing design.** Present what the artefact does say and ask the user for the missing context. If they supply it, carry it forward marked as user-supplied rather than recovered, so at step 6 they can see what they are ratifying, and recommend back-filling the artefact with it: an artefact left without its design puts the next session through this same recovery. If they have none to give, stop and recommend a design session before this work is picked up again. Do not proceed on an inferred design: an artefact with no design has nothing for implementation to treat as approved.

5. **Read the current state of the code.** The design was approved against the codebase as it was read, not as it is. Note anything that has changed since, anything already partially implemented, and anything the design assumes exists but does not.

6. **Present the scope**: the artefact's title and reference; the recovered design, or the user-supplied stand-in flagged as such; what this specific piece of work builds, its acceptance criteria, and its dependencies; what sibling tickets place out of scope; and the codebase observations from step 5.

7. **Confirm with `AskUserQuestion`**, with three options: "Looks good, proceed", "Adjust scope", and "Need more context". Plain-text assent is not confirmation. Adjustments fold in and the scope is re-presented; more context means fetching or reading further, then re-presenting. Only "Looks good, proceed" continues.

8. **Start implementation**, with the approved input assembled from the recovered design (the architectural intent), the scope of this specific ticket or section, its acceptance criteria, and the codebase observations. Implementation runs as its own workflow with its own gates; recovery's job ends at delivering it a design the user has confirmed.

## Handling Multiple Tickets

Work on one at a time, in dependency order read from each ticket's own blocking or linked-ticket references; a ticket blocked by another in the set goes after it. Where no dependency is declared and two tickets are genuinely interchangeable, ask the user rather than picking. Complete each one through the full implementation cycle before starting the next: parallelism belongs inside a piece of work, not across pieces sharing one working tree.

## Edge Cases

- **Already partially implemented**: read the git history and current code, present what exists, and shrink the scope to the remaining work before the step 7 confirmation.
- **Depends on unfinished work**: flag it and ask the user whether to work the dependency first (recover that ticket, return to this one after) or proceed with stubs for the missing pieces, recorded in the step 5 observations so the user confirms them as part of the scope.
- **Vague description**: fill gaps from the recovered design first; where gaps remain, ask the user targeted questions. Do not guess at requirements.
- **No fetchable system**: ask the user to paste the ticket content, and the parent's content if there is one, then run the same recovery against the pasted text, reading its headings as the structure.

## Completion Gate

Do not start implementation until all of these hold:

- The artefact was fetched in full, or its content was supplied by the user
- The design was recovered from exactly one governing source, or supplied by the user and flagged as such
- The current state of the code was read and its divergences noted
- The user confirmed the scope through the step 7 question, not through plain-text assent

## Common Mistakes

| Mistake                                              | Why it is wrong                                                                                        |
|------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| Treating an unfamiliar structure as an error         | Recovery reads what is there. Structure questions go to the user, not to a schema. See step 3.         |
| Merging design content found in two places           | Which version governs is the user's call; a merge invents a design nobody approved. See step 3.        |
| Walking past an unresolvable parent silently         | The missing node may be the one carrying the design. Surface it. See step 3.                           |
| Inferring a design from the ticket title             | An inferred design was never approved. Missing context comes from the user or not at all. See step 4.  |
| Skipping the codebase read because the ticket is new | The code moved the moment the design session ended. Divergence is found here or during a failed build. |
| Accepting "yeah go ahead" as scope confirmation      | Confirmation is the step 7 question. Plain-text assent skips the scope the user is agreeing to.        |
| Starting a second ticket before the first completes  | Two pieces of work in one tree race each other. Dependency order, one at a time.                       |
