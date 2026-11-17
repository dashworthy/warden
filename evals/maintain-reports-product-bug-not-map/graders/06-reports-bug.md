---
type: llm
focus: last_message
weight: 1
arm: both
---
The final message reports adding a todo as broken in the app (a product bug, not doc drift), citing
the observed error (normalise is not defined) and store.js, and leaves the fix to the user. It ends
with one outcome (clean, changed or blocked). FAIL if it fixes the bug, rewrites the map to match
the broken behavior, or does not mention the failure.
