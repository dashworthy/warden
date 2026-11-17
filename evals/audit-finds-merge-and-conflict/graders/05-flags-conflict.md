---
type: llm
focus: last_message
weight: 1
arm: both
---
The report identifies the conflict between RULE-003 ("Retry every external API call") and RULE-004
("Never retry non-idempotent requests"): a POST without an idempotency key can't satisfy both. It
proposes a resolution, such as scoping RULE-003 to idempotent requests or requiring an idempotency
key.
