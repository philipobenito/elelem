---
# noinspection YAMLUnresolvedAlias
globs: **/*_test.go
---

# Go Testing

## Framework

Use the standard `testing` package. For advanced assertions, use `testify/assert` or `testify/require` if the project already uses it.

## File and Function Naming

- Test files: `<module>_test.go` in the same package (or `<module>_test` for external tests)
- Test functions: `func TestFeature(t *testing.T)` or `func TestFeature_Scenario(t *testing.T)` using descriptive phrases
- Benchmark functions: `func BenchmarkFeature(b *testing.B)`
- Example functions: `func ExampleFeature()` for documentation

## Structure

- Use subtests with `t.Run("scenario", func(t *testing.T) {...})` to group related tests
- Table-driven tests for testing multiple inputs/outputs
- Use `t.Helper()` in test helper functions to improve error reporting
- Use `t.Parallel()` when tests can run concurrently

## Assertions

- Use `t.Fatalf()` when a failure means later assertions are meaningless
- Use `t.Errorf()` when you want to report an error and continue
- Prefer `testify/require` for fatal assertions, `testify/assert` for non-fatal
- Format error messages: `"got %v, want %v"` or similar

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or simple data structures
- Mock only at boundaries: network (use `httptest`), file system (`t.TempDir()`), time, randomness
- Use interfaces to enable testing without heavy mocking frameworks
