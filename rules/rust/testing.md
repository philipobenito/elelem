---
# noinspection YAMLUnresolvedAlias
globs: **/*.rs
---

# Rust Testing

## Framework

Use the built-in test framework (`#[test]` and `#[cfg(test)]`). For advanced features, use `rstest` for parameterised tests.

## File and Function Naming

- Tests live in a `tests` module at the bottom of each file: `#[cfg(test)] mod tests { ... }`
- Integration tests live in `tests/` directory at the project root
- Test functions: `#[test] fn test_feature_scenario()` using descriptive names
- Benchmark functions: use `criterion` crate for benchmarking

## Structure

- One assertion concept per test; multiple `assert!` lines are fine if verifying one behaviour
- Use `#[should_panic(expected = "message")]` for tests that expect panics
- Use `Result<(), E>` return type for tests with `?` operator
- Group related tests in nested `mod` blocks within the tests module
- Use `rstest` for parameterised tests rather than copy-pasting

## Assertions

- Use `assert_eq!(left, right)` for equality checks (shows both values on failure)
- Use `assert_ne!(left, right)` for inequality
- Use `assert!(condition)` for boolean checks
- Use `assert!(result.is_ok())` or `assert!(result.is_err())` for Result checks
- For custom error messages: `assert_eq!(left, right, "context: {}", extra_info)`

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or simple data structures
- Mock only at boundaries: network (use test servers), file system (`tempfile`), time (`mock_instant`), randomness
- Use traits and dependency injection for testability
- Prefer fakes (real implementations with test configuration) over mocks when possible
