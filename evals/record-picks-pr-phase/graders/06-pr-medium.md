---
type: llm
focus: last_message
weight: 1
arm: both
---
PASS if the drafted ward is a pull-request ward written in that medium: its Violations and
Compliant examples are PR description text (for example a body with and without `Closes #123`),
not application code, and its example Sample is a PR description too. FAIL if the examples are
application code, or the ward is drafted as a code-review ward.
