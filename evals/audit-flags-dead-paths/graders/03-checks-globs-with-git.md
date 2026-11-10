---
type: tool_used
tool: Bash
input_match: ':\(glob\)'
min: 1
arm: both
---
Glob liveness is decided by git (`git ls-files -- ':(glob)…'`), not by eye.
