# Testing Anti-Patterns

**Load this reference when:** writing or changing tests, adding mocks, or tempted to add test-only methods to production code.

**Core principle:** Test what the code does, not what the mocks do. Following strict TDD prevents all of these.

## The Iron Laws

```
1. NEVER test mock behaviour
2. NEVER add test-only methods to production classes
3. NEVER mock without understanding dependencies
```

## Anti-Pattern 1: Testing Mock Behaviour

```typescript
// BAD: Testing that the mock exists
test('renders sidebar', () => {
  render(<Page />);
  expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();
});

// GOOD: Test real component or don't mock it
test('renders sidebar', () => {
  render(<Page />);
  expect(screen.getByRole('navigation')).toBeInTheDocument();
});
```

**Gate:** Before asserting on any mock element, ask: "Am I testing real behaviour or mock existence?" If mock existence, delete the assertion or unmock.

## Anti-Pattern 2: Test-Only Methods in Production

```typescript
// BAD: destroy() only used in tests
class Session {
  async destroy() { await this._workspaceManager?.destroyWorkspace(this.id); }
}

// GOOD: Test utilities handle test cleanup
export async function cleanupSession(session: Session) {
  const workspace = session.getWorkspaceInfo();
  if (workspace) await workspaceManager.destroyWorkspace(workspace.id);
}
```

**Gate:** Before adding any method to a production class, ask: "Is this only used by tests?" If yes, put it in test utilities instead.

## Anti-Pattern 3: Mocking Without Understanding

```typescript
// BAD: Mock prevents config write that test depends on
vi.mock('ToolCatalog', () => ({
  discoverAndCacheTools: vi.fn().mockResolvedValue(undefined)
}));
await addServer(config);
await addServer(config);  // Should throw but won't

// GOOD: Mock at correct level, preserve behaviour test needs
vi.mock('MCPServerManager');  // Just mock slow server startup
await addServer(config);      // Config written
await addServer(config);      // Duplicate detected
```

**Gate:** Before mocking, answer three questions:
1. What side effects does the real method have?
2. Does this test depend on any of those side effects?
3. If yes, mock at a lower level that preserves the necessary behaviour.

## Anti-Pattern 4: Incomplete Mocks

```typescript
// BAD: Only fields you think you need
const mockResponse = {
  status: 'success',
  data: { userId: '123', name: 'Alice' }
};

// GOOD: Mirror real API completeness
const mockResponse = {
  status: 'success',
  data: { userId: '123', name: 'Alice' },
  metadata: { requestId: 'req-789', timestamp: 1234567890 }
};
```

**Gate:** Before creating mock responses, check the real API response schema. Include ALL fields the system might consume downstream.

## Anti-Pattern 5: Tests as Afterthought

Tests are part of implementation, not optional follow-up. TDD cycle: write a failing test, implement to pass, refactor, then claim complete.

## Quick Reference

| Anti-Pattern                    | Fix                                           |
|---------------------------------|-----------------------------------------------|
| Assert on mock elements         | Test real component or unmock it              |
| Test-only methods in production | Move to test utilities                        |
| Mock without understanding      | Understand dependencies first, mock minimally |
| Incomplete mocks                | Mirror real API completely                    |
| Tests as afterthought           | TDD: tests first                              |
| Over-complex mocks              | Consider integration tests                    |

## Red Flags

- Assertion checks for `*-mock` test IDs
- Methods only called in test files
- Mock setup is >50% of the test
- Test fails when you remove mock
- Can't explain why mock is needed
- Mocking "just to be safe"
