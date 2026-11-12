# elelem opencode configuration

This directory was populated by `install-opencode.sh`. Rules are loaded via the
`instructions` array in `opencode.json`; skills are auto-discovered from
`skills/` per the opencode skills documentation. See `opencode.json` for the
loading manifest.

## opencode notes

elelem installs the same rules and skills under Claude Code and opencode.
Most primitives have direct opencode equivalents and the installer
substitutes them automatically. Two small differences are worth knowing:

**Plan mode.** opencode has plan mode, toggled by the user pressing Tab. The
assistant cannot enter or exit plan mode itself. Skills that currently say
"enter plan mode" or "exit plan mode" will ask you (the user) to press Tab
at the relevant point. The design-before-implementation rule still applies.
Skills affected: brainstorming, brainstorming-standard, brainstorming-guided,
brainstorming-skip. The skip path still works via explicit user approval but
is no longer structurally distinct from brainstorming-standard under opencode.

**Subagent dispatch.** opencode supports subagents via the `task` tool. The
installer substitutes `{{DISPATCH_AGENT_TOOL}}` with `task`. Subagent types
in dispatch templates (e.g. `subagent_type: "general-purpose"`) are advisory
under opencode; @mention the corresponding opencode subagent if your setup
requires explicit selection. All skills that dispatch subagents
(subagent-driven-development, fast-path-implementation, dispatching-parallel-agents,
design-review, requesting-code-review, brainstorming-committee, debugging's
Autonomous mode) work under opencode after substitution.

**User questions.** `{{ASK_USER_QUESTION_TOOL}}` substitutes to opencode's
built-in `question` tool. No degradation.

No skills are currently unsupported under opencode. If you find a skill that
does not work as expected, file an issue against the elelem repo.
