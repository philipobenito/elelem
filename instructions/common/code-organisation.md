# Code Organisation

## File Structure

You **SHOULD** organise files to reflect domain concepts:

- One primary class or module per file (language-dependent)
- Group related functionality together
- Use directory structure to represent architectural boundaries

## Dependency Management

You **MUST NOT** add new runtime or development dependencies without explicit user approval. When proposing a dependency, you **MUST** tell the user:

- Why the standard library or existing project dependencies are insufficient
- The package name, current version, and licence
- Whether it is actively maintained (last release within 12 months, open issues triaged)
- Its approximate installation size and transitive dependency count

You **SHOULD** prefer the standard library or a small inline implementation when a dependency would add fewer than ~50 lines of logic.

## Import Organisation

You **SHOULD** organise imports logically:

- Group by type (standard library, third-party, local)
- Sort alphabetically within groups (allow formatting tools to handle this if defined in project instructions)
- Remove unused imports
