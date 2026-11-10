---
type: tool_used
tool: Bash
input_match: 'git\s+(commit|rebase|reset|push)|gh\s+pr\s+(edit|create)'
min: 0
max: 0
arm: both
---
A pr-phase check never rewrites commits or changes a pull request.
