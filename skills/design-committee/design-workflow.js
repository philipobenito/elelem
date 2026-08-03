// The deliberation workflow shipped with skills/design-committee/SKILL.md.
// The skill constructs the args value; this script owns the control flow:
// three lens agents state independent positions, every position faces
// cross-examination, a synthesiser resolves each decision on evidence with
// vote counting forbidden by its brief, and a decision still split after
// synthesis gets exactly one tiebreak before being recorded as unresolved.
// Decision groups run sequentially so each group's prompts carry the
// consensus recorded by the groups before it.
//
// args (object, or a JSON string of the same shape):
//   brief          the confirmed project brief, pasted verbatim
//   context        codebase context the lead read for this brief: file
//                  structure, patterns, relevant code; pasted, never referenced
//   groups         [{ id, name, decisions }] where decisions is prose naming
//                  the specific decisions in the group; groups run in order
//   priorConsensus optional prose of consensus already recorded, for a
//                  targeted re-run of a single decision

export const meta = {
  name: 'design-committee',
  description: 'Deliberate a set of design decisions through three lenses, cross-examination, and evidence-weighed synthesis',
  phases: [
    { title: 'Positions', detail: 'three lens agents per decision group, independent and concurrent' },
    { title: 'Cross-examination', detail: 'each lens confronts the other two positions' },
    { title: 'Synthesis', detail: 'evidence-weighed resolution, one tiebreak per still-split decision' },
  ],
}

const input = typeof args === 'string' ? JSON.parse(args) : args
const { brief, context, groups } = input

const LENSES = [
  {
    name: 'Pragmatist',
    brief: `Your lens is THE PRAGMATIST.

You prioritise: simplicity and minimal moving parts; maintenance cost and
long-term burden; shipping quickly with confidence; using what already exists
over building new abstractions; the simplest thing that could work.

You are sceptical of: over-engineering and premature abstraction;
"future-proofing" that adds complexity now; new patterns when existing ones
suffice; complexity that does not serve an immediate need.`,
  },
  {
    name: 'Architect',
    brief: `Your lens is THE ARCHITECT.

You prioritise: clean separation of concerns and clear boundaries; consistency
with existing patterns in the codebase; well-defined interfaces between
components; testability and debuggability; the design that best fits the
system's existing architecture.

You are sceptical of: approaches that bypass or work around the existing
architecture; tight coupling between components that should be independent;
designs that make future changes disproportionately expensive; inconsistency
with established codebase patterns.`,
  },
  {
    name: 'Advocate',
    brief: `Your lens is THE ADVOCATE.

You prioritise: correctness and proper edge-case handling; user experience and
developer experience; robustness under failure conditions; clear error messages
and graceful degradation; the approach that is hardest to misuse.

You are sceptical of: happy-path-only designs that ignore failure modes;
approaches that silently fail or produce confusing errors; designs that are
easy to use incorrectly; missing validation at system boundaries.`,
  },
]

const CONSTRAINTS = `## Constraints

You are advising on a design, not implementing it. Read whatever you need to
verify your assumptions, and do not write, edit, create, move, or delete any
file, and do not run any command that changes state. If you believe something
needs changing, say so in your recommendation; someone else decides and acts.

Stay within scope. Do not redesign unrelated systems, and do not propose
refactoring that the brief did not ask for.`

const POSITION_SCHEMA = {
  type: 'object',
  required: ['positions'],
  properties: {
    positions: {
      type: 'array',
      items: {
        type: 'object',
        required: ['decision', 'recommendation', 'reasoning', 'concerns'],
        properties: {
          decision: { type: 'string' },
          recommendation: { type: 'string' },
          reasoning: { type: 'string', description: 'why, citing the specific files or code read wherever they support the position' },
          concerns: { type: 'string', description: "risks or trade-offs, even with the recommended approach; 'none' if none" },
        },
      },
    },
  },
}

const CROSS_SCHEMA = {
  type: 'object',
  required: ['positions'],
  properties: {
    positions: {
      type: 'array',
      items: {
        type: 'object',
        required: ['decision', 'stance', 'recommendation', 'rationale', 'concerns_worth_addressing'],
        properties: {
          decision: { type: 'string' },
          stance: { enum: ['HELD', 'REVISED'] },
          recommendation: { type: 'string' },
          rationale: { type: 'string', description: 'the specific argument or evidence that moved you, or the evidence you hold on' },
          concerns_worth_addressing: { type: 'string', description: "concerns from the other lenses that are real regardless of which recommendation wins; 'none' if none" },
        },
      },
    },
  },
}

const SYNTH_SCHEMA = {
  type: 'object',
  required: ['resolutions'],
  properties: {
    resolutions: {
      type: 'array',
      items: {
        type: 'object',
        required: ['decision', 'outcome', 'consensus', 'reasoning', 'dissent', 'must_address_concerns'],
        properties: {
          decision: { type: 'string' },
          outcome: { enum: ['RESOLVED', 'SPLIT'] },
          consensus: { type: 'string', description: "the resolved direction, or '' when SPLIT" },
          reasoning: { type: 'string', description: 'the evidence that decided it, never the count of lenses agreeing' },
          dissent: { type: 'string', description: "any position rejected on evidence, recorded with its reasoning; 'none' if none" },
          must_address_concerns: { type: 'array', items: { type: 'string' }, description: 'concerns raised through more than one lens, or conceded as real during cross-examination' },
        },
      },
    },
  },
}

const TIEBREAK_SCHEMA = {
  type: 'object',
  required: ['decision', 'outcome', 'chosen', 'reasoning', 'accepted_tradeoffs', 'must_address_concerns'],
  properties: {
    decision: { type: 'string' },
    outcome: { enum: ['RESOLVED', 'UNRESOLVED'] },
    chosen: { type: 'string', description: "the chosen approach, or '' when UNRESOLVED" },
    reasoning: { type: 'string' },
    accepted_tradeoffs: { type: 'string' },
    must_address_concerns: { type: 'array', items: { type: 'string' } },
  },
}

function sharedScaffold(consensusSoFar, group) {
  return `**The project brief:**

${brief}

**Relevant codebase context:**

${context}

**Consensus from earlier decision groups:**

${consensusSoFar || 'None - this is the first group'}

**Decisions to make:**

${group.decisions}

${CONSTRAINTS}`
}

function positionPrompt(lens, group, consensusSoFar) {
  return `You are one lens in a design deliberation. Two other agents are examining the same decisions through different lenses; you will not see their positions in this round, and yours will face cross-examination.

${lens.brief}

${sharedScaffold(consensusSoFar, group)}

## Your Task

For each decision: state your recommendation clearly, explain your reasoning in two or three sentences, and flag any concerns or risks, even with your own recommendation. Cite the specific files or code you read wherever they support your position: a recommendation grounded in something you actually read carries more weight in synthesis than one argued from general principle, and you will be cross-examined on it.`
}

function crossPrompt(lens, group, consensusSoFar, own, others) {
  return `You are one lens in a design deliberation, now cross-examining. You previously took a position on these decisions; the other two lenses took theirs independently, and all three are below.

${lens.brief}

${sharedScaffold(consensusSoFar, group)}

**Your earlier position:**

${own}

**The other two positions:**

${others}

## Your Task

For each decision, state whether you hold or revise your position, and why. Conceding is a useful result, not a loss: if another lens identified something you missed, say so plainly and name what changed your mind. Holding is equally useful, but hold on evidence rather than by restating your original reasoning more forcefully. If a concern of theirs is real but does not change your recommendation, say that too, because it needs addressing in the design either way.`
}

function synthPrompt(group, consensusSoFar, positions) {
  return `You are synthesising a design deliberation. Three agents examined the same decisions through different lenses, then cross-examined each other; their post-cross-examination positions are below.

${sharedScaffold(consensusSoFar, group)}

**The three positions after cross-examination:**

${positions}

## How to Weigh

The three positions come from correlated models given different briefs. Agreement between them is NOT evidence of correctness: the lenses exist to cover different failure modes, not to vote, so you MUST NOT resolve any decision by counting who agrees. Weigh cited files and named failure modes; a lone dissent citing specific code outranks two agreements argued from general principle. Where the positions are equally well evidenced and genuinely incompatible, return SPLIT rather than manufacturing a resolution.

## Your Task

For each decision, return RESOLVED with the consensus direction and the evidence that decided it, or SPLIT. Record any rejected position as dissent with its reasoning. List as must-address every concern raised through more than one lens, and every concern a lens conceded as real during cross-examination, whichever recommendation won.`
}

function tiebreakPrompt(group, consensusSoFar, positions, split) {
  return `Three lens agents deliberated a design decision, cross-examined each other, and a synthesiser found them still genuinely split. You are a fresh adjudicator holding no position of your own.

${sharedScaffold(consensusSoFar, group)}

**The decision still split:**

${split.decision}

**The three positions after cross-examination:**

${positions}

**The synthesiser's account of the split:**

${split.reasoning}

## Your Task

Identify the core tension: what are they actually disagreeing about? Weigh the positions on their evidence; a position citing specific code outranks one argued from general principle, regardless of how many lenses hold each view. Determine whether a compromise addresses the key concern behind each position. If a resolution exists, return RESOLVED with the chosen approach, the reasoning, and the trade-offs being accepted. If the positions are equally well evidenced and truly incompatible, return UNRESOLVED: that is a decision for a human, and forcing a choice here would dress preference up as adjudication. Either way, list the concerns that must be addressed regardless of which approach wins.`
}

const fmtPositions = (rs) => rs.map(r => `## ${r.lens}\n\n${r.result.positions.map(p =>
  `### ${p.decision}\n${'stance' in p ? `**Stance:** ${p.stance}\n` : ''}**Recommendation:** ${p.recommendation}\n**Reasoning:** ${p.rationale || p.reasoning}\n**Concerns:** ${p.concerns_worth_addressing || p.concerns}`).join('\n\n')}`).join('\n\n')

let consensusSoFar = input.priorConsensus || ''
const out = []

for (const group of groups) {
  log(`decision group: ${group.name}`)

  const roundA = await parallel(LENSES.map(lens => () =>
    agent(positionPrompt(lens, group, consensusSoFar), { label: `position:${group.id}:${lens.name}`, phase: 'Positions', schema: POSITION_SCHEMA })
      .then(result => result && { lens: lens.name, result })))
  const positionsA = roundA.filter(Boolean)
  if (positionsA.length < LENSES.length) throw new Error(`group ${group.id}: only ${positionsA.length}/3 lenses returned a position; fewer than three breaks the deliberation`)

  // Cross-examination always runs. Detecting "all three agree with no
  // concerns" reliably would itself take a judge, and a majority without
  // examination is exactly what this workflow exists to avoid.
  const roundB = await parallel(positionsA.map(own => () =>
    agent(crossPrompt(LENSES.find(l => l.name === own.lens), group, consensusSoFar,
      fmtPositions([own]), fmtPositions(positionsA.filter(o => o.lens !== own.lens))),
      { label: `cross:${group.id}:${own.lens}`, phase: 'Cross-examination', schema: CROSS_SCHEMA })
      .then(result => result && { lens: own.lens, result })))
  const positionsB = roundB.filter(Boolean)
  if (positionsB.length < LENSES.length) throw new Error(`group ${group.id}: only ${positionsB.length}/3 lenses returned from cross-examination`)

  const synth = await agent(synthPrompt(group, consensusSoFar, fmtPositions(positionsB)),
    { label: `synthesise:${group.id}`, phase: 'Synthesis', schema: SYNTH_SCHEMA })
  if (!synth) throw new Error(`group ${group.id}: synthesis dispatch died`)

  const resolutions = []
  for (const r of synth.resolutions) {
    if (r.outcome !== 'SPLIT') { resolutions.push(r); continue }
    const tb = await agent(tiebreakPrompt(group, consensusSoFar, fmtPositions(positionsB), r),
      { label: `tiebreak:${group.id}`, phase: 'Synthesis', schema: TIEBREAK_SCHEMA })
    if (tb && tb.outcome === 'RESOLVED') {
      resolutions.push({ decision: r.decision, outcome: 'RESOLVED', consensus: tb.chosen, reasoning: `${tb.reasoning} Accepted trade-offs: ${tb.accepted_tradeoffs}`, dissent: r.dissent, must_address_concerns: [...new Set([...r.must_address_concerns, ...tb.must_address_concerns])] })
    } else {
      // One tiebreak per decision; still split (or a dead dispatch) means
      // the decision is genuinely unresolved and belongs to the user.
      resolutions.push({ ...r, outcome: 'UNRESOLVED', must_address_concerns: [...new Set([...r.must_address_concerns, ...((tb && tb.must_address_concerns) || [])])] })
    }
  }

  consensusSoFar += `\n\n### Group: ${group.name}\n\n` + resolutions.map(r =>
    r.outcome === 'RESOLVED'
      ? `- ${r.decision}: ${r.consensus} (${r.reasoning})`
      : `- ${r.decision}: UNRESOLVED, goes to the user (${r.reasoning})`).join('\n')

  out.push({ id: group.id, name: group.name, resolutions })
  const unresolved = resolutions.filter(r => r.outcome === 'UNRESOLVED').length
  log(`group ${group.id}: ${resolutions.length - unresolved} resolved, ${unresolved} unresolved`)
}

return {
  groups: out,
  consensus: consensusSoFar.trim(),
  unresolved: out.flatMap(g => g.resolutions.filter(r => r.outcome === 'UNRESOLVED').map(r => ({ group: g.name, decision: r.decision, reasoning: r.reasoning }))),
  mustAddressConcerns: [...new Set(out.flatMap(g => g.resolutions.flatMap(r => r.must_address_concerns)))],
  outputTokensSpent: budget.spent(),
}
