export const meta = {
  name: 'orchestrated-implementation-prototype',
  description: 'Prototype for elelem issue 21: run file-disjoint implementation tasks with mechanically enforced invariants',
  phases: [
    { title: 'Pre-flight', detail: 'file-disjointness assertion over the whole decomposition' },
    { title: 'Implement', detail: 'one implementer per ready task, waves by blockedBy' },
    { title: 'Review', detail: 'per-task reviewer, integer fix budget of 2' },
    { title: 'Verify', detail: 'scoped test run per task' },
    { title: 'Reconcile', detail: 'global ownership check, full suite, feature-level review' },
  ],
}

const input = typeof args === 'string' ? JSON.parse(args) : args
const { repo, baseSha, tasks } = input

// ---- Invariant: pre-flight ownership disjointness. Mechanical: throws. ----
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
log(`pre-flight: ${owner.size} files across ${tasks.length} tasks, pairwise disjoint; dependency edges valid`)

const IMPL_SCHEMA = {
  type: 'object',
  required: ['status', 'summary', 'tdd_evidence', 'files_changed', 'test_command', 'test_exit_code'],
  properties: {
    status: { enum: ['DONE', 'DONE_WITH_CONCERNS', 'BLOCKED', 'NEEDS_CONTEXT'] },
    summary: { type: 'string' },
    tdd_evidence: {
      type: 'array',
      items: {
        type: 'object',
        required: ['behaviour', 'test_name', 'red', 'green'],
        properties: {
          behaviour: { type: 'string' },
          test_name: { type: 'string' },
          red: { type: 'string', description: 'observed failing output, first line' },
          green: { type: 'string', description: 'observed passing output, N/N passed' },
        },
      },
    },
    files_changed: { type: 'array', items: { type: 'string' } },
    test_command: { type: 'string' },
    test_exit_code: { type: 'integer' },
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
  required: ['test_command', 'exit_code', 'passed', 'failed', 'scoped_changed_paths', 'pass'],
  properties: {
    test_command: { type: 'string' },
    exit_code: { type: 'integer' },
    passed: { type: 'integer' },
    failed: { type: 'integer' },
    scoped_changed_paths: { type: 'array', items: { type: 'string' } },
    pass: { type: 'boolean' },
  },
}

const RECON_SCHEMA = {
  type: 'object',
  required: ['changed_paths', 'full_suite_command', 'full_suite_exit_code', 'passed', 'failed', 'pass'],
  properties: {
    changed_paths: { type: 'array', items: { type: 'string' }, description: 'every modified or untracked path in the repo, repo-relative' },
    full_suite_command: { type: 'string' },
    full_suite_exit_code: { type: 'integer' },
    passed: { type: 'integer' },
    failed: { type: 'integer' },
    pass: { type: 'boolean' },
  },
}

function implPrompt(t) {
  return `You are a one-shot implementer. Work ONLY inside the git repository at ${repo}. All paths below are relative to it.

## Task ${t.id}: ${t.name}

${t.spec}

## Files you own

You may create or edit ONLY these paths:
${t.files.map(f => '- ' + f).join('\n')}

Other agents are editing this same working tree concurrently and own the files you were not given. Do not create, edit, move or delete any path outside your list. If the task cannot be completed without touching another file, stop and report status BLOCKED with an explanation in summary.

## Method: test-driven development

For each behaviour in the spec: write the failing test FIRST, run it and observe it fail for the right reason (RED), write the minimal production code to pass, run it and observe the pass (GREEN). Capture the evidence per behaviour for your report.

Run only your own test file (for example: cd ${repo} && node --test ${t.testFile}). Do NOT run the full suite; other agents' work is mid-flight and their failures are not yours to see.

## Hard rules

- No git commands that write state: no commit, branch, stash, restore, checkout. Read-only git (status, diff, log) is fine.
- No sudo, no elevated privileges.
- Leave every change uncommitted.

## Report

Return structured output. files_changed MUST list exactly the paths you created or edited (repo-relative) and MUST be a subset of the owned list above. tdd_evidence MUST carry one entry per behaviour with the observed RED line and the observed GREEN line. status is DONE, DONE_WITH_CONCERNS (completed but doubtful), BLOCKED (cannot complete), or NEEDS_CONTEXT (the spec is missing a decision).`
}

function reviewPrompt(t, impl) {
  return `You are a code reviewer, the last gate before this work is accepted. The repository is at ${repo}.

Review the UNCOMMITTED working-tree state scoped to exactly these files (repo-relative):
${t.files.map(f => '- ' + f).join('\n')}

These files are almost certainly NEW and therefore untracked: plain "git diff" will NOT show them. Use: cd ${repo} && git status --porcelain -- ${t.files.join(' ')} to see what exists, then READ each file's full contents.

## The task specification the work must satisfy

${t.spec}

## The implementer's report

Status: ${impl.status}
Summary: ${impl.summary}
Claimed files changed: ${impl.files_changed.join(', ')}
Concerns: ${impl.concerns || 'none reported'}

## What to check

1. Spec compliance: every acceptance criterion in the specification is met. Missing criteria are Critical.
2. Correctness: the code does what it claims for edge cases the spec names.
3. Tests: they genuinely exercise the specified behaviours (run them yourself: cd ${repo} && node --test ${t.testFile}). Vacuous or missing tests are Important.
4. Scope: nothing in the scoped file set that the spec did not ask for.
5. Quality: naming, clarity, idiomatic modern JavaScript (ES modules, const, strict equality).

Severity calibration: Critical means broken or spec-violating. Important means must be fixed before commit. Minor means you would still be comfortable shipping; if a finding would leave you comfortable shipping, it is Minor. Do not inflate.

Verdict is APPROVED only when there are no Critical and no Important findings. Minor findings may accompany an APPROVED verdict.`
}

function fixPrompt(t, review) {
  const items = review.findings.filter(f => f.severity !== 'Minor').map(f => `- [${f.severity}] ${f.description}`).join('\n')
  return `You are a one-shot implementer fixing review findings. Work ONLY inside the git repository at ${repo}.

## Task ${t.id}: ${t.name} (fix round)

The original specification:

${t.spec}

A reviewer examined the current uncommitted state of your owned files and rejected it with these findings:

${items}

## Files you own

You may create or edit ONLY these paths:
${t.files.map(f => '- ' + f).join('\n')}

Fix every finding listed. Keep the test-first discipline: if a finding reveals untested behaviour, add the failing test first, observe RED, fix, observe GREEN. Run only your own test file: cd ${repo} && node --test ${t.testFile}.

No git write commands, no sudo, leave changes uncommitted. Report via structured output as before; files_changed lists what you touched this round.`
}

function verifyPrompt(t) {
  return `You are a verification agent. You change nothing; you run commands and report facts. The repository is at ${repo}.

1. Run: cd ${repo} && node --test ${t.testFile}
   Capture the exit code and the passed and failed counts from the output.
2. Run: cd ${repo} && git status --porcelain -- ${t.files.join(' ')}
   Return every path it lists (repo-relative) as scoped_changed_paths.

pass is true only if the test exit code is 0 and failed is 0. Do not edit any file. Do not run the full suite.`
}

function reconPrompt() {
  return `You are a verification agent. You change nothing; you run commands and report facts. The repository is at ${repo}.

1. Run: cd ${repo} && git status --porcelain -uall
   (-uall matters: without it, untracked directories are collapsed and their files are invisible.)
   Return EVERY modified or untracked file path (repo-relative) as changed_paths. Directories are not paths; list files.
2. Run the full test suite: cd ${repo} && node --test
   Capture the exit code and the passed and failed counts.

pass is true only if the suite exit code is 0 and failed is 0. Do not edit any file.`
}

function finalReviewPrompt() {
  return `You are performing the feature-level review of a multi-task implementation. The repository is at ${repo}. The feature's range starts at commit ${baseSha}; every change is uncommitted in the working tree.

New files are untracked, so "git diff" alone will not show them: run cd ${repo} && git status --porcelain, then read every listed file in full, plus git diff ${baseSha} for tracked changes.

The per-task reviewers each saw one task. Your job is what only appears across task boundaries:

1. Integration: modules that import each other actually compose (run cd ${repo} && node --test yourself).
2. Consistency: naming, error-handling style and module shape are uniform across src/.
3. Gaps: behaviour the tasks jointly imply but none individually owns.

Severity calibration: Critical means broken or spec-violating; Important means must fix before commit; Minor means you would still ship. Verdict is APPROVED only with no Critical and no Important findings.`
}

// Per-task pipeline. Every gate ordering below is enforced by control flow:
// review cannot be skipped, verification cannot precede review, verified
// cannot be written without both gates passing.
const state = {}
for (const t of tasks) state[t.id] = { started: false, verified: false, failed: false }
const results = {}

async function runTask(t) {
  let fixBudget = 2 // Invariant: fix round-trips are an integer, counted across both gates.
  const tr = { taskId: t.id, rounds: 0 }
  results[t.id] = tr

  let impl = await agent(implPrompt(t), { label: `impl:${t.id}`, phase: 'Implement', schema: IMPL_SCHEMA, model: 'haiku' })
  if (!impl) { state[t.id].failed = true; tr.failure = 'implementer dispatch died'; return }
  tr.impl = impl
  if (impl.status === 'BLOCKED' || impl.status === 'NEEDS_CONTEXT') {
    state[t.id].failed = true; tr.failure = `implementer reported ${impl.status}`; return
  }
  // Invariant: claimed ownership subset check. Mechanical (claim-level; the
  // authoritative tree-level check happens at Reconcile).
  const stray = impl.files_changed.filter(p => !t.files.includes(p))
  if (stray.length) { state[t.id].failed = true; tr.failure = `ownership violation claimed: ${stray.join(', ')}`; return }
  // Invariant: TDD evidence must exist before review. Mechanical presence check.
  if (!impl.tdd_evidence.length) { state[t.id].failed = true; tr.failure = 'no TDD evidence in report'; return }

  let review = await agent(reviewPrompt(t, impl), { label: `review:${t.id}`, phase: 'Review', schema: REVIEW_SCHEMA, model: 'sonnet' })
  if (!review) { state[t.id].failed = true; tr.failure = 'reviewer dispatch died'; return }
  while (review.verdict === 'ISSUES_FOUND' && review.findings.some(f => f.severity !== 'Minor')) {
    if (fixBudget === 0) { state[t.id].failed = true; tr.failure = 'fix budget exhausted at review'; tr.lastReview = review; return }
    fixBudget--
    tr.rounds++
    const fix = await agent(fixPrompt(t, review), { label: `fix:${t.id}:r${tr.rounds}`, phase: 'Review', schema: IMPL_SCHEMA, model: 'haiku' })
    if (!fix) { state[t.id].failed = true; tr.failure = 'fix dispatch died'; return }
    const strayFix = fix.files_changed.filter(p => !t.files.includes(p))
    if (strayFix.length) { state[t.id].failed = true; tr.failure = `ownership violation in fix: ${strayFix.join(', ')}`; return }
    review = await agent(reviewPrompt(t, fix), { label: `re-review:${t.id}:r${tr.rounds}`, phase: 'Review', schema: REVIEW_SCHEMA, model: 'sonnet' })
    if (!review) { state[t.id].failed = true; tr.failure = 'reviewer dispatch died on re-review'; return }
  }
  tr.review = review
  tr.deferredMinor = review.findings.filter(f => f.severity === 'Minor')

  let verify = await agent(verifyPrompt(t), { label: `verify:${t.id}`, phase: 'Verify', schema: VERIFY_SCHEMA, model: 'haiku' })
  if (!verify) { state[t.id].failed = true; tr.failure = 'verify dispatch died'; return }
  if (!verify.pass) {
    if (fixBudget === 0) { state[t.id].failed = true; tr.failure = 'fix budget exhausted at verification'; tr.verify = verify; return }
    fixBudget--
    tr.rounds++
    const fix = await agent(fixPrompt(t, { findings: [{ severity: 'Critical', description: `verification failed: ${verify.test_command} exited ${verify.exit_code} with ${verify.failed} failing` }] }), { label: `fix:${t.id}:verify`, phase: 'Verify', schema: IMPL_SCHEMA, model: 'haiku' })
    if (!fix) { state[t.id].failed = true; tr.failure = 'fix dispatch died at verification'; return }
    // Every fix re-enters at code review: enforced by sequence, not memory.
    const reReview = await agent(reviewPrompt(t, fix), { label: `re-review:${t.id}:verify`, phase: 'Verify', schema: REVIEW_SCHEMA, model: 'sonnet' })
    if (!reReview || (reReview.verdict === 'ISSUES_FOUND' && reReview.findings.some(f => f.severity !== 'Minor'))) {
      state[t.id].failed = true; tr.failure = 'post-verification fix failed re-review'; return
    }
    verify = await agent(verifyPrompt(t), { label: `re-verify:${t.id}`, phase: 'Verify', schema: VERIFY_SCHEMA, model: 'haiku' })
    if (!verify || !verify.pass) { state[t.id].failed = true; tr.failure = 'verification failed after fix'; tr.verify = verify; return }
  }
  tr.verify = verify
  tr.fixBudgetRemaining = fixBudget
  // Invariant: verified is written here and only here, after both gates.
  state[t.id].verified = true
}

// ---- Ready-set scheduler. Mechanical: a loop over blockedBy edges. ----
// A task is ready when unstarted and every dependency is VERIFIED (not merely
// claimed complete). Waves run in parallel; the loop ends when nothing new
// becomes ready, which quarantines everything blocked behind a failure.
let waves = 0
while (true) {
  const ready = tasks.filter(t =>
    !state[t.id].started && !state[t.id].failed &&
    t.blockedBy.every(d => state[d].verified))
  if (!ready.length) break
  waves++
  for (const t of ready) state[t.id].started = true
  log(`wave ${waves}: ${ready.map(t => t.id).join(', ')} dispatched in parallel (${ready.length} implementer${ready.length > 1 ? 's' : ''})`)
  await parallel(ready.map(t => () => runTask(t)))
}
const unreached = tasks.filter(t => !state[t.id].started).map(t => t.id)

// ---- Reconcile: authoritative tree-level ownership check. ----
phase('Reconcile')
const recon = await agent(reconPrompt(), { label: 'reconcile', phase: 'Reconcile', schema: RECON_SCHEMA, model: 'haiku' })
const union = new Set(tasks.flatMap(t => t.files))
const rogue = recon ? recon.changed_paths.filter(p => !union.has(p)) : ['reconcile agent died']

let featureReview = null
const allVerified = tasks.every(t => state[t.id].verified)
if (allVerified && rogue.length === 0 && recon && recon.pass) {
  featureReview = await agent(finalReviewPrompt(), { label: 'feature-review', phase: 'Reconcile', schema: REVIEW_SCHEMA, model: 'sonnet' })
} else {
  log(`feature review skipped: allVerified=${allVerified}, rogue=[${rogue.join(', ')}], suitePass=${recon ? recon.pass : 'n/a'}`)
}

log(`output tokens spent by this workflow: ${budget.spent()}`)

return {
  baseSha,
  waves,
  state,
  results,
  unreachedTasks: unreached,
  reconcile: recon,
  rogueChanges: rogue,
  featureReview,
  outputTokensSpent: budget.spent(),
}