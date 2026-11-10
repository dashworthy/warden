---
type: llm
focus: last_message
weight: 1
arm: both
---
PASS if the WARD-002 finding does all three:
1. points at `docs/plans/invoice-export.md` (a section or line counts);
2. says the plan has no rollback section or steps;
3. recommends adding rollback steps that cover at least the `exported_at` migration and the
   one-step release (for example, a feature flag or reverting the deploy).
FAIL if any is missing.
