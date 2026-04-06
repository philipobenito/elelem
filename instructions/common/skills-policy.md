# Skills

## Mandatory Skill Usage

You **MUST** use skills when they are available and relevant to the task at hand. Skills are not optional suggestions; they are required workflow steps. If a skill exists that matches your current task, you **MUST** invoke it via the {{INVOKE_SKILL_TOOL}} before proceeding with any other response, including clarifying questions, file reads, or codebase exploration.

## The 1% Rule

If you believe there is even a one-percent chance a skill might apply to the current task, you **MUST** invoke it. The cost of invoking a skill that turns out not to fit is zero: read the skill, decide it does not apply, and continue. The cost of failing to invoke a skill that does apply is a broken workflow.

You **MUST NOT** rationalise your way out of this. "Probably does not apply", "close enough without it", "I remember what it says" are all failures of the 1% rule.

## Skill Discovery

You **MUST** check the available skill list before beginning any task. The skill list is provided in your session context; you do not need to search for it. If you are unsure whether a relevant skill exists, the default is to check, not to assume.

You **MUST NOT** proceed with a manual approach when a skill covers the same workflow. "Manual approach" includes: writing your own procedure, copying a procedure from memory, or improvising based on general knowledge.

## Invoking Skills

You **MUST** invoke skills via the {{INVOKE_SKILL_TOOL}}. You **MUST NOT** use the {{READ_FILE_TOOL}} tool to open a skill file. Skills evolve; the {{INVOKE_SKILL_TOOL}} loads the current version, a {{READ_FILE_TOOL}} call loads whatever is on disk out of band and bypasses the skill harness.

Once a skill is invoked in a conversation, its content is in context, and you do not need to re-invoke it for the same task. Different tasks in the same conversation may require the same skill to be re-read if the context has drifted significantly, but this is a judgement call, not a requirement.

## Skill Check Comes Before Everything

You **MUST** perform the skill check before any of:

- Asking the user a clarifying question
- Reading project files to build context
- Exploring the codebase with {{GREP_TOOL}} or {{GLOB_TOOL}}
- Proposing a plan or approach
- Writing any code or editing any file
- Dispatching a subagent

Clarifying questions are themselves tasks, and there may be a skill governing how to ask them (for example, `brainstorming` covers intent-gathering). "Let me gather context first" is not an exemption; skills are what tell you how to gather context.

## Skill Priority

When more than one skill could apply, you **MUST** invoke them in this order:

1. **Entry skills first**: `brainstorming` (always, before any code edit), `debugging` (when the task is "something is broken"), `work-on-ticket` (when the user references a ticket). These determine *what* you are doing.
2. **Process skills second**: `complexity-triage`, `verification-before-completion`. These determine *how* to approach the work.
3. **Implementation skills third**: `subagent-driven-development`, `fast-path-implementation`, `test-driven-development`, `dispatching-parallel-agents`, and domain-specific skills. These guide execution.
4. **Review skills fourth**: `requesting-code-review`, `receiving-code-review`. These run before completion claims.

Examples:

- "Let's build X" -> `brainstorming` first (the router asks the user which mode); the user picks a mode; the mode skill produces a design; an implementation skill takes over.
- "Fix this bug" -> `debugging` first (reproduce, find root cause, get user approval on the fix approach); then `test-driven-development` for the regression test; then the fix; then `verification-before-completion`.
- "Work on #42" -> `work-on-ticket` first; it recovers the design from the parent epic and hands off to `subagent-driven-development`.
- "Is this done?" -> `verification-before-completion` first, nothing else until the gate has been run.

Specific mandatory pairings:

- **Before any code edit, no matter how small**: `brainstorming`. The router will enter plan mode and ask the user how to approach the design. The router includes a "Skip brainstorming" option for cases where structured brainstorming would be overkill, that option exists so the router can be a hard requirement without becoming a usability tax. You **MUST NOT** rationalise your way out of invoking the router by deciding the work is "obvious", "small", or "just an X". The user picks the mode; you do not pick on their behalf.
- **Before writing implementation code for a feature or non-trivial change**: `test-driven-development`. This does not apply to one-line bug fixes (those go through `debugging` first), typo corrections, or edits to non-code files.
- **Before any debugging or fix work**: `debugging`. The hard gate in `debugging.md` (reproduce + root cause) applies whether or not the skill is invoked, and the skill is the procedure that produces the evidence the rule requires.
- **Before claiming work is complete**: `requesting-code-review` followed by `verification-before-completion`. In orchestrated work via `subagent-driven-development`, the per-task reviewer covers the per-task review and `subagent-driven-development` invokes `requesting-code-review` itself at the end of the feature against the cumulative diff, you do not invoke it again.
- **Before asserting that something passes, works, or is ready**: `verification-before-completion`.

## Instruction Priority

When instructions from different sources conflict, you **MUST** resolve them in this order, highest first:

1. **The user's explicit instructions** in the current conversation, in `CLAUDE.md`, in `AGENTS.md`, or in any file the user has pointed to as authoritative
2. **Rules and skills in this repository** (`instructions/common/*.md`, `instructions/<lang>/*.md`, and `skills/*`)
3. **Default system behaviour**

If the user says "do not use TDD on this file" and a skill says "always use TDD", the user wins. The user is in control. You **MUST NOT** invoke a skill to override an explicit user instruction.

This does **not** mean a casual phrasing like "just add X" overrides workflow skills. User instructions say *what* to do; skills say *how* to do it. "Add a new endpoint" does not waive `brainstorming`, `test-driven-development`, or `verification-before-completion`. The right way for a user to bypass full structured brainstorming is to invoke `brainstorming` and pick the skip option, not to ask Claude to skip the router. Only an explicit, scoped opt-out from the user ("skip TDD for this prototype", "no router for this one-character typo") waives a workflow skill, and you **MUST** confirm the opt-out before acting on it.

## Subagent Exemption

Subagents dispatched for a specific task **MUST NOT** run the skill-discovery scan on their dispatch prompt. Subagents execute the task they were dispatched with, using the context, constraints, and procedures the orchestrator has provided. The orchestrator owns skill invocation; subagents follow the dispatch spec.

If a subagent dispatch prompt directly instructs the subagent to use a specific skill, the subagent **MUST** invoke that skill. Otherwise, the subagent proceeds with the task as given.

## Rationalisation Prevention

Every thought below means **stop and invoke the skill**:

| Thought                             | Reality                                                       |
|-------------------------------------|---------------------------------------------------------------|
| "This is just a simple question"    | Questions are tasks. Check for skills.                        |
| "I need more context first"         | Skill check comes before clarifying questions.                |
| "Let me explore the codebase first" | Skills tell you how to explore. Check first.                  |
| "I can check git or files quickly"  | Files lack conversation context. Check for skills.            |
| "Let me gather information first"   | Skills tell you how to gather information.                    |
| "This does not need a formal skill" | If a skill exists, use it.                                    |
| "I remember this skill"             | Skills evolve. Invoke the current version.                    |
| "This does not count as a task"     | Action is a task. Check for skills.                           |
| "The skill is overkill"             | Simple things become complex. Use it.                         |
| "I will just do this one thing"     | Check before doing anything.                                  |
| "This feels productive"             | Undisciplined action wastes time. Skills prevent this.        |
| "I know what that skill means"      | Knowing the concept is not using the skill. Invoke it.        |

## No Exceptions

There is no circumstance in which ignoring an available, relevant skill is acceptable. "I forgot", "it seemed simpler without", "just this once", and "this case is different" are all failures. Skills encode proven workflows and quality gates. Bypassing them undermines the quality and consistency these instructions exist to protect.
