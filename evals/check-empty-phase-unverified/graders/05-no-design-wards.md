---
type: llm
focus: last_message
weight: 1
arm: both
---
PASS if the final message says the registry has no wards in the design phase (or no design wards),
reports the result as UNVERIFIED rather than PASS, and points to recording one (for example with
/record-ward). FAIL if it reports PASS, or reviews the plan against the code ward or standards it
made up.
