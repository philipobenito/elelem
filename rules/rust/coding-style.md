---
# noinspection YAMLUnresolvedAlias
globs: **/*.rs
---

# Rust Coding Style

## Type Safety

Rust's type system is your friend. Use it fully:

- Prefer `Result<T, E>` for recoverable errors; `panic!`/`unwrap()` only for programmer errors
- Use `Option<T>` over null; pattern match or use combinator methods (`map`, `and_then`, `unwrap_or`)
- Never use `unwrap()` or `expect()` without a comment explaining why it's safe
- Use custom error types with `thiserror` or `anyhow` for better error handling
- Leverage the borrow checker; prefer borrowing (`&T`, `&mut T`) over cloning

## Strings

- Use `String` for owned strings, `&str` for string slices
- Use `format!()` macro for string interpolation
- Prefer `&str` in function parameters unless you need ownership
- Use raw string literals (`r"..."`) for regex patterns and paths with backslashes

## Imports

- Use `rustfmt` to organise imports automatically
- Order: `std`, external crates, internal modules, separated by blank lines
- Use `pub use` to re-export items for public API ergonomics
- Prefer explicit imports over glob imports except for preludes

## Naming

- `snake_case` for functions, methods, variables, modules, and macros
- `PascalCase` for types (structs, enums, traits)
- `SCREAMING_SNAKE_CASE` for constants and statics
- Trait names: active verbs (`Read`, `Write`) or adjectives (`Clone`, `Debug`)
- Use single-letter generics (`T`, `E`, `K`, `V`) or descriptive names for complex bounds

## Idioms

- Use pattern matching extensively; exhaust all cases or use `_` deliberately
- Prefer iterators (`iter()`, `map()`, `filter()`) over indexing and loops
- Use `?` operator for propagating `Result` and `Option`
- Implement standard traits (`Debug`, `Clone`, `PartialEq`) with `#[derive(...)]`
- Use newtype pattern for type safety: `struct UserId(u64)`
- Prefer composition over inheritance; use traits for shared behaviour
- Use builder pattern for complex initialisation
- Write unsafe code only when necessary and encapsulate it with safe APIs
