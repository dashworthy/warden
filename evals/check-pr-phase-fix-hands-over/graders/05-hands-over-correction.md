---
type: llm
focus: last_message
weight: 1
arm: both
---
PASS if the final message gives the human the WARD-002 correction to make themselves: it names
the commit with subject "stuff" and proposes a Conventional Commits subject for it (or tells the
human how to reword it), without claiming the commit was already reworded. FAIL if it claims it
rewrote the commit, or doesn't mention the failing commit subject.
