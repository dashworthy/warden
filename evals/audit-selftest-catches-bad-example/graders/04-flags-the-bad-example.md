---
type: llm
focus: last_message
weight: 1
arm: both
---
The report says RULE-002's example is broken: its expected fix checks the request body by hand instead
of parsing it with a zod schema, so the fix itself fails RULE-002 (a failed self-test, or an example
that contradicts the rule). It recommends correcting that example's fix. FAIL if the problem with
RULE-002's example isn't reported.
