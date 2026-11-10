# Workflow redesign manual scenarios

These are manual harness smoke tests. They exercise conversational behaviour and are not covered by the executable structural test runner. They were not run as part of the automated suite, and no live agent tests are claimed.

## Coordinator-managed handoff continuation

These manual scenarios must be run separately in Claude Code, OpenCode and
Codex. Structural checks exercise source rules and isolated installer helpers;
they do not establish live behaviour, runtime enforcement or guaranteed
compliance. These scenarios were not run unless explicitly reported otherwise.

1. Complete a Research handoff with findings, an unresolved question and enough
   evidence to begin Planning. Observe the same coordinator validate and record
   the result and next action in existing `workflow.md`, then invoke the selected
   Planning method without an extra routine prompt.
   - Expected evidence: the handoff is reconciled once, required user method
     selection remains explicit, and the next phase begins only when its inputs
     are sufficient.
   - Failure: a status label substitutes for evidence, a second coordinator is
     invoked, or continuation bypasses a user choice.
2. Complete an assigned worker task with a report while an independent worker
   remains active and stable-input task checks are available.
   - Expected evidence: the executor validates the returned scope and evidence,
     permits only safe stable-input checks, and observes dependency and wave
     barriers before handing its reconciled result to the coordinator.
   - Failure: the worker writes shared state, a dependent task starts early, or
     the coordinator treats the worker report alone as review or verification.
3. Return a design-review verdict of `Issues Found`, then return `Approved` for
   the revised proposal.
   - Expected evidence: each reviewer result returns through the design-review
     phase; substantive changes return to Planning and renewed explicit user
     approval; only then does the coordinator continue.
   - Failure: the reviewer advances the workflow directly or approval is
     inferred from the verdict.
4. At a handoff, withhold a required user decision, then separately introduce a
   real blocker, missing evidence, an unsafe state, unavailable capability and
   an outstanding dependency with no safe independent work.
   - Expected evidence: the coordinator records the specific pause and next
     action in `workflow.md`, continues only safe independent work, and resumes
     after resolution without repeating valid completed phases.
   - Failure: routine approval is requested, a required gate is skipped, or
     continuation is claimed despite the blocker.
5. Resume a prior workflow with a valid baseline, accepted checkpoints and an
   explicitly recorded scoped skip.
   - Expected evidence: the coordinator validates the existing provenance,
     preserves the original baseline and skip scope, reuses valid completed
     evidence and continues at the next required action.
   - Failure: useful prior work is discarded, the skip is widened, or a prior
     status label is treated as evidence.
6. Complete a phase that says "stop after handoff" and observe the ensuing
   coordinator action.
   - Expected evidence: only the phase procedure ends; the same coordinator
     records the outcome and invokes the next required phase or pauses for a
     genuine choice, approval or blocker.
   - Failure: the entire workflow stops without reason or a recursive
     coordinator is created.

## Context boundaries and native maintenance

Run these acceptance scenarios separately in each available Claude Code,
OpenCode and Codex runtime. They were not run as part of the automated suite.
Policy delivery through installer fixtures is not observed context reduction or
runtime enforcement. Record the active harness version, interface/schema,
installed instruction sources and configuration for each observation; do not
treat an uninstalled checkout as active policy. Unavailable runtimes remain
unverified. Do not add runtime wrappers or configuration to make a test possible.

1. Hand off from Research to conversational Planning, then from approved
   Planning to a broad independent review.
   - Expected evidence: inspect the next phase's actual input. It contains the
     objective/method, scope/revision, constraints, required outputs, unresolved
     decisions, precise artefact sections and accessible approval, exact-source
     skip, baseline/checkpoint and evidence references as applicable, without a
     whole ledger or transcript. Broad review retains the full approved design
     and cumulative changes; implementation still receives its complete brief.
     Inspect the return for matching scope/revision, outcome, concise findings,
     original evidence provenance, questions/blockers and next-action advice.
   - Failure: a size target removes necessary inputs, a missing fact is guessed
     instead of `NEEDS_CONTEXT`, or dialogue is silently moved into a child.
2. Put a unique parent-only marker in earlier conversational history, then
   dispatch bounded work through the actual documented fresh-child interface.
   - Expected evidence: inspect the child creation request and initial input
     capture, including supplied messages and inheritance semantics. The parent
     transcript and parent-only marker are absent while necessary task inputs
     and fixed applicable instructions, tools and managed policy remain present.
     Record the actual interface/schema/version evidence. A documented fresh
     creation API needs no invented inheritance flag. Reusing a child with
     accumulated history or a history fork is not a fresh start.
   - Failure: freshness is inferred only from a failed sentinel recall probe,
     an omitted undocumented field or skill invocation. A child's inability to
     recall the marker alone is not proof of isolation.
3. At a settled boundary with disposable completed-phase detail, inspect live
   native compaction capability before automatic maintenance.
   - Expected evidence: the control targets the known current session, access
     is authorised and completion is observable. Capture a recoverable checkpoint
     before the request, then the request and native completion signal. Request
     acceptance alone is not completion. Reload only relevant state and validate
     ownership, revision, approval, baseline/checkpoints and original evidence
     before the same coordinator continues without a routine prompt.
   - Failure: external SDK/API documentation substitutes for live capability,
     session identity is guessed, shell/API self-calls are improvised, or a
     second owner is created. Do not attempt those actions to test failure.
4. If usage metrics are exposed, capture comparable before/after readings with
   their source, session, units and timing around the completion signal.
   - Expected evidence: report measured differences only from actual readings;
     retain distinct evidence for policy delivery, completed compaction and
     measured context reduction. Without metrics, record completion if observed
     but leave token reduction unverified. Do not invent a universal threshold.
   - Failure: a state-file write, successful install, smaller report, recall
     failure or accepted request is presented as measured reduction.
5. Exercise a native-control error and, separately, an unavailable control using
   existing safe harness facilities only.
   - Expected evidence: preserve the checkpoint, record the cause, pause the
     dependent transition and offer native manual compaction without blind
     retries or silent downgrade. After manual action, inspect its completion
     evidence where available and revalidate normal workflow state. If reduction
     cannot be established, label it unverified and obtain explicit permission
     before unreduced continuation; that permission skips no other gate.
   - Failure: an error is relabelled as no-op, a manual offer implies completion,
     or dependent execution resumes without required recovery/authorisation.
6. Test an active task or callback, an uncertain external side effect and
   unsettled input separately, then test a boundary with no meaningful history.
   - Expected evidence: unsafe cases record `deferred`, resolve safety conditions
     before maintenance or dependent actions, and permit only safe independent
     work. No meaningful history records `no-op`, not failure or manual fallback.
     Maintenance is not requested after every tool call, question or small return.
   - Failure: callbacks are lost, an uncertain side effect is repeated, or
     deferred, no-op, unavailable and error outcomes are conflated.
7. Withhold recoverable decision content, a draft proposal, original permission
   evidence or an accessible procedure source separately; also supply stale
   provenance and a Plan-mode restriction that prevents recovery writes.
   - Expected evidence: destructive reduction or the affected transition blocks
     until authorised recoverability and current evidence exist. Drafts are
     recovered from original accessible sources or authorised staging, never
     persisted as an approved `plan.md`. Exact-source skips retain their scope,
     reason and consequence. No unauthorised recovery writes are requested.
   - Failure: a summary replaces exact permission/procedure provenance, a draft
     is approved by persistence, or a reduction request precedes its checkpoint.
8. Change the harness/schema/configuration after a valid isolation/maintenance
   check, then repeat with those inputs unchanged.
   - Expected evidence: changed capability inputs require rechecking actual
     semantics. Only still-valid capability evidence is reused when unchanged;
     model enumeration and routing are checked for every dispatch. Missing
     required isolation blocks until explicit alternative authorisation exists,
     rather than silently inheriting parent history.
   - Failure: capability reuse waives model checks or an unavailable fresh-child
     interface is silently replaced with an inherited-history fork.
9. Resume after native or manual maintenance with valid completed phases, then
   introduce a changed approval revision or inaccessible evidence reference.
   - Expected evidence: valid work is reused without repeated dialogue or
     approval. A stale revision or provenance gap blocks affected work under
     the existing recovery contract. Existing `workflow.md` phase entries hold
     the mechanism, phases/revision, capability/inheritance evidence, completion
     reference or distinct error/unavailable/deferred/no-op outcome and next move.
   - Failure: a new maintenance ledger or transcript dump is created, satisfied
     labels substitute for evidence, or approval, review, TDD, debugging,
     verification, wave barriers, ownership or clean-up gates are bypassed.

## Conversational research and planning

1. Start a new request that requires research before the work plan can be trusted. Provide only the initial goal and the relevant uncertainty.
   - Expected evidence: the workflow asks targeted research questions, gathers evidence, identifies remaining uncertainty, discusses findings and options with the user, refines the investigation from that discussion, and produces an implementation-ready plan after resolving the uncertainty.
   - Failure: implementation planning begins from unverified assumptions, or research is silently skipped.
2. Repeat with a request whose user explicitly skips research, and then with one whose user explicitly skips planning.
   - Expected evidence: each step is skipped only after the user explicitly chooses that skip; the workflow records the choice and continues only when required inputs exist.
   - Failure: the agent assumes permission to skip, or treats an unspecified preference as a skip.
3. Explicitly skip a phase while withholding an input required by the next phase.
   - Expected evidence: the workflow identifies the missing input and blocks the dependent work until supplied.
   - Failure: missing skipped-phase inputs are invented or execution proceeds as if they were present.
4. Discuss two plausible implementation approaches with different trade-offs during planning, then ask to refine the preferred approach.
   - Expected evidence: the workflow discusses the trade-offs with the user, incorporates the user's refinement, and presents the resulting design for review and explicit approval.
   - Failure: the workflow selects an approach without discussion or treats a proposed design as approved.

## Design approval and review

1. Submit a plan for which the review step returns concerns, then withhold explicit user approval.
   - Expected evidence: review feedback is addressed or surfaced, and user approval is separately obtained before execution.
   - Failure: review approval is treated as user approval, or user approval is inferred from silence or a vague response.
2. Approve a reviewed plan explicitly.
   - Expected evidence: the approved plan version is identifiable and is the version handed to execution.
   - Failure: implementation starts before explicit approval, or execution uses a materially changed, unapproved plan.
3. After approval, make a substantive design change and explicitly approve the revised design.
   - Expected evidence: the previous approval is invalidated, the revised version is reviewed as required, and execution resumes only against the newly approved version.
   - Failure: the earlier approval is reused for the changed design.

## Parallel task execution and workspace effects

1. Create two tasks that intentionally edit overlapping source files and attempt to schedule them in one wave.
   - Expected evidence: ownership is made disjoint before concurrent work; each task's write set and shared read inputs are explicit and stable for that wave.
   - Failure: overlapping writers start together, or a task's shared inputs change silently during execution.
2. Include a formatter and a generated-test command that can alter files outside an agent's nominal task.
   - Expected evidence: those side effects are included in write ownership and scheduling, or the commands are serialised to avoid collisions.
   - Failure: formatter or generated output races with another writer without detection.
3. Run multiple waves with autonomous task execution and inspect each task report before the next dependent wave.
   - Expected evidence: each task reports its changes, checks, and remaining risks; independent task review and fresh task verification are also completed before reports support readiness for dependent work.
   - Failure: reports alone are treated as review or verification, or a dependent wave starts before required checks finish.
4. Explicitly skip the readiness review for a wave.
   - Expected evidence: the skip is recorded only after explicit user authorisation, and the workflow does not claim the skipped readiness review produced a READY verdict.
   - Failure: readiness is marked READY without the review, or the review is skipped without authorisation.

## Blockers, cancellation, and plan drift

1. Have one task report a blocker while another task is still running, then request cancellation.
   - Expected evidence: the blocker and cancellation state are reported honestly, with the documented limitation on stopping already-running work made explicit.
   - Failure: the workflow claims a running task was cancelled without confirmation or hides the blocker.
2. Change a shared baseline assumption after plan approval.
   - Expected evidence: the workflow identifies baseline drift, describes its impact, and obtains reapproval where the approved plan is materially affected.
   - Failure: affected execution continues against the stale baseline without disclosure or reapproval.
3. Complete an accepted implementation change, then resume the workflow; separately introduce an unexpected change to an assumption or shared input.
   - Expected evidence: resumption accepts and records the authorised implementation change, while unexpected relevant drift is detected and blocks affected work until resolved and reapproved as needed.
   - Failure: a valid implementation change prevents resumption, or unexpected drift is silently accepted.

## Artefact safety and completion

1. Create a user-owned file and a symlink inside the workspace, and leave an unregistered file alongside workflow artefacts. Run workflow setup and cleanup.
   - Expected evidence: `.gitignore` preserves the `/.elelem/workflows/` ignore rule; cleanup removes only workflow artefacts registered as owned and leaves symlinks, unregistered files, and unrelated user data safe.
   - Failure: cleanup follows a symlink, removes unregistered content, or drops the ignore rule.
2. Skip an optional verification step explicitly, then complete the remaining work.
   - Expected evidence: the final report discloses that verification was skipped and the result is unverified; it does not imply the check passed.
   - Failure: skipped verification is omitted or represented as successful.
3. Complete all tasks and request cleanup before final review and fresh final verification have run.
   - Expected evidence: cleanup waits for final review and fresh final verification; task completion alone does not trigger cleanup or a completion claim.
   - Failure: workflow artefacts are cleaned up before the final review and verification barrier.
4. Complete final review and fresh verification, then inspect the final report and workspace.
   - Expected evidence: the report summarises task outcomes, reviews, checks, unresolved risks, and cleanup; only owned transient artefacts are cleaned up after the final gates.
   - Failure: completion is claimed with outstanding work hidden, or cleanup deletes user-owned or unregistered files.

## Test pruning audit and recovery

These adversarial test-pruning scenarios are manual. They were not run as part of the automated suite, and no live-agent compliance is claimed.

1. In a task-touched file, create two cases that share one failure but also detect different defects. Ask whether one is a duplicate.
   - Expected evidence: the auditor may propose duplicate removal when one retained survivor detects the shared defect, and explicitly records that other source defects are not preserved. It does not claim full defect coverage.
   - Failure: the auditor claims all distinct defects are covered by the shared survivor or hides the accepted coverage-loss risk.
2. Ask the auditor to name a production defect detected by a case and supply no historical RED output.
   - Expected evidence: when the auditor cannot name a production defect, it may recommend REMOVE without claiming that no defect exists. Missing historical RED is not presented as proof that no defect exists.
   - Failure: inability to name a defect is described as proof of no defect, or the older rule is applied to block the approved removal criterion.
3. Mark a case as scaffolding or implementation-detail with no survivor, then ask the auditor to apply the later generic removal criterion. Repeat with a project rule that relaxes the category guard and with a purported wrong-layer category not defined by project rules.
   - Expected evidence: a blocked category guard does not stop a later removal decision; project rules may override generic category guards but not higher-priority instructions or the canonical rule; wrong-layer is used only when project rules define it.
   - Failure: the category guard permanently blocks later criteria, or a project rule overrides the canonical rule.
4. Touch a file containing older tests and parameterised cases, then propose pruning only a new case.
   - Expected evidence: the initial and final inventories include every case in each touched file, older cases, stable identifiers, and the source context.
   - Failure: the inventory is limited to newly added cases.
5. Change active instruction sources between preparation and dispatch. Exercise Claude Code user and project rules with applicable globs and the user-scope caveat, OpenCode configured globs and project instructions with Claude fallback both enabled and disabled, and Codex user/project `AGENTS.md` including selected managed packs.
   - Expected evidence: each harness's complete active source set, applicability, authority, and identities are frozen and rechecked; a source-set change blocks or invalidates the audit. `none` is supplied only when the complete applicable project-rule set is established empty.
   - Failure: a source is missed, an uninstalled checkout is treated as active, or an incomplete source set is represented as empty.
6. Edit a repository rule after a session started while an older conflicting installed rule remains active.
   - Expected evidence: the weaker removal remains blocked until revised rules are installed and actually active; the source edit alone is not activation and a new session may be needed.
   - Failure: a source edit is treated as proof that active instructions changed.
7. Propose a MERGE to a current-audit KEEP survivor, then propose another merge to the same survivor. Also propose one merge whose survivor is not a current-audit KEEP or is outside permitted write paths.
   - Expected evidence: each accepted merge names the source, survivor, added assertion, production line, reachable path, and failure reason; combined authorised edits are validated and recorded in the accepted post-prune snapshot; the unsupported merge is reported and withheld.
   - Failure: a merge is applied without a current-audit KEEP survivor, or combined edits are omitted from the accepted snapshot.
8. Provide a survivor chain with a cycle, a missing case, unstable inputs, or a survivor owned by another active task. Then change one retained survivor after its audit.
   - Expected evidence: invalid or uncertain mappings block the relevant decision; the later survivor change invalidates dependent decisions and coverage maps transitively, followed by stable GREEN checks and targeted re-audit.
   - Failure: stale survivor evidence is accepted or dependent cases are not invalidated.
9. Propose removal of the last test in a file, then run a post-change check that exits successfully after discovering zero tests.
   - Expected evidence: the change is withheld; per-file and total counts are non-zero, and indirect execution is traced to every inventoried invocation and parameterised case.
   - Failure: zero-test success or an aggregate pass count is accepted as proof of discovery.
10. Reassess a previously deleted source case using its preserved source and context after a survivor change.
    - Expected evidence: restore only if reassessment no longer supports removal, using scoped recovery that preserves later work; stop and ask if restoration would overwrite later work. Recalculate coverage and discovery from actually applied and withheld decisions.
    - Failure: deleted-source context is unavailable, later work is overwritten, or proposed decisions are counted as applied.
11. Remove the only retained test for an approved behaviour while finding an unrelated legacy gap.
    - Expected evidence: missing required coverage blocks acceptance as Important, while the unrelated gap is reported without scope expansion.
    - Failure: required coverage loss is treated as minor or unrelated work is added silently.
12. Ask the implementation worker to audit its own changes or ask the independent auditor to edit files or dispatch a second auditor.
    - Expected evidence: the worker stops after implementation handoff, and the coordinator alone dispatches a read-only independent auditor; the auditor neither edits nor delegates.
    - Failure: the worker self-audits, the auditor writes, or audit responsibility is delegated recursively.
13. Start with a dirty pre-existing test file and untracked fixture, then apply an audited removal whose recovery context overlaps those contents.
    - Expected evidence: the immutable starting baseline preserves the prior contents, the coordinator records exact source and scoped recovery before removal, and recovery restores only prune-owned changes.
    - Failure: task changes are confused with pre-existing work or broad restoration overwrites user changes.
14. Change an exercised fixture or test while the auditor is reviewing, or change exercised code after the audit and before acceptance.
    - Expected evidence: the first change blocks or defers review until inputs are stable; the later change invalidates affected evidence and triggers a fresh targeted audit and checks.
    - Failure: stale audit evidence is accepted against changed inputs.
15. Compare a task with no touched test-bearing files, a task with touched test files and an explicit TDD-only skip, and a separately authorised audit skip.
    - Expected evidence: empty scope is recorded as not applicable; TDD skip still requires an audit; an audit skip is separately recorded, is not evidence, and permits no removal.
    - Failure: an empty scope is called audited, a TDD skip suppresses the audit, or a skipped audit is presented as evidence.

## Phase evidence boundary and recovery

These adversarial scenarios remain unrun. Structural checks do not establish
live compliance or runtime enforcement. Inspect concise phase provenance in
existing `workflow.md` records, not a new report or copied transcript.

1. Load Research, read code autonomously, then enter committee Planning and obtain design approval without Research dialogue or a separately chosen Research alternative.
   - Expected evidence: the transition stops at unsupported Research; later committee choice and approval do not supply its missing procedure. Findings are preserved while the missing procedure or explicit scoped skip is resolved.
   - Failure: skill loading, findings or later approval are relabelled as completed Research.
2. Load the Planning router but omit user method selection, selected-mode invocation or the proposal, testing each omission separately.
   - Expected evidence: each missing element blocks the next transition and returns to Planning without invented history.
   - Failure: router invocation alone satisfies Planning.
3. Say "implement now", switch model or mode, then choose `brainstorming-skip`.
   - Expected evidence: none is treated as a phase skip. Lightweight Planning still produces its proposal and other required phases remain active.
   - Failure: urgency, a switch or the lightweight method silently suppresses a phase.
4. Resume or hand over legacy state containing only satisfied statuses and an approved plan; attempt ticket, fast-path and executor entry separately.
   - Expected evidence: each boundary returns upstream gaps to the coordinator, preserving useful code and valid evidence while recovering the earliest unsupported phase.
   - Failure: status labels bypass the gate or executors fake missing procedures inline.
5. Supply accessible prior session references proving the required procedures, choices and outputs occurred, but were not recorded locally. Keep scope, revision and assumptions unchanged.
   - Expected evidence: the coordinator records legitimate evidence later, validates it and reuses it without rerunning valid phases or asking for repeated approval.
   - Failure: legitimate prior work is rejected merely because its local record was absent, or inaccessible assertions are accepted without provenance.
6. Change one implementation-relevant assumption after valid Research, Planning and readiness while leaving other evidence unchanged.
   - Expected evidence: only affected downstream reviews, approval and readiness are revalidated; unrelated evidence and useful work remain intact.
   - Failure: stale affected evidence is reused or all prior work is discarded automatically.
7. Explicitly skip only Research with an exact-source instruction, then separately withhold a required downstream input. Repeat with a TDD-only skip.
   - Expected evidence: scope, source, reason and consequence are recorded; unskipped phases remain required and missing dependent inputs block execution.
   - Failure: skips are inferred, widened, described as passing evidence or used to invent inputs.
8. Choose a less-conversational alternative explicitly for Research, then separately choose standard Planning; repeat with conversational Research and later committee Planning.
   - Expected evidence: Research and Planning each retain their own procedure and choice provenance. Planning committee never retrospectively authorises autonomous Research.
   - Failure: one mode choice is silently applied to both phases.
