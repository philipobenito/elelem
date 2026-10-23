// The implementation workflow shipped with skills/work-swarm/SKILL.md.
// The skill constructs the args value; this script owns the control flow and
// enforces the coordination invariants as code: the pre-flight disjointness
// assertion throws, the scheduler treats only verified as satisfied, the fix
// budget is an integer, review-before-verification is control flow, and
// verified has exactly one write site. Agents have no write path into script
// state, so write authority needs no rule.
//
// args (object, or a JSON string of the same shape):
//   repo          absolute path to the repository being implemented in
//   baseSha       the commit the whole feature is measured against
//   suiteCommand  full-suite command run once at reconcile (e.g. "npm test")
//   severityTable optional; overrides the severity calibration embedded below
//   testValueRule the Meaningful Assertions section of rules/common/testing.md,
//                 pasted whole; required when any task prunes, and deliberately
//                 without an embedded default so the rule keeps one home
//   simple        true when the sizing verdict was SIMPLE (one task, no new behaviour)
//   implementerModel / reviewerModel / verifierModel
//                 concrete model names confirmed to exist in the environment;
//                 the reviewer never runs at a lower tier than the implementer;
//                 a task may override implementerModel with its own model field
//   tasks         [{ id, name, files, blockedBy, spec, verifyCommand, model?,
//                    isolated?, codeless?, noTestFramework? }]
//                 files are repo-relative and pairwise disjoint across tasks;
//                 verifyCommand is the task-scoped test command;
//                 isolated: true dispatches the implementer into its own git
//                 worktree (repo must be the session repository root);
//                 codeless: true marks a task whose files carry no production
//                 code, so TDD does not apply and the task's proof is its
//                 verifyCommand; inert when simple is true;
//                 noTestFramework: true marks a task whose files DO carry
//                 production code, in a project that has no test framework for
//                 them, so TDD does not apply and the proof is again the
//                 verifyCommand; mutually exclusive with codeless, which
//                 pre-flight enforces; inert when simple is true

export const meta = {
  name: 'work-swarm',
  description: 'Implement an approved design as file-disjoint tasks with per-task review and verification',
  phases: [
    { title: 'Pre-flight', detail: 'file-disjointness assertion over the whole decomposition' },
    { title: 'Implement', detail: 'one implementer per ready task, waves by blockedBy' },
    { title: 'Prune', detail: 'fresh audit removes tests that catch no defect another test misses' },
    { title: 'Review', detail: 'per-task reviewer, integer fix budget of two' },
    { title: 'Verify', detail: 'task-scoped verification commands' },
    { title: 'Reconcile', detail: 'tree-level ownership check and full suite' },
  ],
}

const input = typeof args === 'string' ? JSON.parse(args) : args
const { repo, baseSha, suiteCommand, simple, tasks } = input
const implementerModel = input.implementerModel
const reviewerModel = input.reviewerModel
const verifierModel = input.verifierModel
const testValueRule = input.testValueRule
const isTddTask = t => !simple && !t.codeless && !t.noTestFramework

const severityTable = input.severityTable || `Critical: broken behaviour, data loss, a security hole, or a violated acceptance criterion; the work cannot ship.
Important: must be fixed before this commits; real correctness or maintainability damage a reviewer should not wave through.
Minor: style, naming, micro-efficiency, and anything else you would still be comfortable shipping.
The test is the shipping question: if a finding would leave you comfortable shipping the change, it is Minor. Reviewers over-flag by default; do not inflate.`

phase('Pre-flight')
const owner = new Map()
for (const t of tasks) {
  if (t.codeless && t.noTestFramework) throw new Error(`pre-flight failure: task ${t.id} sets both codeless and noTestFramework`)
  for (const f of t.files) {
    if (owner.has(f)) throw new Error(`pre-flight failure: ${f} owned by both ${owner.get(f)} and ${t.id}`)
    owner.set(f, t.id)
  }
}
if (tasks.some(isTddTask) && !testValueRule) throw new Error('pre-flight failure: testValueRule is required when any task prunes')
const ids = new Set(tasks.map(t => t.id))
for (const t of tasks) for (const d of t.blockedBy) {
  if (!ids.has(d)) throw new Error(`task ${t.id} blockedBy unknown task ${d}`)
}
log(`pre-flight: ${owner.size} files across ${tasks.length} task(s), pairwise disjoint`)

const IMPL_SCHEMA = {
  type: 'object',
  required: ['status', 'summary', 'behaviour_introduced', 'tdd_evidence', 'files_changed', 'test_command', 'test_exit_code', 'working_directory'],
  properties: {
    status: { enum: ['DONE', 'DONE_WITH_CONCERNS', 'BLOCKED', 'NEEDS_CONTEXT'] },
    summary: { type: 'string' },
    behaviour_introduced: { type: 'string', description: "exactly 'none', or a description of the observable behaviour introduced" },
    tdd_evidence: {
      type: 'array',
      items: {
        type: 'object',
        required: ['behaviour', 'test_name', 'red', 'green'],
        properties: {
          behaviour: { type: 'string' },
          test_name: { type: 'string' },
          red: { type: 'string' },
          green: { type: 'string' },
        },
      },
    },
    files_changed: { type: 'array', items: { type: 'string' } },
    test_command: { type: 'string' },
    test_exit_code: { type: 'integer' },
    working_directory: { type: 'string', description: 'absolute path of the tree actually worked in' },
    concerns: { type: 'string' },
    minor_outcomes: {
      type: 'array',
      items: {
        type: 'object',
        required: ['finding', 'outcome', 'reason'],
        properties: {
          finding: { type: 'string' },
          outcome: { enum: ['FIXED', 'DECLINED'] },
          reason: { type: 'string' },
        },
      },
    },
  },
}

const PRUNE_SCHEMA = {
  type: 'object',
  required: ['baseline_exit_code', 'verdicts', 'withheld', 'uncovered_behaviours', 'files_changed', 'verify_exit_code', 'working_directory'],
  properties: {
    baseline_exit_code: { type: 'integer', description: 'exit code of the verification command run before any removal' },
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'test_name', 'verdict', 'reason'],
        properties: {
          file: { type: 'string' },
          test_name: { type: 'string' },
          verdict: { enum: ['KEEP', 'REMOVE'] },
          reason: { type: 'string' },
          surviving_test: { type: 'string', description: "required on REMOVE, absent on KEEP: 'file :: test name', or 'none' when the removed test could not fail" },
          removed_source: { type: 'string', description: 'required on REMOVE, absent on KEEP: the removed test case, verbatim, so the removal can be reversed' },
        },
      },
    },
    withheld: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'test_name', 'surviving_test'],
        properties: {
          file: { type: 'string' },
          test_name: { type: 'string' },
          surviving_test: { type: 'string' },
        },
      },
    },
    uncovered_behaviours: { type: 'array', items: { type: 'string' } },
    files_changed: { type: 'array', items: { type: 'string' } },
    verify_exit_code: { type: 'integer' },
    working_directory: { type: 'string', description: 'absolute path of the tree actually worked in' },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['verdict', 'findings'],
  properties: {
    verdict: { enum: ['APPROVED', 'ISSUES_FOUND'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'description'],
        properties: {
          severity: { enum: ['Critical', 'Important', 'Minor'] },
          description: { type: 'string' },
          file: { type: 'string' },
        },
      },
    },
    notes: { type: 'string' },
  },
}

const VERIFY_SCHEMA = {
  type: 'object',
  required: ['command', 'exit_code', 'passed', 'failed', 'scoped_changed_paths', 'pass'],
  properties: {
    command: { type: 'string' },
    exit_code: { type: 'integer' },
    passed: { type: 'integer' },
    failed: { type: 'integer' },
    scoped_changed_paths: { type: 'array', items: { type: 'string' } },
    pass: { type: 'boolean' },
  },
}

const RECON_SCHEMA = {
  type: 'object',
  required: ['changed_paths', 'suite_command', 'suite_exit_code', 'passed', 'failed', 'pass'],
  properties: {
    changed_paths: { type: 'array', items: { type: 'string' } },
    suite_command: { type: 'string' },
    suite_exit_code: { type: 'integer' },
    passed: { type: 'integer' },
    failed: { type: 'integer' },
    pass: { type: 'boolean' },
  },
}

const state = {}
for (const t of tasks) state[t.id] = { started: false, verified: false, failed: false }
const results = {}
// An isolated task's implementer works in its own worktree; later agents for
// that task must target the same tree, reported as working_directory.
const treeFor = t => (results[t.id] && results[t.id].tree) || repo

const tddBlock = simple
  ? `## Testing

This work was sized SIMPLE: it introduces no observable behaviour, so there is nothing for a new test to cover and you MUST NOT write one. The existing suite must stay green; run the task's verification command before reporting. If you find the work DOES introduce observable behaviour, that falsifies the sizing: describe it in behaviour_introduced and report honestly rather than quietly writing tests.`
  : `## Testing

For every behaviour in the spec, follow the test-driven cycle: write the failing test FIRST, run it and observe it fail for the right reason (RED), write the minimal production code to pass, observe the pass (GREEN). Capture the evidence per behaviour for your report. Run only the task's own verification command, not the full suite; other agents' work is mid-flight.`

const codelessBlock = `## Testing

This task is marked codeless: its files carry no production code, so there is nothing for TDD to bind and you MUST NOT write tests. The existing suite must stay green; run the task's verification command before reporting. If completing the task requires introducing production code, that falsifies the codeless marking: describe that code in behaviour_introduced and report honestly rather than quietly writing it. On this task, report behaviour_introduced as exactly 'none' unless completing it forced production code; content changes to codeless files are not behaviour.`

const noFrameworkBlock = `## Testing

This task is marked noTestFramework: its files DO carry production code, but this project has no test framework for them, so there is nothing for TDD to bind and the task's proof is its verification command. You MUST NOT write tests and you MUST NOT introduce a test framework, a test runner, or a test dependency. Run the task's verification command before reporting.

Production code IS expected from you here. Do not read this across from a codeless task: describe in behaviour_introduced whatever observable behaviour you introduce, as you would on any ordinary task.

If you find that a test framework capable of hosting a test for these files does exist after all, that falsifies the marking. Report status DONE_WITH_CONCERNS and name the framework and where you found it in concerns, so the reviewer can adjudicate it. Do not quietly write tests in it, and do not quietly skip tests you could have written. The project's own proving command, the verification command you were given, is not itself such a framework.`

function implPrompt(t) {
  return `You are a one-shot implementer. Work ONLY inside the git repository at ${repo}.${t.isolated ? ' You have been given an isolated worktree; your working directory IS your repository, work there and nowhere else.' : ''} All paths below are repo-relative.

## Task ${t.id}: ${t.name}

${t.spec}

## Files you own

You may create or edit ONLY these paths:
${t.files.map(f => '- ' + f).join('\n')}

Other agents may be editing this tree concurrently and own the files you were not given. Do not create, edit, move or delete any path outside your list. If the task cannot be completed without another file, stop and report status BLOCKED with the reason in summary.

${!simple && t.codeless ? codelessBlock : !simple && t.noTestFramework ? noFrameworkBlock : tddBlock}

Task verification command: ${t.verifyCommand}

## Hard rules

- No git commands that write state: no commit, branch, stash, restore, checkout. Read-only git is fine.
- No sudo, no elevated privileges.
- Leave every change uncommitted.

## Report

Return structured output. files_changed MUST list exactly the repo-relative paths you created or edited and MUST be a subset of the owned list. behaviour_introduced is exactly 'none' or a description of observable behaviour you introduced. working_directory is the absolute path of the tree you worked in (run pwd). Status: DONE, DONE_WITH_CONCERNS (completed but doubtful, say why in concerns), BLOCKED (cannot complete), NEEDS_CONTEXT (the spec is missing a decision; never guess one).`
}

function prunePrompt(t, impl) {
  const scope = impl.files_changed
  const otherTasksFiles = tasks.filter(o => o.id !== t.id).flatMap(o => o.files)
  return `You are a one-shot test auditor. Work ONLY inside the git repository at ${treeFor(t)}. All paths below are repo-relative. Every test in scope must earn its place.

## Task ${t.id}: ${t.name}

${t.spec}

## What the implementer built

Behaviour introduced: ${impl.behaviour_introduced}

Tests the implementer wrote for it:
${impl.tdd_evidence.map(e => `- ${e.test_name}: ${e.behaviour}`).join('\n')}

## The rule

${testValueRule}

## Files in scope

Audit every test in these files, whether the implementer added it or it existed before:
${scope.map(f => '- ' + f).join('\n')}

## Baseline

Before removing anything, run the task's verification command and report its exit code as baseline_exit_code: ${t.verifyCommand}

If it is non-zero, stop there. A pruned suite can only be judged against a green one. Remove nothing, and report empty verdicts, withheld, uncovered_behaviours and files_changed, with verify_exit_code equal to baseline_exit_code. The reviewer picks up the failing suite.

## For each test

1. Name the concrete defect in the production code that makes this test fail. If you cannot name one, the test cannot fail: its verdict is REMOVE with surviving_test 'none'.
2. Look for another test that also fails on that defect.
3. If one exists, the verdict is REMOVE, with that test as surviving_test in the form 'file :: test name'. Otherwise the verdict is KEEP, with the defect only this test catches as reason.

A surviving test is valid only when it is a KEEP in this audit, sits in a file outside the files in scope that no other task in this run owns, or is 'none' because the removed test cannot fail. These files belong to other tasks, which are pruning at the same time, so they are NEVER valid survivors:
${otherTasksFiles.length ? otherTasksFiles.map(f => '- ' + f).join('\n') : '- none'}

Check every REMOVE against that rule before applying anything. Two duplicates that each name the other cannot both be removed: keep one.

## Applying the verdicts

Apply every REMOVE by deleting that test case. Before deleting it, copy the whole test case verbatim into removed_source, so the removal can be reversed without touching anything else in the file. Edit ONLY the files in scope above. Remove test code only: write no new tests and change no production behaviour. An inline test module inside a production file is test code. Never delete a file. If removing a test would leave its file with no tests, do not remove it: list it in withheld instead, and leave it out of verdicts.

Then run the task's verification command and report its exit code as verify_exit_code: ${t.verifyCommand}

## Coverage

Map the behaviour introduced to the tests that still cover it after your removals. List every behaviour with no covering test in uncovered_behaviours. Do not write a test for it: the reviewer sends it back to the implementer.

## Hard rules

- No git commands that write state: no commit, branch, stash, restore, checkout. Read-only git is fine.
- No sudo, no elevated privileges.
- Leave every change uncommitted.

## Report

Return structured output. verdicts lists every test you audited except the withheld ones. surviving_test and removed_source are required on every REMOVE and absent on every KEEP. files_changed MUST list exactly the repo-relative paths you edited. working_directory is the absolute path of the tree you worked in (run pwd).`
}

function testAuditSection(t) {
  const tr = results[t.id]
  if (!tr || !tr.prune) return ''
  const removed = tr.prune.verdicts.filter(v => v.verdict === 'REMOVE')
  const list = items => items.length ? items.join('\n') : '- none'
  const uncoveredInstruction = tr.rounds === 0
    ? 'The orchestrator raises each of these as an Important finding on this review, so do not report them yourself.'
    : 'Raise an Important finding for each of these that still has no covering test.'
  return `

## The test audit

A fresh auditor pruned the tests in this task's changed files before this review. Every remaining test should catch a defect no other test catches.

Removed tests, each with the surviving test it relied on:
${list(removed.map(v => `- ${v.file} :: ${v.test_name}, survivor ${v.surviving_test}`))}

For each removed test with a named survivor, check that the survivor exists and fails on the same defect. For each test removed with survivor 'none', check that the removed test genuinely could not fail. If either check does not hold, the behaviour is untested: raise an Important finding. The tests listed above as removed are gone on purpose. Do not report them as missing.

Withheld, because removing them would have left their file with no tests:
${list(tr.prune.withheld.map(w => `- ${w.file} :: ${w.test_name}, survivor ${w.surviving_test}`))}

Behaviours the auditor found with no covering test:
${list(tr.prune.uncovered_behaviours.map(b => '- ' + b))}

${uncoveredInstruction}`
}

function withUncoveredFindings(review, prune) {
  if (!prune || !prune.uncovered_behaviours.length) return review
  const uncovered = prune.uncovered_behaviours.map(b => ({ severity: 'Important', description: `UNCOVERED: the test prune left no test for this behaviour: ${b}` }))
  return { ...review, verdict: 'ISSUES_FOUND', findings: [...review.findings, ...uncovered] }
}

function reviewPrompt(t, impl) {
  return `You are a code reviewer, the last gate before this work is accepted. The repository to review is at ${treeFor(t)}.

Review the UNCOMMITTED working-tree state scoped to exactly these files (repo-relative):
${t.files.map(f => '- ' + f).join('\n')}

New files are untracked, and untracked files are invisible to plain "git diff": run git status --porcelain -uall -- <the files> to see what exists, git diff -- <the files> for tracked changes, and READ every scoped file in full.

## The task specification the work must satisfy

${t.spec}

## The implementer's report

Status: ${impl.status}
Summary: ${impl.summary}
Behaviour introduced: ${impl.behaviour_introduced}
Concerns: ${impl.concerns || 'none reported'}
Minor findings declined, each with the implementer's reason, which you may accept or contest at a higher severity: ${(impl.minor_outcomes || []).filter(o => o.outcome === 'DECLINED').map(o => `${o.finding} (${o.reason})`).join('; ') || 'none'}

## What to check

1. Spec compliance: every acceptance criterion is met. A missing criterion is Critical.
2. Correctness: edge cases the spec names, and the ones it obviously implies.
3. ${!simple && (t.codeless || t.noTestFramework) ? `Verification: run the task's verification command yourself: ${t.verifyCommand}` : `Tests: they genuinely exercise the specified behaviours; run the task's verification command yourself: ${t.verifyCommand}`}
4. Scope: nothing changed that the spec did not ask for.
5. Quality: naming, clarity, consistency with the surrounding codebase.
${simple ? `6. Sizing: this work was sized SIMPLE, meaning uniform mechanical change, no new logic, no new interfaces, no observable behaviour, under 40 substantive lines. You are reading the code the sizing predicted, so your evidence outranks the prediction. If any of that does not hold, including a new test appearing, return ISSUES_FOUND with a Critical finding whose description begins 'SIZING:' and names what does not hold. Absent new tests are correct on SIMPLE work; do not report their absence.` : t.codeless ? `6. Codeless: this task is marked codeless, meaning its files carry no production code and no tests. You are reading the diff the marking predicted, so your evidence outranks the prediction. If the diff introduces production code or tests, return ISSUES_FOUND with a Critical finding whose description begins 'CODELESS:' and names what appeared. Absent new tests are correct on a codeless task; do not report their absence.` : t.noTestFramework ? `6. Test framework: this task is marked noTestFramework, meaning its files carry production code and this project has no test framework for them, so its verification command is its proof. You are reading the diff the marking predicted, so your evidence outranks the prediction. If the diff introduces tests, a test runner or a test dependency, or if you find an existing test framework in this project that could host a test for these files, return ISSUES_FOUND with a Critical finding whose description begins 'FRAMEWORK:' and names what you found. Two things this check is NOT. Absent new tests are correct on this task; do not report their absence. And the project's own proving command, including the verification command named above, is not itself a test framework; its existence does not falsify the marking. Production code IS expected on this task, unlike a codeless one, so do not report its presence as a problem.` : ''}${testAuditSection(t)}

## Severity calibration

${severityTable}

Verdict is APPROVED only when there are no Critical and no Important findings. Minor findings may accompany an APPROVED verdict; do not inflate severity to charge the fix budget.`
}

function fixPrompt(t, review) {
  const line = f => `- [${f.severity}] ${f.description}`
  const blocking = review.findings.filter(f => f.severity !== 'Minor').map(line).join('\n')
  const minor = review.findings.filter(f => f.severity === 'Minor').map(line).join('\n')
  return `You are a one-shot implementer fixing review findings. Work ONLY inside the git repository at ${treeFor(t)}.

## Task ${t.id}: ${t.name} (fix round)

The original specification:

${t.spec}

A reviewer examined the current uncommitted state of the owned files and ${blocking ? 'rejected it' : 'approved it with Minor findings'}:

${[blocking, minor].filter(Boolean).join('\n')}

## Files you own

You may create or edit ONLY these paths:
${t.files.map(f => '- ' + f).join('\n')}

Fix every Critical and Important finding. Minor findings are assessed on merit, not deferred: fix each one where the fix makes sense inside the files you own, otherwise decline it and state the reason. "It is only Minor" is not a reason. Report every Minor finding in minor_outcomes as FIXED or DECLINED with its reason, quoting the finding text verbatim. Keep the discipline that applies to this task: ${simple ? 'the work is sized SIMPLE, so introduce no new behaviour and no new tests; the suite stays green.' : t.codeless ? 'the task is marked codeless: introduce no production code and no tests; the verification command must pass.' : t.noTestFramework ? 'the task is marked noTestFramework: production code is expected, but introduce no tests and no test framework; the verification command must pass.' : 'if a finding reveals untested behaviour, add the failing test first, observe RED, fix, observe GREEN.'} Run the task's verification command: ${t.verifyCommand}

No git write commands, no sudo, leave changes uncommitted. Report via structured output as before.`
}

function verifyPrompt(t) {
  return `You are a verification agent. You change nothing; you run commands and report facts. The repository is at ${treeFor(t)}.

1. Run the task's verification command from the repository root: ${t.verifyCommand}
   Capture the exit code and the passed and failed counts.
2. Run: git status --porcelain -uall -- ${t.files.join(' ')}
   (-uall matters: without it untracked directories are collapsed.) Return every listed file path as scoped_changed_paths.

pass is true only if the exit code is 0 and failed is 0. Do not edit any file. Do not run the full suite.`
}

function reconPrompt() {
  return `You are a verification agent. You change nothing; you run commands and report facts. The repository is at ${repo}.

1. Run: git status --porcelain -uall
   Return EVERY modified or untracked file path (repo-relative) as changed_paths. Directories are not paths; list files.
2. Run the full suite from the repository root: ${suiteCommand}
   Capture the exit code and the passed and failed counts.

pass is true only if the exit code is 0 and failed is 0. Do not edit any file.`
}

async function runPrune(t, impl, tr) {
  const fail = failure => { state[t.id].failed = true; tr.failure = failure; return false }
  const prune = await agent(prunePrompt(t, impl), { label: `prune:${t.id}`, phase: 'Prune', schema: PRUNE_SCHEMA, model: reviewerModel })
  if (!prune) return fail('prune dispatch died')
  const strayPrune = prune.files_changed.filter(p => !t.files.includes(p))
  if (strayPrune.length) {
    tr.prune = prune
    return fail(`ownership violation in prune: ${strayPrune.join(', ')}`)
  }
  if (prune.baseline_exit_code !== 0 && prune.files_changed.length) {
    tr.prune = prune
    return fail(`prune edited files despite a red baseline: ${prune.files_changed.join(', ')}`)
  }
  if (prune.baseline_exit_code !== 0) {
    tr.pruneSkipped = `suite red before the prune: exit code ${prune.baseline_exit_code}`
    return true
  }
  tr.prune = prune
  if (prune.verdicts.some(v => v.verdict === 'REMOVE' && !(v.surviving_test && v.removed_source))) return fail('prune verdict incomplete: a REMOVE lacks surviving_test or removed_source')
  if (prune.verify_exit_code !== 0) return fail(`verification failed after prune: exit code ${prune.verify_exit_code}`)
  return true
}

async function runTask(t) {
  let fixBudget = 2
  const tr = { taskId: t.id, rounds: 0 }
  results[t.id] = tr

  const implOpts = { label: `impl:${t.id}`, phase: 'Implement', schema: IMPL_SCHEMA, model: t.model || implementerModel }
  if (t.isolated) implOpts.isolation = 'worktree'
  const impl = await agent(implPrompt(t), implOpts)
  if (!impl) { state[t.id].failed = true; tr.failure = 'implementer dispatch died'; return }
  tr.impl = impl
  if (t.isolated) tr.tree = impl.working_directory
  if (impl.status === 'BLOCKED' || impl.status === 'NEEDS_CONTEXT') {
    state[t.id].failed = true; tr.failure = `implementer reported ${impl.status}`; return
  }
  const stray = impl.files_changed.filter(p => !t.files.includes(p))
  if (stray.length) { state[t.id].failed = true; tr.failure = `ownership violation claimed: ${stray.join(', ')}`; return }
  if (simple && impl.behaviour_introduced !== 'none') {
    state[t.id].failed = true; tr.failure = `sizing falsified: implementer reports new behaviour: ${impl.behaviour_introduced}`; tr.sizingFalsified = true; return
  }
  if (!simple && t.codeless && impl.behaviour_introduced !== 'none') {
    state[t.id].failed = true; tr.failure = `codeless falsified: implementer reports production code: ${impl.behaviour_introduced}`; tr.codelessFalsified = true; return
  }
  if (isTddTask(t) && !impl.tdd_evidence.length) {
    state[t.id].failed = true; tr.failure = 'no TDD evidence in report'; return
  }
  if (isTddTask(t) && !(await runPrune(t, impl, tr))) return

  let review = await agent(reviewPrompt(t, impl), { label: `review:${t.id}`, phase: 'Review', schema: REVIEW_SCHEMA, model: reviewerModel })
  if (!review) { state[t.id].failed = true; tr.failure = 'reviewer dispatch died'; return }
  const sizingFinding = r => r.findings.find(f => f.description.startsWith('SIZING:'))
  const codelessFinding = r => r.findings.find(f => f.description.startsWith('CODELESS:'))
  const frameworkFinding = r => r.findings.find(f => f.description.startsWith('FRAMEWORK:'))
  if (simple && sizingFinding(review)) {
    state[t.id].failed = true; tr.failure = `sizing falsified by reviewer: ${sizingFinding(review).description}`; tr.sizingFalsified = true; return
  }
  if (!simple && t.codeless && codelessFinding(review)) {
    state[t.id].failed = true; tr.failure = `codeless falsified by reviewer: ${codelessFinding(review).description}`; tr.codelessFalsified = true; return
  }
  if (!simple && t.noTestFramework && frameworkFinding(review)) {
    state[t.id].failed = true; tr.failure = `noTestFramework falsified by reviewer: ${frameworkFinding(review).description}`; tr.frameworkFalsified = true; return
  }
  review = withUncoveredFindings(review, tr.prune)
  tr.minorOutcomes = []
  const minorFed = new Set()
  let minorAssessed = false
  const minorOf = r => r.findings.filter(f => f.severity === 'Minor')
  const needsFixRound = r => r.verdict === 'ISSUES_FOUND' && r.findings.some(f => f.severity !== 'Minor')
  const needsMinorRound = r => !minorAssessed && fixBudget > 0 && minorOf(r).length > 0
  while (needsFixRound(review) || needsMinorRound(review)) {
    const minorOnly = !needsFixRound(review)
    if (!minorOnly) {
      if (fixBudget === 0) { state[t.id].failed = true; tr.failure = 'fix budget exhausted at review'; tr.lastReview = review; return }
      fixBudget--
    }
    if (minorOf(review).length) minorAssessed = true
    minorOf(review).forEach(f => minorFed.add(f.description))
    tr.rounds++
    const fix = await agent(fixPrompt(t, review), { label: `fix:${t.id}:r${tr.rounds}`, phase: 'Review', schema: IMPL_SCHEMA, model: t.model || implementerModel })
    if (!fix) { state[t.id].failed = true; tr.failure = 'fix dispatch died'; return }
    const strayFix = fix.files_changed.filter(p => !t.files.includes(p))
    if (strayFix.length) { state[t.id].failed = true; tr.failure = `ownership violation in fix: ${strayFix.join(', ')}`; return }
    tr.minorOutcomes.push(...(fix.minor_outcomes || []))
    if (minorOnly && fix.files_changed.length === 0) break
    review = await agent(reviewPrompt(t, fix), { label: `re-review:${t.id}:r${tr.rounds}`, phase: 'Review', schema: REVIEW_SCHEMA, model: reviewerModel })
    if (!review) { state[t.id].failed = true; tr.failure = 'reviewer dispatch died on re-review'; return }
    if (simple && sizingFinding(review)) {
      state[t.id].failed = true; tr.failure = `sizing falsified by reviewer: ${sizingFinding(review).description}`; tr.sizingFalsified = true; return
    }
    if (!simple && t.codeless && codelessFinding(review)) {
      state[t.id].failed = true; tr.failure = `codeless falsified by reviewer: ${codelessFinding(review).description}`; tr.codelessFalsified = true; return
    }
    if (!simple && t.noTestFramework && frameworkFinding(review)) {
      state[t.id].failed = true; tr.failure = `noTestFramework falsified by reviewer: ${frameworkFinding(review).description}`; tr.frameworkFalsified = true; return
    }
  }
  tr.review = review
  const findingKey = s => s.replace(/^-?\s*\[Minor\]\s*/, '').trim()
  const reported = new Set(tr.minorOutcomes.map(o => findingKey(o.finding)))
  const unassessedReason = d => minorFed.has(d) ? 'fed to a fix round, no outcome reported'
    : minorAssessed ? 'raised after this task\'s one Minor assessment'
    : 'no fix budget left to cover a re-review'
  const minorSeen = new Set([...minorFed, ...minorOf(review).map(f => f.description)])
  tr.minorOutcomes.push(...[...minorSeen].filter(d => !reported.has(findingKey(d))).map(d => ({ finding: d, outcome: 'UNASSESSED', reason: unassessedReason(d) })))

  let verify = await agent(verifyPrompt(t), { label: `verify:${t.id}`, phase: 'Verify', schema: VERIFY_SCHEMA, model: verifierModel })
  if (!verify) { state[t.id].failed = true; tr.failure = 'verify dispatch died'; return }
  if (!verify.pass) {
    if (fixBudget === 0) { state[t.id].failed = true; tr.failure = 'fix budget exhausted at verification'; tr.verify = verify; return }
    fixBudget--
    tr.rounds++
    const fix = await agent(fixPrompt(t, { findings: [{ severity: 'Critical', description: `verification failed: ${verify.command} exited ${verify.exit_code} with ${verify.failed} failing` }] }), { label: `fix:${t.id}:verify`, phase: 'Verify', schema: IMPL_SCHEMA, model: t.model || implementerModel })
    if (!fix) { state[t.id].failed = true; tr.failure = 'fix dispatch died at verification'; return }
    // Every fix re-enters at code review; unreviewed code never reaches the gate.
    const reReview = await agent(reviewPrompt(t, fix), { label: `re-review:${t.id}:verify`, phase: 'Verify', schema: REVIEW_SCHEMA, model: reviewerModel })
    if (!reReview || (reReview.verdict === 'ISSUES_FOUND' && reReview.findings.some(f => f.severity !== 'Minor'))) {
      state[t.id].failed = true; tr.failure = 'post-verification fix failed re-review'; return
    }
    verify = await agent(verifyPrompt(t), { label: `re-verify:${t.id}`, phase: 'Verify', schema: VERIFY_SCHEMA, model: verifierModel })
    if (!verify || !verify.pass) { state[t.id].failed = true; tr.failure = 'verification failed after fix'; tr.verify = verify; return }
  }
  tr.verify = verify
  tr.fixBudgetRemaining = fixBudget
  state[t.id].verified = true
}

let waves = 0
while (true) {
  const ready = tasks.filter(t =>
    !state[t.id].started && !state[t.id].failed &&
    t.blockedBy.every(d => state[d].verified))
  if (!ready.length) break
  waves++
  for (const t of ready) state[t.id].started = true
  log(`wave ${waves}: ${ready.map(t => t.id).join(', ')} dispatched in parallel`)
  await parallel(ready.map(t => () => runTask(t)))
}
const unreached = tasks.filter(t => !state[t.id].started).map(t => t.id)

phase('Reconcile')
// The reconcile sweep runs against the shared tree. Isolated tasks' changes
// sit in their worktrees until the lead merges at the drain, so their files
// are legitimately absent here.
const recon = await agent(reconPrompt(), { label: 'reconcile', phase: 'Reconcile', schema: RECON_SCHEMA, model: verifierModel })
const sharedUnion = new Set(tasks.filter(t => !t.isolated).flatMap(t => t.files))
const rogue = recon ? recon.changed_paths.filter(p => !sharedUnion.has(p)) : ['reconcile agent died']
if (rogue.length) log(`ROGUE PATHS: ${rogue.join(', ')} changed in the tree but owned by no task`)

log(`output tokens spent: ${budget.spent()}`)

return {
  baseSha,
  waves,
  state,
  results,
  unreachedTasks: unreached,
  sizingFalsified: tasks.some(t => results[t.id] && results[t.id].sizingFalsified),
  codelessFalsified: tasks.some(t => results[t.id] && results[t.id].codelessFalsified),
  frameworkFalsified: tasks.some(t => results[t.id] && results[t.id].frameworkFalsified),
  reconcile: recon,
  rogueChanges: rogue,
  outputTokensSpent: budget.spent(),
}
