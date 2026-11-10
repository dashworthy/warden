---
type: llm
focus: last_message
weight: 1
arm: both
---
Judge only the ward-check report in the message. Paths may be relative or absolute (for example
`/private/tmp/.../src/handlers/invoices.ts`); treat them as the same file.

PASS if both hold:
1. The WARD-001 finding reports that the test `handlers-use-services.test.mjs` failed (a failing
   exit status or its failure output counts) and points at the `db` import in
   `src/handlers/invoices.ts`.
2. The WARD-002 result is UNVERIFIED, and the report gives as the reason that its test file
   `handlers-validate-input.test.mjs` is missing or couldn't be run.

FAIL if either is missing, or if WARD-002 is reported as PASS.
