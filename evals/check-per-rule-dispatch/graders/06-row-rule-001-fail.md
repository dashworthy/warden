---
type: regex
pattern: '\|\s*RULE-001\s*\|[^|\n]*\|\s*FAIL\s*\|'
match: "count:1"
arm: both
---
The summary table has exactly one row for RULE-001, with the result FAIL.
