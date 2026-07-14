---
# noinspection YAMLUnresolvedAlias
globs: **/package.json, **/package-lock.json, **/pnpm-lock.yaml, **/yarn.lock
---

# JavaScript Tooling

## Project Layout

Use a standard Node.js layout:

```
project/
  package.json
  src/
    index.js
  tests/
  node_modules/
```

## Dependency Management

- `package.json` is the single source of truth for dependencies
- Prefer `pnpm` for fast, disk-efficient installs. Fall back to `npm` (v8+) or `yarn` if the project uses it
- Never edit `package-lock.json`, `pnpm-lock.yaml`, or `yarn.lock` by hand
- Use exact versions (`"package": "1.2.3"`) for applications, ranges (`"^1.2.3"`) for libraries
- Separate `dependencies` (runtime) from `devDependencies` (build/test tools)
- Run `pnpm update` / `npm update` to update dependencies within semver ranges

## Formatting and Linting

- Formatter: `prettier` with project-specific configuration
- Linter: `eslint` with modern config (`@eslint/js`, `eslint-config-prettier`)
- Use `"type": "module"` in `package.json` for ESM by default
- Never suppress a lint error without a comment explaining why

## Build and Run

- Use `node` directly for running scripts in development
- Use a bundler (`vite`, `esbuild`, `rollup`) for production builds
- Define npm scripts in `package.json` for common tasks (`dev`, `build`, `test`, `lint`)
- Use `.env` files for environment variables (with `dotenv` or Vite's built-in support)
