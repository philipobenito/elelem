// The implementation workflow shipped with skills/orchestrated-implementation/SKILL.md.
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
//   simple        true when the sizing verdict was SIMPLE (one task, no new behaviour)
//   implementerModel / reviewerModel / verifierModel
//                 concrete model names confirmed to exist in the environment;
//                 the reviewer never runs at a lower tier than the implementer;
//                 a task may override implementerModel with its own model field
//   tasks         [{ id, name, files, blockedBy, spec, verifyCommand, model?, isolated? }]
//                 files are repo-relative and pairwise disjoint across tasks;
//                 verifyCommand is the task-scoped test command;
//                 isolated: true dispatches the implementer into its own git
//                 worktree (repo must be the session repository root)

export const meta = {
  name: 'orchestrated-implementation',
  description: 'Implement an approved design as file-disjoint tasks with per-task review and verification',
  phases: [
    { title: 'Pre-flight', detail: 'file-disjointness assertion over the whole decomposition' },
    { title: 'Implement', detail: 'one implementer per ready task, waves by blockedBy' },
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

const severityTable = input.severityTable || `Critical: broken behaviour, data loss, a security hole, or a violated acceptance criterion; the work cannot ship.
Important: must be fixed before this commits; real correctness or maintainability damage a reviewer should not wave through.
Minor: style, naming, micro-efficiency, and anything else you would still be comfortable shipping.
The test is the shipping question: if a finding would leave you comfortable shipping the change, it is Minor. Reviewers over-flag by default; do not inflate.`

phase('Pre-flight')
const owner = new Map()
for (const t of tasks) {
  for (const f of t.files) {
    if (owner.has(f)) throw new Error(`pre-flight failure: ${f} owned by both ${owner.get(f)} and ${t.id}`)
    owner.set(f, t.id)
  }
}
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

function implPrompt(t) {
  return `You are a one-shot implementer. Work ONLY inside the git repository at ${repo}.${t.isolated ? ' You have been given an isolated worktree; your working directory IS your repository, work there and nowhere else.' : ''} All paths below are repo-relative.

## Task ${t.id}: ${t.name}

${t.spec}

## Files you own

You may create or edit ONLY these paths:
${t.files.map(f => '- ' + f).join('\n')}

Other agents may be editing this tree concurrently and own the files you were not given. Do not create, edit, move or delete any path outside your list. If the task cannot be completed without another file, stop and report status BLOCKED with the reason in summary.

${tddBlock}

Task verification command: ${t.verifyCommand}

## Hard rules

- No git commands that write state: no commit, branch, stash, restore, checkout. Read-only git is fine.
- No sudo, no elevated privileges.
- Leave every change uncommitted.

## Report

Return structured output. files_changed MUST list exactly the repo-relative paths you created or edited and MUST be a subset of the owned list. behaviour_introduced is exactly 'none' or a description of observable behaviour you introduced. working_directory is the absolute path of the tree you worked in (run pwd). Status: DONE, DONE_WITH_CONCERNS (completed but doubtful, say why in concerns), BLOCKED (cannot complete), NEEDS_CONTEXT (the spec is missing a decision; never guess one).`
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

## What to check

1. Spec compliance: every acceptance criterion is met. A missing criterion is Critical.
2. Correctness: edge cases the spec names, and the ones it obviously implies.
3. Tests: they genuinely exercise the specified behaviours; run the task's verification command yourself: ${t.verifyCommand}
4. Scope: nothing changed that the spec did not ask for.
5. Quality: naming, clarity, consistency with the surrounding codebase.
${simple ? `6. Sizing: this work was sized SIMPLE, meaning uniform mechanical change, no new logic, no new interfaces, no observable behaviour, under 40 substantive lines. You are reading the code the sizing predicted, so your evidence outranks the prediction. If any of that does not hold, including a new test appearing, return ISSUES_FOUND with a Critical finding whose description begins 'SIZING:' and names what does not hold. Absent new tests are correct on SIMPLE work; do not report their absence.` : ''}

## Severity calibration

${severityTable}

Verdict is APPROVED only when there are no Critical and no Important findings. Minor findings may accompany an APPROVED verdict; do not inflate severity to force a fix round.`
}

function fixPrompt(t, review) {
  const items = review.findings.filter(f => f.severity !== 'Minor').map(f => `- [${f.severity}] ${f.description}`).join('\n')
  return `You are a one-shot implementer fixing review findings. Work ONLY inside the git repository at ${treeFor(t)}.

## Task ${t.id}: ${t.name} (fix round)

The original specification:

${t.spec}

A reviewer examined the current uncommitted state of the owned files and rejected it:

${items}

## Files you own

You may create or edit ONLY these paths:
${t.files.map(f => '- ' + f).join('\n')}

Fix every finding. Keep the discipline that applies to this task: ${simple ? 'the work is sized SIMPLE, so introduce no new behaviour and no new tests; the suite stays green.' : 'if a finding reveals untested behaviour, add the failing test first, observe RED, fix, observe GREEN.'} Run the task's verification command: ${t.verifyCommand}

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
  if (!simple && !impl.tdd_evidence.length) {
    state[t.id].failed = true; tr.failure = 'no TDD evidence in report'; return
  }

  let review = await agent(reviewPrompt(t, impl), { label: `review:${t.id}`, phase: 'Review', schema: REVIEW_SCHEMA, model: reviewerModel })
  if (!review) { state[t.id].failed = true; tr.failure = 'reviewer dispatch died'; return }
  const sizingFinding = r => r.findings.find(f => f.description.startsWith('SIZING:'))
  if (simple && sizingFinding(review)) {
    state[t.id].failed = true; tr.failure = `sizing falsified by reviewer: ${sizingFinding(review).description}`; tr.sizingFalsified = true; return
  }
  while (review.verdict === 'ISSUES_FOUND' && review.findings.some(f => f.severity !== 'Minor')) {
    if (fixBudget === 0) { state[t.id].failed = true; tr.failure = 'fix budget exhausted at review'; tr.lastReview = review; return }
    fixBudget--
    tr.rounds++
    const fix = await agent(fixPrompt(t, review), { label: `fix:${t.id}:r${tr.rounds}`, phase: 'Review', schema: IMPL_SCHEMA, model: t.model || implementerModel })
    if (!fix) { state[t.id].failed = true; tr.failure = 'fix dispatch died'; return }
    const strayFix = fix.files_changed.filter(p => !t.files.includes(p))
    if (strayFix.length) { state[t.id].failed = true; tr.failure = `ownership violation in fix: ${strayFix.join(', ')}`; return }
    review = await agent(reviewPrompt(t, fix), { label: `re-review:${t.id}:r${tr.rounds}`, phase: 'Review', schema: REVIEW_SCHEMA, model: reviewerModel })
    if (!review) { state[t.id].failed = true; tr.failure = 'reviewer dispatch died on re-review'; return }
    if (simple && sizingFinding(review)) {
      state[t.id].failed = true; tr.failure = `sizing falsified by reviewer: ${sizingFinding(review).description}`; tr.sizingFalsified = true; return
    }
  }
  tr.review = review
  tr.deferredMinor = review.findings.filter(f => f.severity === 'Minor')

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
  reconcile: recon,
  rogueChanges: rogue,
  outputTokensSpent: budget.spent(),
}
