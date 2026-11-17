---
type: llm
focus: trace
weight: 1
arm: both
---
Every feature file the run wrote under features/ (other than README.md) has an H1 title, a one-
paragraph description, and exactly these H2 sections in order: Sub-features, How to get to it (user
POV), Driving it with <harness>, Gotchas. FAIL if any feature file is missing one or uses different
headings.
