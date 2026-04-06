# Error Handling

## Explicit Error States

You **SHOULD** make error conditions explicit and handled:

- Avoid silent failures
- Use exceptions for exceptional circumstances, not control flow
- Validate input at system boundaries (see `security.md` for the definition of a system boundary)
- Return explicit error types (Result/Either) for operations whose failure is an expected outcome rather than a bug (e.g. parsing, network calls, file I/O)

## Error Messages

You **MUST** provide actionable error messages:

- Describe what went wrong
- Include relevant context (what operation was attempted)
- Suggest remediation where applicable
- Use British English
