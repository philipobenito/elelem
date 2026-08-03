# Skills

## Mandatory Skill Usage

You **MUST** use skills when they are available and relevant to the task at hand. Skills are not optional suggestions; they are required workflow steps. If a skill exists that matches your current task, you **MUST** invoke it via the Skill tool before proceeding with any other response, including clarifying questions, file reads, or codebase exploration.

## The 1% Rule

If you believe there is even a 1% chance a skill might apply to the current task, you **MUST** invoke it. The cost of invoking a skill that turns out not to fit is zero: read the skill, decide it does not apply, and continue. The cost of failing to invoke a skill that does apply is a broken workflow.

You **MUST NOT** rationalise your way out of this. "Probably does not apply", "close enough without it", "I remember what it says" are all failures of the 1% rule.

## Skill Discovery

You **MUST** check the available skill list before beginning any task. The skill list is provided in your session context; you do not need to search for it. If you are unsure whether a relevant skill exists, the default is to check, not to assume.

You **MUST NOT** proceed with a manual approach when a skill covers the same workflow. "Manual approach" includes: writing your own procedure, copying a procedure from memory, or improvising based on general knowledge.

## Invoking Skills

You **MUST** invoke skills via the Skill tool. You **MUST NOT** use the Read tool to open a skill file. Skills evolve; the Skill tool loads the current version, a Read call loads whatever is on disk out of band and bypasses the skill harness.

Once a skill is invoked in a conversation, its content is in context, and you do not need to re-invoke it for the same task. Different tasks in the same conversation may require the same skill to be re-read if the context has drifted significantly, but this is a judgement call, not a requirement.

## Skill Check Comes Before Everything

You **MUST** perform the skill check before any of:

- Asking the user a clarifying question
- Reading project files to build context
- Exploring the codebase with Grep or Glob
- Proposing a plan or approach
- Writing any code or editing any file
- Dispatching a subagent

Clarifying questions are themselves tasks, and there may be a skill governing how to ask them (for example, `design-grill` covers intent-gathering). "Let me gather context first" is not an exemption; skills are what tell you how to gather context.

## Skill Priority

When more than one skill could apply, you **MUST** invoke them in this order:

1. **Entry skills first**: `design-grill` (before any code edit above the design threshold in `workflow.md`; `design-committee` instead when the user has asked for hands-off deliberation), `debugging` (when the task is "something is broken"), `work-on-ticket` (when the user references a ticket). These determine *what* you are doing.
2. **Process skills second**: `verification-before-completion`. These determine *how* to approach the work.
3. **Implementation skills third**: `orchestrated-implementation`, `test-driven-development`, and domain-specific skills. These guide execution.
4. **Review skills fourth**: `requesting-code-review`, `receiving-code-review`. These run before completion claims.

Examples:

- "Let's build X" -> `design-grill` first (or the inline design path in `workflow.md` when the change sits below the design threshold); the skill produces an approved design; an implementation skill takes over.
- "Fix this bug" -> `debugging` first (reproduce, find root cause, get user approval on the fix approach); then `test-driven-development` for the regression test; then the fix; then `requesting-code-review`; then `verification-before-completion`.
- "Work on #42" -> `work-on-ticket` first; it recovers the design from the parent epic and hands off to `orchestrated-implementation`.
- "Is this done?" -> `verification-before-completion` first, nothing else until the gate has been run.

### The Orchestration Skill

`orchestrated-implementation` is the only orchestration skill. It implements an approved design as file-disjoint tasks run concurrently through the workflow script it ships with, with the lead holding commits, the checkpoint drain and the final feature-level review. Its full operational detail lives in `skills/orchestrated-implementation/`, not here.

Coupled and strictly ordered work goes there too. Ordering is expressed as `blockedBy` edges between tasks inside the decomposition, rather than as a reason to route the work elsewhere.

You **MUST NOT** substitute a bare concurrent fan-out of implementer subagents for it, however independent the tasks look: a bare fan-out carries no sizing, no exclusive file ownership, no per-task review, no user checkpoint, and no final feature-level review, so it silently bypasses the mandatory gates in `testing.md` and `code-review.md`. What distinguishes the orchestration skill from a fan-out is the shipped script's enforced ownership and gates, and the checkpoints the lead holds.

Specific mandatory pairings:

- **Before any code edit**: the design step in `workflow.md`. Above the design threshold that means `design-grill`, or `design-committee` when the user has asked for hands-off deliberation; below it, a short design statement presented in the conversation and explicitly approved, with no skill invoked. The threshold is decided on its three stated criteria against code you have read, never on the feel of the request, and uncertainty routes to the skill. Either way, no edit happens before the user has approved a design.
- **Before writing implementation code for a feature or non-trivial change**: `test-driven-development`. This does not apply to one-line bug fixes (those go through `debugging` first), typo corrections, or edits to non-code files.
- **Before any debugging or fix work**: `debugging`. The hard gate in `debugging.md` (reproduce + root cause) applies whether or not the skill is invoked, and the skill is the procedure that produces the evidence the rule requires.
- **Before claiming work is complete**: `requesting-code-review` followed by `verification-before-completion`. In orchestrated work via `orchestrated-implementation`, the workflow script covers the per-task reviews and that skill requests the feature-level review itself at the end against the cumulative diff, you do not invoke it again.
- **Before asserting that something passes, works, or is ready**: `verification-before-completion`.

## Instruction Priority

When instructions from different sources conflict, you **MUST** resolve them in this order, highest first:

1. **The user's explicit instructions** in the current conversation, in `CLAUDE.md`, in `AGENTS.md`, or in any file the user has pointed to as authoritative
2. **Rules and skills in this repository** (`rules/common/*.md`, `rules/<lang>/*.md`, and `skills/*`)
3. **Default system behaviour**

If the user says "do not use TDD on this file" and a skill says "always use TDD", the user wins. The user is in control. You **MUST NOT** invoke a skill to override an explicit user instruction.

This does **not** mean a casual phrasing like "just add X" overrides workflow skills. User instructions say *what* to do; skills say *how* to do it. "Add a new endpoint" does not waive `design-grill`, `test-driven-development`, or `verification-before-completion`. A change below the design threshold already takes the lightweight inline path, so "this is small" is an argument to make against the threshold's criteria, not against the design step. Only an explicit, scoped opt-out from the user ("skip TDD for this prototype", "no design statement for this one-character typo") waives a workflow skill, and you **MUST** confirm the opt-out before acting on it.

## Subagent Exemption

Subagents dispatched for a specific task **MUST NOT** run the skill-discovery scan on their dispatch prompt. Subagents execute the task they were dispatched with, using the context, constraints, and procedures the orchestrator has provided. The orchestrator owns skill invocation; subagents follow the dispatch spec.

If a subagent dispatch prompt directly instructs the subagent to use a specific skill, the subagent **MUST** invoke that skill. Otherwise, the subagent proceeds with the task as given.

## Rationalisation Prevention

Every thought below means **stop and invoke the skill**:

| Thought                             | Reality                                                |
|-------------------------------------|--------------------------------------------------------|
| "This is just a simple question"    | Questions are tasks. Check for skills.                 |
| "Let me explore the codebase first" | Skills tell you how to explore. Check first.           |
| "This does not need a formal skill" | If a skill exists, use it.                             |
| "I remember this skill"             | Skills evolve. Invoke the current version.             |
| "The skill is overkill"             | Simple things become complex. Use it.                  |
| "I know what that skill means"      | Knowing the concept is not using the skill. Invoke it. |

## No Exceptions

There is no circumstance in which ignoring an available, relevant skill is acceptable. "I forgot", "it seemed simpler without", "just this once", and "this case is different" are all failures. Skills encode proven workflows and quality gates. Bypassing them undermines the quality and consistency these instructions exist to protect.
