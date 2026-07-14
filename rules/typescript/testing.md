---
# noinspection YAMLUnresolvedAlias
globs: **/*.test.ts, **/*.spec.ts, **/*.test.tsx, **/*.spec.tsx, **/tests/**/*.ts, **/jest.config.ts, **/vitest.config.ts
---

# TypeScript Testing

## Framework

Use `vitest` for new projects (fast, native ESM and TypeScript support). Use `jest` with `ts-jest` if the project already uses it.

## File and Function Naming

- Test files: `<module>.test.ts` (preferred) or `<module>.spec.ts`
- Test functions: `test('should do something specific', () => {})` or `it('does something', () => {})`
- Group related tests with `describe('Feature', () => {})`
- Type your test data and mocks for better safety

## Structure

- One assertion concept per test
- Use `beforeEach`/`afterEach` for common set-up/teardown
- Use `describe` blocks to organise related tests
- Prefer test-specific set-up over shared state between tests
- Use parameterised tests (`test.each`) rather than copy-pasting
- Type your fixtures and test data properly

## Assertions

- Use the framework's built-in assertions: `expect(value).toBe(expected)`
- For objects: use `.toEqual()` for deep equality, `.toBe()` for reference equality
- For async: use `await expect(promise).resolves.toBe(value)` or `await expect(promise).rejects.toThrow()`
- Use type assertions sparingly; prefer proper typing of test data
- Leverage TypeScript to catch type mismatches at compile time

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or simple data structures
- Mock only at boundaries: HTTP requests (`msw`), timers (`vi.useFakeTimers`), file system, DOM
- Use dependency injection with typed interfaces to make code testable
- Type your mocks properly with the same interfaces as the real implementations
