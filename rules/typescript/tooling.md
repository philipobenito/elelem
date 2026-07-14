---
# noinspection YAMLUnresolvedAlias
globs: **/tsconfig.json, **/tsconfig.*.json, **/package.json
---

# TypeScript Tooling

## Project Layout

Use a standard TypeScript project layout:

```
project/
  package.json
  tsconfig.json
  src/
    index.ts
  tests/
  dist/ (build output)
```

## Dependency Management

- `package.json` is the single source of truth for dependencies
- Prefer `pnpm` for fast, disk-efficient installs. Fall back to `npm` (v8+) or `yarn` if the project uses it
- Install types: `pnpm add -D @types/node @types/...` for packages without built-in types
- Never edit lock files by hand
- Separate `dependencies` (runtime) from `devDependencies` (build/test tools)

## TypeScript Configuration

- Enable strict mode: `"strict": true` in `tsconfig.json`
- Use `"module": "ESNext"` and `"target": "ES2022"` or higher
- Enable `"moduleResolution": "bundler"` for modern bundler usage
- Set `"skipLibCheck": true` to speed up compilation
- Configure path aliases in `tsconfig.json` for cleaner imports
- Use `tsconfig.base.json` for monorepos with shared configuration

## Formatting and Linting

- Formatter: `prettier` with project-specific configuration
- Linter: `eslint` with `@typescript-eslint/parser` and recommended rules
- Type checker: `tsc --noEmit` for type checking without emitting files
- Never suppress a lint or type error without a comment explaining why

## Build and Run

- Use `tsx` or `ts-node` for running TypeScript directly in development
- Use `tsc` for type checking and producing declaration files
- Use a bundler (`vite`, `esbuild`, `tsup`) for production builds
- Define npm scripts in `package.json`: `dev`, `build`, `test`, `typecheck`, `lint`
- Emit source maps for debugging: `"sourceMap": true`
