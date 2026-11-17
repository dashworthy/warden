---
type: llm
focus: trace
weight: 1
arm: both
---
The run wrote a verify skill: a SKILL.md for verify-<app> plus features/README.md and at least one
feature file, with the Write tool or a shell command, either at .claude/skills/verify-<app>/ in the
repo or, if writing there was blocked, at the same relative path in a scratch copy, with the exact
copy command handed over. FAIL if no SKILL.md or no feature file was written anywhere.
