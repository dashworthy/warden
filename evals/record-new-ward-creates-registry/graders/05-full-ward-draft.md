---
type: regex
pattern: '^(?=[\s\S]*#\s*WARD-001)(?=[\s\S]*\*\*Description:\*\*)(?=[\s\S]*\*\*Rationale:\*\*)(?=[\s\S]*\*\*Violations:\*\*)(?=[\s\S]*\*\*Compliant examples:\*\*)(?=[\s\S]*\*\*Verification:\*\*)(?=[\s\S]*PASS when)(?=[\s\S]*FAIL when)(?=[\s\S]*\*\*Applicability:\*\*)(?=[\s\S]*\*\*Human review:\*\*)(?=[\s\S]*```)'
arm: both
---

The proposal shows the complete draft ward.md: the WARD-001 heading, every field label
(Description, Rationale, Violations, Compliant examples, Verification, Applicability, Human review),
explicit PASS when and FAIL when conditions, and code.
