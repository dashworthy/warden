---
type: llm
focus: last_message
weight: 1
arm: both
---
Judge only the proposed ward.md text (its frontmatter, heading and six fields), not the examples,
the self-test or the rest of the proposal. If no ward.md text is shown, FAIL.

PASS if all of these hold:
1. **Description**, **Rationale** and **Applicability** are each one sentence of at most about 30
   words.
2. None of those three retells the incidents one by one. Naming the kinds of check the request
   itself asked for (presence, type, range, length, allowed values) is fine.
3. **Verification** has at most two numbered steps, each one sentence of at most about 50 words,
   followed by one PASS line and one FAIL line.
4. Each code block under **Violations** and **Compliant examples** is at most 10 lines.

FAIL if any of these is exceeded. A semicolon or colon inside a sentence doesn't start a new one,
but it doesn't make a long sentence short either.
