---
type: llm
focus: trace
weight: 1
arm: both
---
After running the generated cleanup, the run checked that the captured evidence still exists at the
location the skill names (for example by listing it). FAIL if the run never ran a cleanup, or never
checked the evidence after it.
