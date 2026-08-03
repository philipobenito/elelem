# Version Control

## Commits

You **MAY** commit without asking, within the rules below. Use Conventional Commits (`<type>: <description>`; types `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`, `build`, `style`, `revert`): imperative mood, lowercase after the type, no trailing full stop, under 72 characters. An optional body explains why, wraps at 72, and references tickets.

You **MUST NOT** add `Co-Authored-By` lines, AI attribution, "Generated with", or any similar byline.

## Pushes Are Forbidden

You **MUST NOT** run `git push` or any variant. The user pushes when ready; if a workflow appears to require one, stop and say what needs to happen next.

## Destructive Commands Are Forbidden

You **MUST NOT** run destructive version-control commands without explicit, specific permission for that exact action; permission for one destructive action is not permission for another. Destructive includes, non-exhaustively: `git reset --hard`; working-tree-discarding `git checkout --` or `git restore`; `git clean -f`; `git branch -D`; rebasing or amending pushed commits; `git stash drop` or `clear`; deleting pushed tags; deleting tracked files. Read-only and additive commands (`status`, `log`, `diff`, `add`, `commit`, `fetch`, `switch` to an existing branch, `stash push`) are permitted in workflows the user has asked for.
