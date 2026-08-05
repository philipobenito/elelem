---
name: design-committee
description: "Turns an idea into an approved design through hands-off deliberation: three lens agents (Pragmatist, Architect, Advocate) state independent positions, cross-examine each other, and a synthesiser resolves each decision on evidence, all run as control flow by the workflow script shipped with this skill. Use when the user wants to be hands-off during design: 'committee', 'you decide', 'don't ask me design questions', 'come back when it's done'. The user confirms the brief, then sees nothing until the finished design is presented, design-reviewed, and put to them for explicit approval. Needs at least two meaningful design decisions; smaller work belongs to the interactive design dialogue."
---

# Design Committee

Hands-off design deliberation. `./design-workflow.js` runs the deliberation as control flow: per decision group, three lens agents state independent positions concurrently, every position faces cross-examination, a synthesiser resolves each decision on cited evidence with vote counting forbidden by its brief, and a decision still split after one tiebreak comes back marked unresolved for the user. This file holds the judgement the script cannot: confirming the brief, gathering the context, cutting the decision groups, constructing the args, and everything from the script's return to the user's approval.

The lenses are not voters. Three agents drawing on the same base model produce correlated answers, so agreement between them is not evidence of correctness; the lenses exist because each is briefed to catch a different way the design could fail, and the deliberation's value is in the contradictory context they force each other to resolve. The script's synthesis brief enforces this, and nothing on this side of the run may undo it by presenting a head-count as a reason.

## When to Run

The user has asked to be hands-off, and the work holds at least two meaningful design decisions. Where it holds fewer, say so and recommend the interactive dialogue instead: a deliberation over one settled question produces theatre, not a design. Being hands-off is the user's to ask for, never inferred from the shape of the work.

## Preconditions

- **Plan mode.** Enter it before anything else; load `EnterPlanMode` and `ExitPlanMode` via `ToolSearch` first where they are deferred. Where plan mode genuinely cannot be entered, proceed and say so: every agent prompt in the script carries a read-only instruction, and without plan mode that instruction is load-bearing rather than belt-and-braces.
- **The `Workflow` tool.** Confirm it is available before promising a deliberation. If it is not, run the same rounds sequentially through one-shot `Agent` dispatches, using the prompts embedded in the script as the briefs and holding its rules (cross-examination always runs, no vote counting, one tiebreak per decision) in your own text. If `Agent` is also unavailable, stop: name the missing capability and recommend the interactive dialogue.

## Procedure

1. **Confirm the brief.** Restate what you understand the user wants, the scope as you see it, and your assumptions, and confirm via `AskUserQuestion`. Once confirmed, the user is hands-off until step 6.

2. **Explore project context.** Read the area of the codebase the brief touches. Stay narrow: everything you read here is pasted into the args and reaches every agent in every round, so unnecessary context dilutes focus. If the brief needs more than three top-level source directories, or you cannot tell which code is relevant, surface what you found and ask via `AskUserQuestion`; this is the only question permitted between steps 1 and 6.

3. **Cut the decision groups.** List the key decisions (architecture, approach, data flow, error handling, testing strategy, integration) and group related ones into coherent sets rather than micro-choices. Order matters: groups run sequentially and each group's prompts carry the consensus recorded before it, so put the decisions others depend on first.

4. **Construct the args and launch.** The args are the entire world the agents see; the field list is documented at the top of `./design-workflow.js`. Paste the brief and the codebase context in full, never as file references. Launch with `Workflow` passing `scriptPath` pointing at `./design-workflow.js` beside this file; the run is background work, so continue only when its result returns. If the script throws on a missing lens position, re-launch once with `resumeFromRunId`; completed calls replay from cache and only the dead dispatch re-runs.

5. **Assemble the design summary.** Build a single coherent summary from the returned resolutions, covering goal, architecture, components, interfaces, data flow, error handling, testing strategy, and integration points, scaled to each section's complexity. Every entry in `mustAddressConcerns` is addressed in the design, not just noted. Follow existing patterns and add nothing the brief did not ask for; the synthesis can reject scope creep from a lens, but the assembly must not reintroduce it.

6. **Put the unresolved decisions to the user first.** Each entry in `unresolved` survived cross-examination and one tiebreak still split, which means it genuinely belongs to a human. Ask via `AskUserQuestion`, one decision at a time, presenting the competing positions and their evidence. Their answers go into the summary as decisions made.

7. **Present the design.** The full summary, a brief note on any decision that moved during cross-examination or was resolved against a dissent (with the reasoning), and the risks that were flagged. Never dump the deliberation transcripts, and never present how many lenses agreed as support for anything: the user wants the result and its evidence, not the process.

8. **Run a design review of the consolidated summary** and follow the return contract it states, with one addition for this mode. A reviewer edit or an open decision that changes something the deliberation explicitly resolved (a constraint, a trade-off, an interface boundary, rather than detail consistent with it) gets one targeted deliberation round first: re-launch the script with a single group holding that one decision and `priorConsensus` carrying the full recorded consensus, fold the result in, and have the revised summary reviewed afresh. Where you cannot tell whether an edit crosses that line, run the round; it costs one small launch, and skipping it lets one reviewer silently overrule a deliberation. A review that ends with its budget spent goes to the user as it stands.

9. **Take explicit final approval.** Present the reviewed summary and ask directly; "looks fine" is not approval. A user revision is taken as-is: the user overrules the deliberation, no targeted round, and the revised summary is text no reviewer has seen, so it returns to step 8. Once they approve, release plan mode via `ExitPlanMode` carrying the approved summary.

10. **Ask what happens next**, via `AskUserQuestion` with "Create tickets first", "Implement directly", plus one option per available skill whose description claims implementation of an approved design as its job, constructed per the routing rule in ../../rules/common/workflow.md, then do what they chose. An answer outside the offered options is new instruction and goes back to the user.

## Worked Example

User: "Add webhook delivery for order events. I don't want to be involved, come back when you have a design."

1. **Confirm the brief**: outbound webhooks for order lifecycle events, customer-configurable endpoints, management UI out of scope. Confirmed.
2. **Explore**: `src/orders/`, `src/queue/`, `src/config/`. An existing Redis-backed job queue with an at-least-once contract, HMAC signing already used for inbound partner callbacks, table-driven tests throughout.
3. **Groups**: (A) delivery mechanism and retry semantics; (B) endpoint configuration, signing, and failure handling. A first, because B's decisions depend on where delivery runs.
4. **Launch** with the brief, the pasted context, and both groups. In group A the Pragmatist recommends reusing the job queue, the Architect a separate delivery service so webhook backpressure cannot starve order jobs, the Advocate sides with separation purely on retry-storm risk. Cross-examination moves the Pragmatist to a dedicated queue on the existing Redis infrastructure, which the other two accept, the Advocate conditional on a dead-letter queue. The synthesiser resolves on that shape, citing the starvation scenario and the existing queue contract, and lists the isolation concern as must-address because two lenses raised it.
5. **Assemble** the summary from both groups' resolutions, with the dead-letter queue and isolation handling designed in rather than noted.
6. **Unresolved**: none returned this run, so nothing to put to the user early.
7. **Present**, noting the delivery-mechanism decision moved under cross-examination and why.
8. **Design review** returns an open decision: the summary never says what happens when a customer endpoint redirects, and following, failing, and rejecting are all consistent with the text. That is a decision the deliberation never made rather than a change to one it did, so it gets a targeted round: one group, one decision, `priorConsensus` carrying everything recorded. The round resolves on following redirects with a cap of three; the revised summary is reviewed afresh and approved.
9. **Final approval** explicit, then `ExitPlanMode` carrying the summary.
10. **Next step**: create tickets first.

## Completion Gate

Do not create tickets or start implementation until all of these hold:

- Every decision in every group has a recorded resolution, from the script, from a targeted round, or from the user answering an unresolved one
- Every must-address concern is addressed in the summary
- The design review approved the summary text you are holding
- The user gave explicit final approval against the reviewed summary
- Plan mode was released via `ExitPlanMode`, or was never entered because it was unavailable
- The user chose the next step themselves

## Common Mistakes

| Mistake                                                      | Why it is wrong                                                                                                                    |
|--------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Asking the user design questions between steps 1 and 6       | The deliberation replaces user questioning; the one exception is the scoping question in step 2.                                   |
| Presenting agreement between lenses as evidence              | Correlated agents agreeing tells you nothing. The evidence is what they cited, and it is the only support the presentation offers. |
| Resolving an unresolved decision yourself                    | It survived cross-examination and a tiebreak still split. Deciding it silently commits the user to a choice they never saw.        |
| Answering a review's open decision on the committee's behalf | A decision the deliberation never made gets a targeted round or the user, never an inline answer from you.                         |
| Dumping the deliberation transcripts on the user             | They asked to be hands-off. Surface the result, what moved, dissent worth knowing about, and the risks.                            |
| Skipping the design review because the lenses deliberated    | Deliberation is not review. The reviewer reads the consolidated summary fresh, which no lens ever saw.                             |
| Letting a must-address concern arrive as a footnote          | Concerns raised through more than one lens, or conceded under cross-examination, are signal. Design them in or the run failed.     |
| Re-running the design review after its budget is spent       | An exhausted review means a human decides. Only genuinely revised text earns a fresh review.                                       |
