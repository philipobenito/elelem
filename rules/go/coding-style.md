---
# noinspection YAMLUnresolvedAlias
globs: **/*.go
---

# Go Coding Style

## Type Safety

You **MUST** handle all errors explicitly. Never ignore errors with `_` unless you document why in a comment.

- Return errors as the last return value
- Wrap errors with `fmt.Errorf("context: %w", err)` to add context
- Use custom error types when callers need to distinguish error cases
- Never panic in library code; reserve panics for truly unrecoverable programmer errors

## Strings

- Use raw string literals (backticks) for multi-line strings or strings with many escape sequences
- Use standard string interpolation with `fmt.Sprintf` for complex formatting
- Prefer `strings.Builder` over string concatenation in loops

## Imports

- Use `goimports` to organise imports automatically
- Order: standard library, third-party, first-party, separated by blank lines
- Group related imports within each section
- Never use dot imports (`. "package"`) except in test files when absolutely necessary

## Naming

- `MixedCaps` or `mixedCaps` (no underscores) for multi-word names
- Exported names start with uppercase; unexported with lowercase
- Interface names: single-method interfaces end in `-er` (e.g., `Reader`, `Writer`)
- Acronyms are all caps when exported (`HTTPServer`, `XMLParser`) or all lowercase when unexported (`httpServer`)
- Package names: short, lowercase, no underscores, no plurals

## Idioms

- Use `defer` for clean-up operations (close, unlock, etc.)
- Accept interfaces, return concrete types
- Prefer composition over inheritance; embed types when appropriate
- Use goroutines and channels for concurrency; avoid shared mutable state
- Make the zero value useful when possible
- Use `context.Context` as the first parameter for functions that may block or need cancellation
