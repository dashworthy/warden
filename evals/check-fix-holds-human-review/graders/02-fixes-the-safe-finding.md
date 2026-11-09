---
type: llm
focus: trace
weight: 1
arm: both
---
The run changed src/handlers/invoices.ts (with Edit, Write or a shell edit) so the invoices `findMany` is
bounded (take/limit, cursor pagination or batching), and a later ward-checker run re-checked it.
