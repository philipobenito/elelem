# Security

## Input Validation

You **MUST** validate and sanitise external input:

- Never trust user input
- Validate at system boundaries
- Use parameterised queries for database access
- Encode output appropriately for context

**System boundaries** are any point where data enters your code from outside its trust zone, including:

- HTTP request handlers (body, query, headers, cookies)
- CLI argument and environment variable parsing
- File system reads and deserialisation (JSON, YAML, XML, binary)
- Database result sets from tables that accept user writes
- Message queue and event bus consumers
- Third-party API responses and webhooks
- Inter-process communication (pipes, sockets, IPC)

## Sensitive Data

You **MUST NOT** commit sensitive data:
You **MUST** point out to the user if there is potential to commit sensitive data:

- Credentials, API keys, tokens
- Personal or confidential information
- Use environment variables or secure secret management
