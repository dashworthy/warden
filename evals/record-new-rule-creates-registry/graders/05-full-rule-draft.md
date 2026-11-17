---
type: regex
pattern: '^(?=[\s\S]*#\s*RULE-001)(?=[\s\S]*\*\*Description:\*\*)(?=[\s\S]*\*\*Rationale:\*\*)(?=[\s\S]*\*\*Violations:\*\*)(?=[\s\S]*\*\*Compliant examples:\*\*)(?=[\s\S]*\*\*Verification:\*\*)(?=[\s\S]*PASS when)(?=[\s\S]*FAIL when)(?=[\s\S]*\*\*Applicability:\*\*)(?=[\s\S]*\n[ \t]*source:)(?=[\s\S]*\n[ \t]*decided:)(?=[\s\S]*```)'
arm: both
---

The proposal shows the complete draft rule.md: the `source` and `decided` frontmatter keys, the
RULE-001 heading, every field label (Description, Rationale, Violations, Compliant examples,
Verification, Applicability), explicit PASS when and FAIL when conditions, and code.
