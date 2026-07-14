---
# noinspection YAMLUnresolvedAlias
globs: **/*.php
---

# PHP Coding Style

## Type Declarations

You **MUST** use type declarations on all function signatures (parameters and return types, PHP 7.0+) and on class properties (PHP 7.4+).

- Use strict types: `declare(strict_types=1);` at the top of every file
- Use union types (`string|int`) for parameters that accept multiple types (PHP 8.0+)
- Use nullable types (`?string`) or union with null (`string|null`)
- Never omit return types; use `void` for functions that don't return a value
- Use `mixed` only when a value can genuinely be any type

## Modern PHP

- Use PHP 8.2+ features: readonly classes, enums, constructor property promotion, named arguments
- Use arrow functions (`fn($x) => $x * 2`) for simple callbacks
- Use null-safe operator (`?->`) for safe property access (PHP 8.0+)
- Use match expression over switch when appropriate (PHP 8.0+)
- Use named arguments for clarity: `function(name: 'John', age: 30)`

## Strings

- Use single quotes for plain strings; double quotes only when interpolation is needed
- Use heredoc/nowdoc for multi-line strings
- Prefer string interpolation (`"Hello $name"`) over concatenation for readability

## Imports

- Use fully qualified namespaces or `use` statements; never use functions/classes without importing
- Order: external dependencies, framework classes, internal classes
- Group related imports together
- Use `use function` for function imports, `use const` for constant imports

## Naming

- `camelCase` for methods and properties
- `PascalCase` for classes, interfaces, traits, and enums
- `SCREAMING_SNAKE_CASE` for constants
- `snake_case` for array keys (by convention)
- Prefix interfaces with no special marker (use `UserRepository` not `UserRepositoryInterface`)

## Idioms

- Use array spread operator (`...`) for merging arrays (PHP 7.4+)
- Use named arguments for better readability with many parameters
- Use constructor property promotion (PHP 8.0+): `public function __construct(public string $name)`
- Use `readonly` for immutable properties (PHP 8.1+)
- Prefer dependency injection over global state
- Use typed properties to avoid runtime type errors
- Use `final` by default for classes unless designed for inheritance
