---
type: llm
focus: last_message
weight: 1
arm: both
---
PASS if the report does both:
1. says WARD-001's path `app/Http/Controllers/**` matches no file in the repository (dead, stale or
   wrong for this codebase), so the ward would never apply;
2. recommends replacing it with paths that cover the code the ward governs, such as `src/**` or
   `src/handlers/**`.
FAIL if it misses the dead path, recommends removing or merging WARD-001, or raises a path problem
for WARD-002 (`migrations/**`, which matches a migration file).
