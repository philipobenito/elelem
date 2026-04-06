---
name: dispatching-parallel-agents
description: Dispatches multiple focused subagents concurrently in a single message when a problem decomposes into independent domains. For the standing rules on context isolation, subagent type selection, and model selection, see instructions/common/subagents.md.
---

# Dispatching Parallel Agents

The standing rules on every subagent dispatch (context isolation, git ownership, subagent type selection, model selection, answering subagent questions, escalation) live in `instructions/common/subagents.md`. This skill is the procedure for the specific case where the work decomposes into two or more independent problem domains that can be investigated or fixed concurrently.

## When This Skill Applies

You **MUST** confirm all of the following before dispatching in parallel:

- There are two or more failures, tasks, or investigations to work on
- Each one can be understood and completed without information from the others
- No two tasks will read or write the same files
- No task's correct fix depends on another task's outcome

If any of these is false, a parallel dispatch is not valid. Either investigate sequentially or investigate together with a single agent that sees the full picture. "Fixing one might fix the others" is the clearest disqualification: it means the problems are coupled, and parallel fixes will race or overlap.

## Procedure

1. **Identify independent domains.** Group the work by what is broken or what needs building. Each group **MUST** map to exactly one problem domain with no shared files, shared state, or shared causal chain. If you cannot cleanly partition the work, stop. This skill does not apply.

2. **Annotate each task with its subagent type and model.** Per `subagents.md`, pick the most specific subagent type for each task (for example `typescript-pro` for a TypeScript test file, `python-pro` for a Python module, `debugger` for diagnostic work). Start every dispatch on `haiku` and escalate only on evidence.

3. **Construct each task prompt.** Per `subagents.md`, do not let any subagent inherit your session history. For each agent, write a self-contained prompt containing:

   - The specific scope (one file, one subsystem, one failing behaviour)
   - The failing symptoms, including exact test names and error messages where relevant
   - The constraint boundary: what the agent may touch and what it **MUST NOT** touch
   - The required output format: a summary of what was found, what was changed, and the verification the agent ran before reporting done

4. **Dispatch in a single message.** Parallelism happens because the dispatches are issued in one message, not because you intend it to. Issue every `{{DISPATCH_AGENT_TOOL}}` call in the same turn. A dispatch issued in the next turn runs after the previous one has returned, which is sequential, not parallel.

5. **Reconcile on return.** For each returned agent:

   - Read the full summary
   - Check for file-level conflicts: did any two agents touch the same file? If yes, read both diffs and confirm the edits do not overwrite each other
   - Check for systematic errors: agents operating in isolation can reach the same wrong conclusion
   - Run the full verification suite against the merged state per `instructions/common/verification.md`. Per-agent local verification is not sufficient; the parallel fixes only pass the gate once they pass together.

6. **Act on failure modes.** If reconciliation fails (edit conflict, systematic error, merged verification red), follow the escalation ladder in `subagents.md`: more context and re-dispatch, more capable model, smaller scope, or escalation to the human partner. You **MUST NOT** patch the output manually in the orchestrator context.

## Parallel-Specific Mistakes

These are the mistakes that are unique to parallel dispatch. General subagent-dispatch mistakes are covered in `subagents.md`.

| Mistake                                                | Correct                                                                        |
|--------------------------------------------------------|--------------------------------------------------------------------------------|
| Partitioning work that is actually coupled             | Investigate sequentially when fixing one might fix the others                  |
| Two agents assigned overlapping files                  | Repartition so each file has one owner, or sequentialise                       |
| Dispatching across multiple messages                   | Issue every dispatch in one message; multi-message issue is sequential         |
| Running per-agent verification only                    | Run the full suite against the merged state after all agents return            |
| Accepting per-agent summaries without reconciling      | Read every diff, check for conflicts, verify the merged state                  |
| Trusting agents that reached the same conclusion       | Convergent answers from isolated agents can be a shared blind spot, not proof  |

## Worked Example

Six test failures across three files after a refactor:

- `agent-tool-abort.test.ts`: 3 failures, timing and race conditions
- `batch-completion-behavior.test.ts`: 2 failures, tools not executing
- `tool-approval-race-conditions.test.ts`: 1 failure, execution count is zero

Independence check: each file exercises a different subsystem (abort logic, batch completion, tool approval). The failures do not share state or files. Parallel dispatch is valid.

Decomposition, annotated with subagent type and model:

- Agent 1 (`typescript-pro`, `haiku`): fix `agent-tool-abort.test.ts`; scope limited to that file plus the abort implementation it exercises; replace arbitrary timeouts with event-based waiting; do not touch other test files
- Agent 2 (`typescript-pro`, `haiku`): fix `batch-completion-behavior.test.ts`; scope limited to the batch completion path; do not touch abort or approval code
- Agent 3 (`typescript-pro`, `haiku`): fix `tool-approval-race-conditions.test.ts`; scope limited to the approval path

Dispatch all three in a single message.

On return:

- Agent 1 replaced timeouts with event-based waiting in the abort path
- Agent 2 fixed a misplaced `threadId` field in the batch completion event
- Agent 3 added a wait for async tool execution in the approval path

Reconciliation: check for file-level overlap (none; each agent touched a distinct test file plus a distinct production module). Run the full test suite against the merged working tree per `verification.md`. If green, report the work as complete with the cited command output. If red, identify which fix regressed and escalate per `subagents.md`.
