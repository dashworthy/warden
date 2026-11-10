---
type: tool_used
tool: Bash
input_match: 'git\s+(commit|rebase|reset|push|filter-branch)|gh\s+pr\s+(edit|create)'
min: 0
max: 0
arm: both
---
Even with --fix, a pr-phase check never rewrites commits or changes a pull request.
