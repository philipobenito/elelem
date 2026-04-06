---
# noinspection YAMLUnresolvedAlias
globs: **/pyproject.toml, **/requirements*.txt, **/uv.lock, **/poetry.lock
---

# Python Tooling

## Project Layout

Use a `src/` layout for packages:

```
project/
  pyproject.toml
  src/
    mypackage/
      __init__.py
  tests/
```

## Dependency Management

- `pyproject.toml` is the single source of truth for dependencies and metadata
- Prefer `uv` for environment and dependency management. Fall back to `poetry` if the project already uses it, or `pip` + `pip-tools` if neither is present
- Never edit `uv.lock` / `poetry.lock` / `requirements.txt` by hand; regenerate via the tool
- Pin direct dependencies with lower bounds only (`requests>=2.31`) in `pyproject.toml`; let the lockfile pin transitively
- Separate groups: runtime dependencies, `dev` (test, lint, format), and optional extras

## Formatting and Linting

- Formatter: `ruff format` (or `black` if the project already uses it)
- Linter: `ruff check` with the project's configured rule set
- Type checker: `mypy` or `pyright` per project convention
- Never silence a lint or type error with an inline ignore without a comment explaining why and a ticket reference

## Virtual Environments

- Never install packages into the system Python
- Activate the project's venv before running any Python command that touches dependencies
- If no venv exists and the user asks you to install something, stop and ask which tool to use
