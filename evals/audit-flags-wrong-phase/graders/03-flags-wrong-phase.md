---
type: llm
focus: last_message
weight: 1
arm: both
---
PASS if the report does both:
1. says WARD-002 is checked in the wrong phase: it has no `phases` (so it runs as a code ward) but
   it governs pull request descriptions;
2. recommends giving it the `pr` phase (`phases: [pr]` or equivalent) and updating its Summary row.
FAIL if either is missing, if it recommends removing or merging WARD-002, or if it says WARD-001
(bounded queries) is in the wrong phase.
