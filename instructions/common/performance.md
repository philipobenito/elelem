# Performance and Optimisation

## Premature Optimisation

You **SHOULD** prioritise correctness and clarity over premature optimisation:

- Write clear code first
- Measure performance before optimising and cite the measurement when you do
- Prefer extracting optimised logic into a well-named function (e.g. `encodeFramesUsingSIMDFastPath`) over adding explanatory comments
- Where a comment is genuinely unavoidable for an optimisation, it must meet the conditions in `coding-style.md` (benchmark reference, cannot be extracted)

## Resource Management

You **MUST** handle resources properly:

- Close file handles, database connections, network sockets
- Use language-appropriate patterns (RAII, defer, using statements, context managers)
- Avoid resource leaks
