---
type: llm
focus: last_message
weight: 1
arm: both
---
The report identifies the conflict between WARD-003 ("Retry every external API call") and WARD-004
("Never retry non-idempotent requests"): a POST without an idempotency key can't satisfy both. It
proposes a resolution, such as scoping WARD-003 to idempotent requests or requiring an idempotency
key.
