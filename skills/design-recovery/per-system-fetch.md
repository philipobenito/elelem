# Per-System Fetch

**Load model**: this file is **not** always in context. `./SKILL.md` loads it at step 2, once the reference has been resolved to a system. Read the section for that system and skip the rest; the others describe APIs this run will not call.

Each section covers both halves of what recovery needs: the call that fetches a ticket, and the mechanism the design walk follows to reach its parent. Parents are found through the system's native mechanism wherever one exists; body-text references (`Part of #N`, `Epic: #N`) are the fallback for paths with no native link, and each section says which those are.

## GitHub Issues

With GitHub MCP tools: `issue_read` with the issue number. The response includes body, labels, and parent or sub-issue relationship fields.

With `gh` CLI:

```bash
gh issue view <number> --json title,body,labels,milestone,projectItems
```

**Parent**: the native parent field on `issue_read` first; if absent, body-text references, which is the path CLI-created and hand-filed tickets take.

## Jira

With Atlassian MCP tools: `getJiraIssue` with the issue key. The response includes the `parent` and `epic` fields natively, and the issue type (Epic, Story, Task) is useful context for what a node is likely to carry.

**Parent**: the `parent` or `epic` field on `getJiraIssue`.

## GitLab Issues

With GitLab MCP tools if available; otherwise:

```bash
glab issue view <number>
```

**Parent**: the group Epic association where group Epics are available (premium GitLab); body-text references where they are not.

## Linear

With Linear MCP tools. The response includes the `parent` field.

**Parent**: the `parent` field on the issue; body-text references where a workspace was populated without nesting.

## Markdown Document

A document needs no fetch call: read the file. Its heading structure is the shape, and the walk collapses to reading it. Where the document was written by the handoff skill, the file body carries the design under `## Design` and each ticket is a heading inside `## Tickets`, with grouping expressed by heading nesting; a hand-written document may use any structure, and its headings are read for what they say rather than matched against that template.
