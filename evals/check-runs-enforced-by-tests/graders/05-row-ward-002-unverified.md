---
type: regex
pattern: '\|\s*WARD-002\s*\|[^|\n]*\|\s*UNVERIFIED\s*\|'
match: "count:1"
arm: both
---
The summary table has exactly one row for WARD-002, with the result UNVERIFIED: its enforced-by
test file is missing.
