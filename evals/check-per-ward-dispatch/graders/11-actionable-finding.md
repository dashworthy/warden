---
type: llm
focus: last_message
weight: 1
arm: both
---
PASS if the report's WARD-001 finding does all three:
1. gives a location in src/handlers/invoices.ts with a line number or a line range (for example `:8` or `:8-11`);
2. shows or describes the unbounded `findMany` call;
3. recommends a concrete correction, such as take/limit, cursor pagination or batching.
Extra detail elsewhere in the report doesn't affect the verdict. FAIL only if one of the three is missing.
