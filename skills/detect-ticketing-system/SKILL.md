---
name: detect-ticketing-system
description: Identifies which ticketing system the current project uses (GitHub Issues, Jira, GitLab, Linear, or none) by scanning available MCP tools, git remotes, and CLI binaries. Returns the detected system so a caller can pick the right API, or reports that no system is available so the caller can fall back.
---

# Detect Ticketing System

This skill is a reusable detection capability invoked by `create-tickets`, `work-on-ticket`, and any other skill that needs to know where tickets live for the current project. It does not create or read tickets itself; it only identifies the system.

For the rules on how tickets and epics must be structured, see `skills/_shared/tickets.md`. The ticket-creation and ticket-recovery skills (`create-tickets`, `work-on-ticket`) load that file when they are invoked.

## Procedure

Run the three checks in order. Stop at the first check that returns an unambiguous result.

### 1. Available MCP Tools

Scan the MCP tools available in the current session for ticketing-system patterns:

| MCP Tool Pattern                    | System        |
|-------------------------------------|---------------|
| `mcp__*Atlassian*__*JiraIssue*`     | Jira          |
| `mcp__*github*__issue_*`            | GitHub Issues |
| `mcp__*linear*__*`                  | Linear        |
| `mcp__*gitlab*__*`                  | GitLab Issues |

If exactly one system's tools are present, record it as the detected system and stop. If more than one is present, record all of them and carry through to resolution.

### 2. Git Remote

If the MCP check did not produce exactly one result, inspect the git remote:

```bash
git remote get-url origin
```

| Remote contains | System        |
|-----------------|---------------|
| `github.com`    | GitHub Issues |
| `gitlab.com`    | GitLab Issues |
| `dev.azure.com` | Azure DevOps  |
| `bitbucket.org` | Bitbucket     |

A self-hosted instance (`github.mycorp.com`, `gitlab.internal`, on-prem Jira) may still match by substring. If the substring is ambiguous, skip to step 3.

### 3. CLI Binary Availability

If neither MCP tools nor the git remote resolved the system, check for installed CLI binaries:

| Binary | System        | Availability check |
|--------|---------------|--------------------|
| `gh`   | GitHub Issues | `command -v gh`    |
| `glab` | GitLab Issues | `command -v glab`  |

A CLI binary alone is weaker evidence than MCP tools or a matching git remote; a user may have `gh` installed without using GitHub Issues on this project. Treat CLI-only detection as a candidate, not a confirmation.

## Resolution

After the three checks, resolve the result:

- **Exactly one system found**: return that system and the strongest mechanism that detected it (MCP > git remote > CLI). The caller will confirm with the user before taking destructive action.
- **More than one system found**: return the list. The caller **MUST** ask the user which to use via `{{ASK_USER_QUESTION_TOOL}}` before proceeding.
- **No system found**: return "none". The caller decides its own fallback (for example, `create-tickets` writes a structured Markdown file; `work-on-ticket` asks the user to paste the ticket content directly).

## Worked Example

Session has the Atlassian MCP tools loaded (`mcp__Atlassian__getJiraIssue`, `mcp__Atlassian__createJiraIssue`, etc.), the git remote is `git@github.com:acme/widget.git`, and `gh` is installed.

1. MCP check: Atlassian Jira tools are present, no GitHub MCP tools. One system found: Jira.
2. Git remote check: skipped (MCP already resolved).
3. CLI check: skipped.

Return: `{ system: "Jira", mechanism: "mcp" }`.

Note that the git remote pointing at `github.com` did not override the Jira detection. A project can live in a GitHub repository while tracking tickets in Jira; the MCP tools reflect the user's actual ticketing workflow, so they win.
