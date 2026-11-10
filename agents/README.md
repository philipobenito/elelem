# Bundled specialist agents

These agent definitions are adapted from the locally supplied [ampedweb/awesome-subagents](https://github.com/ampedweb/awesome-subagents) fork of [VoltAgent/awesome-subagents](https://github.com/VoltAgent/awesome-subagents), version 2, at source revision `4ce4267485e1a5491488548b3474007e1e6bddfb`. Copyright remains (c) 2025 VoltAgent under the included MIT licence in `LICENSE`.

The bundle contains `architect-reviewer`, `qa-expert`, `typescript-pro`, `python-pro`, `golang-pro`, `rust-engineer`, `react-specialist`, `laravel-specialist`, `java-architect`, `csharp-developer`, and `rails-expert` in native Claude Code Markdown, OpenCode V2 Markdown, and Codex TOML formats. Each identity has equivalent substantive instructions and routing descriptions across formats, without fixed model choices or assumptions about other installed agents or skills.

These are bounded workers, not independent workflow owners. They follow the authorised brief, exact write and side-effect limits, existing conventions and applicable instructions. Review-only assignments remain read-only. Delegated design analysis is permitted, but workers cannot approve designs or expand their own scope. Missing consequential context, required procedures or capabilities blocks dependent action rather than authorising a guess.

The profiles retain specialist judgement about relevant correctness pitfalls, such as Go cancellation and goroutine lifecycles, TypeScript narrowing, React effect cleanup, framework transaction boundaries and meaningful QA evidence. They replace expertise catalogues, mandatory lifecycle stages and arbitrary numerical targets with guidance limited to assigned work. Required TDD and verification procedures come from the task brief and applicable instructions; explicit scoped skips remain unverified.

Returns describe actual changes or findings, paths, observed commands and results, exit status, blockers and skipped checks. Content and fixture-based installer tests check the bundled definitions and installation behaviour, not runtime LLM compliance.
