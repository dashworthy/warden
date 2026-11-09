---
type: regex
pattern: 'Overall:?\W*PASS'
match: "not_contains"
arm: both
---
The result is never reported as an overall PASS.
