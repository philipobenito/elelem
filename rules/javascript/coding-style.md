---
# noinspection YAMLUnresolvedAlias
globs: **/*.js, **/*.mjs, **/*.cjs
---

# JavaScript Coding Style

## Type Safety

Use JSDoc type annotations for better IDE support and runtime safety checks:

- Document function parameters and return types with `@param` and `@returns`
- Use `@type` for variable type hints
- Consider migrating to TypeScript for large codebases

## Modern JavaScript

- Use ES6+ features: arrow functions, destructuring, template literals, spread operators
- Use `const` by default; `let` only when reassignment is needed; never use `var`
- Use optional chaining (`?.`) and nullish coalescing (`??`) for safer property access
- Use async/await over raw promises; avoid callback hell

## Strings

- Use template literals (backticks) for interpolation and multi-line strings
- Prefer single quotes for plain strings (or follow project convention)
- Use `String.trim()`, `String.includes()`, etc. over regex when possible

## Imports

- Use ES modules (`import`/`export`) over CommonJS (`require`/`module.exports`) in new code
- Order: external dependencies, internal modules, local files
- Use named exports over default exports for better refactoring support
- Never import entire libraries when you only need specific functions

## Naming

- `camelCase` for variables, functions, and methods
- `PascalCase` for classes and constructor functions
- `SCREAMING_SNAKE_CASE` for module-level constants
- Prefix private class fields with `#` (private class features)

## Idioms

- Use array methods (`map`, `filter`, `reduce`) over manual loops when appropriate
- Use object/array destructuring to extract values
- Use spread syntax for copying/merging arrays and objects
- Use `Object.freeze()` for immutable objects
- Prefer pure functions; minimise side effects
- Use `===` and `!==` for comparisons; never use `==` or `!=`
