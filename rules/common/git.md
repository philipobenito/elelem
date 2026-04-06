# Version Control

## Commits Are Permitted

You **MAY** create commits without asking, provided they follow the rules below. You do **not** need to request permission for each commit.

## Commit Message Format

You **MUST** use Conventional Commits:

```
<type>: <description>

<optional body>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`, `build`, `style`, `revert`

**Rules for the subject line:**

- Use the imperative mood (`add`, not `added` or `adds`)
- Lowercase after the type (`feat: add colour picker`, not `feat: Add colour picker`)
- No trailing full stop
- Aim for under 72 characters
- British English (see `language.md`)

**Body (optional):**

- Explain *why*, not *what* (the diff shows the what)
- Wrap at 72 characters
- Reference tickets or issues where relevant

## Pushes Are Forbidden

You **MUST NOT** run `git push` (or any variant) under any circumstances. The user will push when they are ready. If a workflow appears to require a push (e.g. opening a pull request), stop and tell the user what needs to happen next.

## Destructive Commands Are Forbidden

You **MUST NOT** run destructive version control commands without explicit, specific permission from the user for that exact action. Permission for one destructive action is not permission for another.

**Destructive commands** include but are not limited to:

- `git reset --hard` and `git reset` onto a different branch
- `git checkout -- <file>` / `git restore` that discards working-tree changes
- `git clean -f` / `-fd` / `-fx`
- `git branch -D` (force delete)
- `git rebase` of commits that have already been pushed
- `git commit --amend` on commits that have already been pushed
- `git stash drop` / `git stash clear`
- `git tag -d` of pushed tags
- Any `rm` or file deletion of tracked files intended as part of version control

Anything else read-only or non-destructive (`git status`, `git log`, `git diff`, `git add`, `git commit`, `git fetch`, `git switch <existing-branch>`, `git stash push`) is permitted as part of workflows the user has asked you to perform.

## Co-Authored-By

You **MUST NOT** add `Co-Authored-By` lines, AI attribution lines, "Generated with", or any similar bylines to commit messages. Commit messages contain only the description of the change.
