# Per-System Fetch

**Load model**: this file is **not** always in context. `./SKILL.md` loads it at step 2, once `../_shared/ticketing-detection.md` has resolved which system the ticket lives in. Read the section for that system and skip the rest; the others describe APIs this run will not call.

Each section covers both halves of what the walk needs: the call that fetches the ticket, and the native mechanism `resolve_epic_context` follows to reach its parent. The tier marker itself is read uniformly per the Tier Markers section of `../_shared/tickets.md`; fetching a ticket also returns enough metadata (issue type, labels, or heading level) to identify the tier without an extra round trip.

Parents are found through the system's native parent mechanism wherever one exists, not by inspecting body text. Body-text references are a fallback for the paths that have no native mechanism, and each section says which those are.

## GitHub Issues

With GitHub MCP tools: `issue_read` with the issue number. The response includes body, labels, and parent or sub-issue relationship fields.

With `gh` CLI:

```bash
gh issue view <number> --json title,body,labels,milestone,projectItems
```

Read the `tier:*` label from the labels array.

**Parent**: use the native parent field on `issue_read` first; if absent, scan the body for `Part of #N` and `Epic: #N` references, which is the path the `gh` CLI fallback and legacy tickets take.

## Jira

With Atlassian MCP tools: `getJiraIssue` with the issue key. The response includes the `parent` and `epic` fields natively, and the native issue type carries the tier.

**Parent**: the `parent` or `epic` field on `getJiraIssue`. Jira natively supports Epic-Story and Story-Sub-task relationships.

## GitLab Issues

With GitLab MCP tools if available; otherwise:

```bash
glab issue view <number>
```

The tier comes from either the native group Epic association (top tier on premium GitLab) or the `tier:*` label.

**Parent**: epic associations where group Epics are available, or `Part of #N` references in the body where they are not.

## Linear

With Linear MCP tools. The response includes the `parent` field, and the tier comes from the `tier:epic` / `tier:story` / `tier:task` label.

In a workspace where Linear nesting is degraded to two-tier, a Task carries a `story:<slug>` label instead of a Story parent, so the walker treats it as a direct child of the Epic. The full degradation, including how the Story theme is recovered from the epic body, is described in the Linear section of `../create-tickets/per-system-creation.md`.

**Parent**: the `parent` field on the issue.
