---
type: llm
focus: last_message
weight: 1
arm: both
---
The report says WARD-002's example is broken: its expected fix checks the request body by hand instead
of parsing it with a zod schema, so the fix itself fails WARD-002 (a failed self-test, or an example
that contradicts the ward). It recommends correcting that example's fix. FAIL if the problem with
WARD-002's example isn't reported.
