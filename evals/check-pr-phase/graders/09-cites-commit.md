---
type: llm
focus: last_message
weight: 1
arm: both
---
PASS if the WARD-002 finding identifies the commit whose subject is "stuff" (by its subject or its
short hash) and recommends a Conventional Commits subject for it, such as
`feat(invoices): register the export route`. Rewording the commit can be left to the human.
FAIL if the finding doesn't point at that commit, or if the report flags the unbounded query as a
failure of this check.
