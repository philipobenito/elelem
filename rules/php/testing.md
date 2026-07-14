---
# noinspection YAMLUnresolvedAlias
globs: **/tests/**/*.php, **/*Test.php, **/phpunit.xml
---

# PHP Testing

## Framework

Use `PHPUnit` for testing. For BDD-style, use `Pest` if the project already uses it.

## File and Function Naming

- Test files: `<Class>Test.php` in the `tests/` directory, mirroring the `src/` structure
- Test classes: `class UserTest extends TestCase`
- Test methods: `public function testFeatureScenario()` or `public function test_feature_scenario()` using descriptive phrases
- Use data providers for parameterised tests: `#[DataProvider('providerName')]`

## Structure

- One assertion concept per test
- Use `setUp()` and `tearDown()` for common test fixtures
- Prefer test-specific set-up over shared mutable state between tests
- Use data providers (`#[DataProvider]`) rather than copy-pasting tests
- Organise tests in directories mirroring your source code structure

## Assertions

- Use specific assertions: `assertSame()` for identity, `assertEquals()` for equality
- For exceptions: `$this->expectException(InvalidArgumentException::class)`
- For strings: use `assertStringContainsString()`, `assertStringStartsWith()`, etc.
- For arrays: use `assertArrayHasKey()`, `assertContains()`, `assertCount()`
- Provide custom messages for assertions: `$this->assertTrue($result, 'Expected user to be active')`

## What Not to Mock

- Do not mock the code under test
- Do not mock value objects or data transfer objects
- Mock only at boundaries: HTTP clients (use `symfony/http-client` test tools), databases (use in-memory SQLite), external APIs
- Use interfaces and dependency injection to make code testable
- Prefer fakes over mocks when possible (real implementations with test configuration)
