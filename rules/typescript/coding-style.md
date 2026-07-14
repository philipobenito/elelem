---
# noinspection YAMLUnresolvedAlias
globs: **/*.ts, **/*.tsx, **/*.d.ts
---

# TypeScript Coding Style

## Type Safety

You **MUST** use explicit types on all function signatures (parameters and return types) and on exported constants/variables.

- Prefer `interface` for object shapes that may be extended; `type` for unions, intersections, and mapped types
- Use `unknown` over `any` for truly dynamic values; narrow with type guards
- Never use `any` without a comment explaining why and a plan to remove it
- Use strict null checks; prefer `value | null` or `value | undefined` over optional fields when the distinction matters
- Use const assertions (`as const`) for literal types and readonly tuples

## Modern TypeScript

- Use ES6+ features: arrow functions, destructuring, template literals, spread operators
- Use `const` by default; `let` only when reassignment is needed; never use `var`
- Use optional chaining (`?.`) and nullish coalescing (`??`) for safer property access
- Use satisfies operator when you want both type checking and inference
- Prefer utility types (`Partial<T>`, `Pick<T>`, `Omit<T>`) over manual type manipulation

## Strings

- Use template literals (backticks) for interpolation and multi-line strings
- Prefer single quotes for plain strings (or follow project convention)
- Use template literal types for string-based types when appropriate

## Imports

- Use ES modules (`import`/`export`) exclusively
- Order: external dependencies, internal modules, local files, type-only imports
- Use `import type` for type-only imports to enable better tree-shaking
- Never import entire libraries when you only need specific functions
- Use path aliases (from `tsconfig.json`) for cleaner imports

## Naming

- `camelCase` for variables, functions, and methods
- `PascalCase` for classes, interfaces, type aliases, and enums
- `SCREAMING_SNAKE_CASE` for module-level constants
- Prefix private class fields with `#` or use TypeScript's `private` keyword
- Do not prefix interfaces with `I` (e.g., use `User` not `IUser`)

## Idioms

- Use array methods (`map`, `filter`, `reduce`) over manual loops when appropriate
- Use object/array destructuring to extract values
- Use type guards and type predicates for narrowing
- Prefer discriminated unions over enums for state machines
- Use `readonly` for immutable data structures
- Prefer composition over inheritance; use interfaces for contracts
