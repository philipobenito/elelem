---
# noinspection YAMLUnresolvedAlias
globs: **/*.py, **/*.pyi
---

# Python Coding Style

## Type Hints

You **MUST** use type hints on all function signatures (parameters and return types) and on module-level constants where the type is non-obvious.

- Prefer built-in generics (`list[str]`, `dict[str, int]`) over `typing.List` / `typing.Dict` (Python 3.9+)
- Use `|` for union types (`str | None`) over `Optional[str]` (Python 3.10+)
- Use `from __future__ import annotations` only when targeting Python <3.10
- Never use bare `Any` unless the type is genuinely dynamic; prefer a protocol or `object` with narrowing

## Strings

- Use f-strings for interpolation. Never use `%` formatting or `str.format()` in new code
- Use double quotes by default; single quotes only when the string contains double quotes

## Imports

- Never use wildcard imports (`from module import *`)
- Order: standard library, third-party, first-party local, separated by blank lines
- Absolute imports only, except within a package's own tests

## Naming

- `snake_case` for functions, methods, variables, modules
- `PascalCase` for classes
- `SCREAMING_SNAKE_CASE` for module-level constants
- Leading underscore (`_name`) for module-private; double leading (`__name`) only for name-mangling in classes

## Idioms

- Use `pathlib.Path` over `os.path` for filesystem operations
- Use context managers (`with`) for any resource with `close()` or `__exit__`
- Prefer comprehensions over `map`/`filter` with lambdas, but only when they remain readable on one line
- Use `enumerate()` and `zip()` instead of index arithmetic
