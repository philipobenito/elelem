---
# noinspection YAMLUnresolvedAlias
globs: **/*.test.js, **/*.spec.js, **/tests/**/*.js, **/jest.config.js, **/vitest.config.js
---

# JavaScript Testing

## Framework

Use `vitest` for new projects (fast, ESM-native, compatible with Jest). Use `jest` if the project already uses it. Avoid Mocha/Chai in new code.

## File and Function Naming

- Test files: `<module>.test.js` (preferred) or `<module>.spec.js`
- Test functions: `test('should do something specific', () => {})` or `it('does something', () => {})`
- Group related tests with `describe('Feature', () => {})`

## Structure

- One assertion concept per test
- Use `beforeEach`/`afterEach` for common set-up/teardown
- Use `describe` blocks to organise related tests
- Prefer test-specific set-up over shared state between tests
- Use parameterised tests (`test.each`) rather than copy-pasting

## Assertions

- Use the framework's built-in assertions: `expect(value).toBe(expected)`
- For objects: use `.toEqual()` for deep equality, `.toBe()` for reference equality
- For async: use `await expect(promise).resolves.toBe(value)` or `await expect(promise).rejects.toThrow()`
- Chain matchers for clarity: `expect(arr).toHaveLength(3)`

## What Not to Mock

- Do not mock the code under test
- Do not mock pure functions or simple data structures
- Mock only at boundaries: HTTP requests (`msw`), timers (`vi.useFakeTimers`), file system, DOM
- Use dependency injection to make code testable without heavy mocking
