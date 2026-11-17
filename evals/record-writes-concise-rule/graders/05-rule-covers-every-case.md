---
type: llm
focus: last_message
weight: 1
arm: both
---
Judge only the proposed rule.md text. The request listed these bad payloads: a missing required
field, a negative quantity, an unknown country code, a 10,000-character note for a varchar(500)
column, and a quantity sent as the string "3".

PASS if a reviewer applying the rule as written would require a handler to deal with each of the
five before using the field, whether the rule lists them or states one general requirement that covers them all
(for example, "every field is checked against every value the code can't take"). For the string
quantity, rejecting it or deliberately coercing it to a number both count. The rule must apply to
the webhook handlers in `src/webhooks/`.

FAIL if the rule, read as written, would let any of the five reach the code that uses it
unchecked, or if it covers something narrower than webhook payload fields.
