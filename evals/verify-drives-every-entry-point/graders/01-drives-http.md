---
type: tool_used
tool: Bash
input_match: 'curl[^\n]*-X\s*POST[^\n]*todos|curl[^\n]*todos[^\n]*-X\s*POST|curl[^\n]*-d[^\n]*todos'
min: 1
arm: both
---
The HTTP entry point is driven with a POST to /todos.
