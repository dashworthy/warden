---
type: llm
focus: last_message
weight: 1
arm: both
---
The final message reports trimming as proved for both the HTTP API (POST /todos) and the CLI (node
cli.js add), each with the command run and the observed, trimmed title read back. FAIL if it covers
only one entry point, or reports a pass without evidence.
