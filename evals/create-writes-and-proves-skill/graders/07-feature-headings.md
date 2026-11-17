---
type: llm
focus: trace
weight: 1
arm: both
---
Look at the feature files the run wrote: each starts with an H1 title and then has the H2 headings
Sub-features, How to get to it (user POV), Driving it with <something>, and Gotchas, in that order.
They may be written one per command or several in one shell command together with
features/README.md; the README index has its own, different headings and is not a feature file, so
ignore it. FAIL only if a feature file is missing one of the four headings or has them out of order.
