# Test Pruning

This procedure governs audits and supported removal of tests from task-touched
test-bearing files. The coordinator owns audit dispatch, snapshots, workflow
state, and recovery. The implementation worker never dispatches an auditor,
delegates an audit, or substitutes a self-audit. The Meaningful Assertions
section in `rules/common/testing.md` is the sole canonical value rule. Retrieve
its authoritative text as described below and inject it into the auditor prompt
verbatim; do not duplicate or paraphrase the rule here.

## Resolve and freeze active instruction sources

Before preparing an audit, identify the active harness and inspect its complete
instruction context, not only the canonical rule file. Resolve all applicable
project test rules and higher-priority instructions that affect test value.
Supply applicable project test rules verbatim to the auditor, or supply `none`
only when the complete applicable project-rule set is established empty. Block
when scope, applicability, completeness, or authority cannot be established;
uncertain applicability blocks dispatch.

- Claude Code: inspect active user-scope and project-scope rule files and
  applicable `globs:`. Account for the documented user-scope caveat: user-scope
  `globs:` may not be honoured, while project-scope rules can still apply.
- OpenCode: inspect the configured instruction globs, project instructions,
  and Claude Code fallback when enabled, including its fallback instructions.
  A source outside the configured or fallback context is not active merely
  because it exists in the checkout.
- Codex: inspect active user and project `AGENTS.md` instructions, including
  selected packs within active elelem-managed blocks. Do not infer the active
  managed block from an uninstalled checkout.

Freeze each source's identity, applicability, authority, and the complete
source set before dispatch. Recheck them at dispatch and acceptance. A changed
source set or identity invalidates affected audit evidence. Older conflicting
active instructions block weaker removals until the revised rules are
installed and actually active. Editing a source file alone is not activation.
A source edit alone is not activation; a new session may be required.

## Retrieve the canonical rule

For Claude Code and OpenCode, resolve the authoritative
`rules/common/testing.md` from the complete, verified active instruction source
set and current harness instruction context. The skill and active rule may be
installed in different user or project scopes. Select the source using active
rule applicability, configured instruction globs and Claude fallback status,
together with harness precedence. Verify the selected source identity and
active status against frozen inputs. Do not infer the canonical rule source
from adjacency to this helper or a guessed path. Do not guess a path or fall
back to an uninstalled source. If the active authoritative source, its
identity, applicability, or precedence is missing, inconsistent, or ambiguous,
block before dispatch.

For Codex, use the active elelem-managed `AGENTS.md` block and its
`## rules/common/testing.md` entry, as identified by the current instruction
context. Do not use a guessed path or the source checkout. Within the exact
`<!-- elelem:codex:start -->` and `<!-- elelem:codex:end -->` block, locate the
unique `## rules/common/testing.md` rule entry, then locate its unique
`## Meaningful Assertions` section. Do not use a similarly named heading
elsewhere in `AGENTS.md` or another active instruction file.

From the selected rule entry, copy only the complete Meaningful Assertions
section verbatim. Its boundaries are the `## Meaningful Assertions` heading
through the line immediately before the next level-two heading, or before a
higher-level heading if one comes first. For Codex, first bound the rule entry
from `## rules/common/testing.md` to the next `## rules/` entry or the end of
the elelem-managed block, then apply the same section boundaries. Include no
surrounding rule sections, generated labels, or commentary.

Confirm the harness source, managed-block and rule-entry boundaries where
applicable, and exactly one matching section before dispatch. If the
authoritative full section is unavailable, cannot be retrieved, has ambiguous
or duplicate boundaries, or cannot be copied exactly, block the audit before
dispatch. Do not fall back to paraphrase, memory, another harness's source, or
the repository source when Codex's active managed rule is unavailable.

## Scope and entry conditions

Before the first RED step, the coordinator records in `workflow.md` the
immutable task-start HEAD and relevant working-tree state, including exact
contents or equivalent snapshots of relevant pre-existing dirty and untracked
paths. An existing supplied baseline may be used only after validating its
source, revision, scope, and current contents. Never move or replace the
original baseline with a later task checkpoint.

Keep the current-live inventory separate from archived removed-source cases.
Before pruning begins, record the complete initial live inventory: every test
and parameterised case currently present in each test-bearing file in scope,
including older live tests. After implementation work stops,
derive the final audit scope from the worker's actual changed paths within the
task's allowed writes.
Do not use a broad HEAD diff to select tests. Inventory every case still
present in each actually touched test-bearing file and record stable test and
case identifiers and source identities. Archived removed-source records are
separate from the current live inventory; do not add archived cases to it or
count them as live execution cases. If no test-bearing file was touched, record
the audit as `NOT APPLICABLE` with the empty live scope and do not invent an
audit or evidence.

A TDD-only skip does not waive this audit. A TDD skip, audit skip, and check
skip are separate decisions. Only explicit user authorisation can skip the
audit or a check. Record each skip's exact scope, reason, and consequence in
`workflow.md`. A skipped audit is not evidence and permits no test removals.

## Freeze inputs and establish the pre-prune state

The coordinator must ensure that no relevant writer is active. If an audit
input may change during another task, defer the audit to a safe wave barrier.
Never rely on tests owned or changed by another active task as removal
survivors.

Freeze and record stable input identities for current-live test files and
cases, exercised production code, fixtures, configuration, and resources that
affect the assertions. Archived removed-source records are not current-live
cases. Account for test-command side effects before running checks. Run the
pre-prune task checks against stable live inputs and record exact commands,
outputs, exit codes, discovered test and case counts per current-live file, and
total counts. Establish non-zero discovery counts per current-live file and
total for the live inventory. Where execution uses an indirect runner, capture
a trace and correlate each current-live case invocation with its executed trace
entry. Archived sources are excluded from current-live counts and trace
requirements. Aggregate pass counts are not discovery evidence. If a
check changes a live audit input, refresh the live inventory and content
identities and rerun the check until the inputs and results are stable. The
coordinator records the resulting live pre-prune audit snapshot and evidence in
`workflow.md` before dispatching an auditor.

Every required pre-prune check must exit with status zero. A non-zero exit
status blocks removal and auditor dispatch. Treat the failed check as a task
blocker, correct it through the approved workflow, refresh affected inputs, and
rerun the pre-prune checks before auditing. A failed check is not a valid audit
baseline.

If the runner cannot establish discovery counts, or a test-bearing file has no
discovered tests, stop before removal. Do not treat a successful command that
discovered zero tests as a passing pre-prune baseline.

## Independent audit

The coordinator selects a suitable independent test or quality specialist and
uses the current `subagent-dispatch.md` procedure to verify the concrete
high-capability model and harness routing. The coordinator alone dispatches
the auditor. The auditor is read-only: it must not edit files, run tests or
other mutating checks, change workflow state, dispatch another agent, or
perform removals. Give it the frozen inputs and pre-prune evidence listed in
the prompt. If those inputs are incomplete or unstable, it returns `BLOCKED`.

The auditor inventories every current-live test and case in scope and returns
exactly one `KEEP`, `REMOVE`, or `MERGE` decision for each, with evidence under
the supplied canonical rule. Include category, rationale, named production
defect when applicable, and current-audit survivor references. A `REMOVE` may
follow when the auditor cannot name a production defect, without claiming that
this proves no defect exists. For duplicate removal, one retained survivor may
detect a defect shared with the source even when other source defects are not
preserved. Do not treat one shared failure as proof of general redundancy.
Survivors must be real, stable, retained, and non-cyclic. Uncertain survivor
proof cannot establish retained coverage; report that uncertainty and do not
claim unverified coverage is preserved. Uncertain safe application blocks
applying a proposed removal or merge. These uncertainties do not override a
REMOVE otherwise permitted by the canonical rule when the auditor cannot name
a production defect.

Archived removed-source reassessments are separate from current-live cases.
Always require the preserved exact source and surrounding context,
pre-removal snapshot identities, and actual prior check and discovery evidence,
including commands, outputs, exit status, and discovery counts. Establish the
original runner and whether historical trace evidence was applicable. Require
prior trace-to-case evidence when the original runner was indirect; when the
original runner was direct, the prior check and discovery evidence is sufficient
and a trace is not required. Archived cases are not required to execute in the
current live run. Archived evidence is complete only when the source and
context, snapshot identities, prior check and discovery evidence, runner and
trace-applicability evidence, and any applicable trace are present. If any
required archived evidence is missing, unstable, or inconsistent, return
`BLOCKED`; do not invent or fabricate prior evidence.
Record separate report rows for current-live cases and archived reassessments,
with their distinct evidence.

For every `MERGE`, identify the source case, a `KEEP` survivor in this same
current audit, the small added assertion, the production line and reachable
path it exercises, and the failure reason that assertion would detect. A merge
may be applied automatically only when its survivor is a current-audit `KEEP`
in the permitted write paths. Otherwise report and withhold the merge. If
multiple authorised merges target one survivor, validate the combined
authorised edits and include those exact edits in the accepted post-prune
snapshot.

The auditor maps every approved behaviour in the task design to retained tests.
Recalculate coverage using decisions actually applied and withheld, not only
proposed decisions. A required approved behaviour without retained coverage is
an Important finding and blocks acceptance. Report unrelated pre-existing
coverage gaps separately without expanding the task. Record the complete
decision inventory and evidence even when no removal or merge is applied.

## Apply supported removals and recover safely

Before assigning any removal or merge, the coordinator records in `workflow.md`
the exact source test or case, its path and surrounding context, the auditor's
decision evidence, and a scoped recovery patch or snapshot. For removal, record
the source and decision evidence. If the criterion requires no survivor,
explicitly record `no survivor required`. Record survivor identity and evidence
only when the decision criterion requires it. For a duplicate `REMOVE`, record
the retained survivor and evidence that it detects the shared defect. For a
`MERGE`, record the current-audit `KEEP` survivor, added assertion, production
line, reachable path, and failure reason. Preserve both source and survivor
context for a merge. Record expected per-file and total discovery-count
changes. If exact source or safe recovery material cannot be preserved, do not
apply the change.

The assigned implementation worker applies only audited removals and
authorised merges. It must not change production code, add tests, perform
unrelated helper cleanup, delete a test file, or remove the last test in a
file. It reports each applied and withheld decision. The coordinator inspects
the actual diff against the audit and allowed writes before accepting it.

Run the post-prune command against stable current-live inputs. Require a fresh,
stable GREEN result with exit status zero. Compare live discovery results and
counts with the recorded expected removals, per file and in total. Confirm that
every live test-bearing file still discovers at least one test and the overall
live command did not succeed with zero discovered tests. For an indirect runner,
capture its current trace and correlate each live case with a trace entry; for a
direct runner, use its actual check and discovery output without requiring a
trace. Archived sources do not contribute to current-live discovery counts or
trace requirements. Unexpected counts, failures, changed inputs, or ownership
violations block acceptance.

If a later reassessment no longer supports a removed source, the coordinator
assigns restoration to the implementation worker using the preserved source
and recovery material. Restore only when reassessment no longer supports
removal, and never overwrite later work. The coordinator must not edit files or
apply restoration directly. Do not use a broad Git restore or reset. If scoped
recovery cannot apply without overwriting later work, stop and ask the user
while preserving the current state. For application or verification failure,
restoration is likewise assigned to the worker and checked against its recorded
recovery.

Missing required behaviour coverage is an Important finding and blocks
acceptance. Return an in-scope correction to the assigned worker for TDD and a
targeted fresh audit;
if the correction is outside the approved task, return to the coordinator for
planning and approval. Unrelated old gaps are reported only.

## Evidence, invalidation, and handoff

The coordinator records the accepted post-prune snapshot in `workflow.md`,
including content identities for retained test files and exercised code,
fixtures, configuration, and resources, plus post-prune commands, outputs,
exit codes, and actual discovery counts. Include exact authorised removal and
merge changes in this snapshot. Record the content difference between the
pre-prune snapshot and this accepted snapshot. That difference must contain
only the exact authorised pruning changes. Exact authorised pruning changes,
including merges, do not invalidate their audit decisions. The original
task-start baseline remains immutable and distinct from both snapshots.

Before acceptance, compare current-live audit inputs with the accepted
post-prune snapshot, not with the pre-prune snapshot. Any additional change to
an audited live test or case, exercised code, fixture, configuration, or
relevant resource invalidates the affected evidence. A changed live test
inventory requires a fresh inventory; changed exercised behaviour inputs
require a targeted audit of affected live cases and survivors. Record
decision-to-survivor dependencies.
Unexpected changes to a survivor cause transitive survivor-dependency
invalidation. After GREEN and stable passing checks for live cases, re-audit the
affected live cases and survivors. For a previously removed source, present its
archived source, context, pre-removal snapshot, and prior trace/check evidence
to the auditor for reassessment; do not require current execution of that
archived case. If required archived context or evidence is missing or unstable,
block reassessment rather than fabricating history. Restore it through scoped
recovery only when reassessment no longer supports removal. Changes to
active-task ownership or survivor stability invalidate affected evidence.
Re-run applicable checks and dispatch a fresh independent audit on stable
inputs only for unexpected changes. Record new recovery material before any
further removal. Do not repeat the audit merely because the accepted snapshot
contains exact authorised changes. Changes outside frozen audit inputs do not
invalidate evidence merely because they are in the same repository. Final
review inspects the audit and accepted snapshot, and repeats neither unless
evidence has been invalidated.

## Auditor prompt template

The coordinator fills every bracketed field from the approved task, actual
diff, stable source, and workflow record before dispatch. Paste the complete
current canonical Meaningful Assertions section into its slot verbatim. Do not
send the prompt with unresolved bracketed fields or make the auditor recover
missing context from session history.

```text
{{DISPATCH_AGENT_TOOL}} ([VERIFIED_TEST_OR_QUALITY_SPECIALIST]):
  description: "Independently audit test pruning for [TASK_ID]"
  prompt: |
    You are an independent, read-only test-pruning auditor. Follow the supplied
    task contract and canonical value rule. Do not edit files, run tests or
    other mutating checks, change workflow state, dispatch another agent, or
    apply removals. Do not infer missing inputs. Return BLOCKED if the supplied
    scope or evidence is incomplete, unstable, or inconsistent. Do not infer
    missing authority or write scope from inherited session history.

    ## Approved task and required behaviours

    Task: [TASK_ID]
    Approved design revision: [DESIGN_REVISION]
    Approved behaviours, each with its requirement identifier:
    [APPROVED_BEHAVIOUR_TO_REQUIREMENT_MAP]

    ## Immutable baseline and audit scope

    Task-start HEAD and baseline source:
    [TASK_START_HEAD_AND_BASELINE_REFERENCE]
    Relevant pre-existing dirty and untracked contents, preserved separately
    from task changes:
    [PRE_EXISTING_CONTENT_IDENTITIES_OR_SNAPSHOTS]
    Actual task-changed paths and evidence used to derive scope:
    [ACTUAL_TASK_DIFF_PATHS_AND_SCOPE_EVIDENCE]
    Active harness, complete instruction source set, identities,
    applicability, and authority frozen for this audit:
    [FROZEN_ACTIVE_INSTRUCTION_SOURCES_AND_IDENTITIES]
    Applicable higher-priority testing instructions in authority order,
    verbatim, with source identities and applicability, or `none` only when the
    complete active higher-priority set is established empty:
    [APPLICABLE_HIGHER_PRIORITY_TESTING_INSTRUCTIONS]
    Applicable project test rules verbatim, or `none` only when the complete
    applicable source set is established empty:
    [APPLICABLE_PROJECT_TEST_RULES]
    Exact permitted write paths for automatic MERGE application:
    [EXACT_PERMITTED_MERGE_WRITE_PATHS]
    Authority and task-scope evidence for those paths:
    [MERGE_WRITE_PATH_AUTHORITY_AND_SCOPE_EVIDENCE]
    Every current-live test-bearing file and every test or parameterised case,
    including older live tests, with archived cases excluded:
    [COMPLETE_FILE_AND_CASE_INVENTORY]
    Exact source and surrounding context for each current-live case:
    [TEST_SOURCE_AND_CONTEXT]
    Archived removed-source reassessments, separate from current-live cases:
    [ARCHIVED_REMOVED_SOURCE_AND_CONTEXT]
    Archived pre-removal snapshot identities:
    [ARCHIVED_PRE_REMOVAL_SNAPSHOT_IDENTITIES]
    Archived actual prior checks and discovery evidence, including commands,
    outputs, exit status, discovery counts, and source identities:
    [ARCHIVED_PRIOR_CHECKS_AND_DISCOVERY_EVIDENCE]
    Archived original runner and evidence establishing whether historical trace
    was applicable:
    [ARCHIVED_ORIGINAL_RUNNER_AND_TRACE_APPLICABILITY]
    Archived prior trace-to-case evidence when the original runner required it,
    or evidence that a direct runner made historical trace inapplicable:
    [ARCHIVED_PRIOR_TRACE_EVIDENCE_IF_APPLICABLE]

    ## Frozen exercised inputs and ownership

    Stable production code, fixtures, configuration, and resources exercised:
    [INPUT_PATHS_AND_CONTENT_IDENTITIES]
    Concurrent writers and test ownership information:
    [ACTIVE_TASK_OWNERSHIP_AND_STABILITY_EVIDENCE]
    Current-live pre-prune commands, exit codes, outputs, and per-file and total
    discovery counts; include trace-to-case evidence when the runner is
    indirect, and direct-runner execution evidence from its check output:
    [PRE_PRUNE_CHECKS_AND_DISCOVERY_COUNTS]
    Planned post-prune live GREEN command, applicable trace capture, and
    discovery-counting method:
    [POST_PRUNE_COMMAND_AND_COUNTING_METHOD]

    ## Canonical value rule, authoritative text

    [PASTE THE COMPLETE CURRENT MEANINGFUL ASSERTIONS SECTION VERBATIM]

    ## Generic category meanings for classification only

    These meanings classify observable test shape only. They are not a
    test-value rule; use the supplied canonical Meaningful Assertions section
    for value decisions. Do not infer KEEP, REMOVE, or MERGE solely from a
    category.

    - Scaffolding: a case that checks renders-without-crashing,
      export/module/type-shape, a literal constant, its own mock, an
      intermediate full-flow step, or redundant input-class cases.
    - Implementation-detail: a case that asserts internal call counts, CSS
      class names, DOM structure, or child props.
    - Duplicate: cases that fail on the same shared production defect.
    - Timing-dependent: a case that relies on real timers or `waitFor` chains
      without a deterministic signal.
    - Wrong-layer: use only when applicable project test rules define the
      category.

    ## Audit

    Assess every current-live test and case in the supplied live inventory using
    the supplied canonical rule and applicable project rules. Archived removed
    sources are not live cases and are not required to execute in the current
    trace. For every archived source require its exact preserved source and
    context, pre-removal snapshot identities, and actual prior check and
    discovery evidence, including commands, outputs, exit status, and counts.
    Establish the original runner and whether a trace was applicable. Require
    historical trace-to-case evidence for an indirect original runner; for a
    direct original runner, prior check and discovery evidence is sufficient
    and no trace is required. If any required archived input or evidence is
    missing, unstable, or inconsistent, return BLOCKED; do not invent or
    fabricate prior evidence. Return separate decisions and evidence for
    current-live cases and archived reassessments.
    Return exactly one KEEP,
    REMOVE, or MERGE decision for each. Identify the category, behaviour,
    rationale, and evidence. For REMOVE decisions, apply the supplied
    category-first rule, then the authorised defect and duplicate criteria.
    Do not claim that inability to name a production defect proves no defect
     exists. For duplicate removal, identify one retained survivor that detects
     the shared defect; do not claim other source defects are preserved unless
     they are. Reject missing, unstable, cyclic, or ownership-uncertain
     survivors and report uncertain coverage.

     Apply supplied higher-priority testing instructions according to their
     authority. If applicable higher-priority testing instructions are missing
     or ambiguous, return BLOCKED. If exact permitted MERGE write paths or their
     scope evidence are missing or ambiguous, return BLOCKED. `none` is valid
     only when the supplied source inventory establishes the complete applicable
     set is empty. Do not use inherited session history to fill missing
     instruction or write-scope inputs.

    For every MERGE, name the source case, its current-audit KEEP survivor, the
    small added assertion, production line, reachable path, and failure reason.
    Recommend automatic application only when the survivor is a current-audit
    KEEP and its path exactly matches an authorised path in the supplied
    permitted-write-path list. If the path is outside the permitted write
    paths, report and withhold the merge. Do not infer permission from the task
    description or session history.
    Identify decision-to-survivor dependencies for later invalidation.

    Map every approved behaviour to retained test identifiers. Mark any
    required approved behaviour without retained coverage as an Important
    finding. Report unrelated gaps separately without proposing scope expansion.
    From the supplied per-file pre-prune counts and proposed removals and
    merges, calculate projected per-file and total post-change counts. Flag a
    projected zero-test file or total as a blocker. The coordinator validates
    counts and records source context plus scoped recovery in workflow.md
    before assigning any change. The recovery record is coordinator owned and
    is created after your audit, before a worker is assigned.
    Do not recommend deleting a file or its last test. You have no authority to
    make edits or delegate this audit.

    ## Required report

    Verdict: READY only when the inventory and evidence are complete and there
    is no Important finding for required behaviour coverage; otherwise BLOCKED.
    Complete inventory: one KEEP, REMOVE, or MERGE row per test or case.
    For each row: path, stable test/case identifier, category, decision, named
    behaviour, rationale, and evidence from the supplied stable inputs.
    For each REMOVE: the applicable reason and any required survivor mapping.
    For each MERGE: source, current-audit KEEP survivor, assertion, production
    line, reachable path, and failure reason, or state that it is withheld.
    Behaviour coverage: each approved behaviour and its retained test IDs, or
    an Important finding when coverage is absent.
    Current-live report rows: one KEEP, REMOVE, or MERGE row per live case,
    with current live source and audit evidence.
    Archived reassessment rows: exact source and context, pre-removal snapshot
    identity, actual prior check/discovery evidence, original runner and trace
    applicability, and prior trace evidence when applicable, plus the decision
    and rationale. If any required archived input is missing or unstable,
    report BLOCKED without fabricating evidence.
    Discovery: confirm current-live per-file and total pre-prune counts are
    non-zero, confirm trace-to-case evidence for current-live indirect runners
    or direct-runner execution evidence, and provide projected current-live
    post-change per-file and total counts or identify the blocker. Archived
    cases are excluded from current discovery and trace counts.
    Stability: list any missing, changing, or ownership-uncertain inputs.
    Unrelated gaps: report only, with no scope expansion.
    Do not claim tests passed, checks ran, files changed, or removals were
    applied. Return evidence and recommendations only.
```
