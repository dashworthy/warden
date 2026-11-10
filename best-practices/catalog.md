# Best practices

Generic wards any repository can adopt with `/record-ward BP-NNN`, which fills each one's bindings
from the repository and writes it to the registry once a person approves. The format is in
`../shared/best-practices-format.md`.

| ID | Name | Phases | Bindings | Stacks |
|----|------|--------|----------|--------|
| [BP-001](BP-001/ward.md) | Keep business logic out of controllers | code | 9 | Laravel, Node |
| [BP-002](BP-002/ward.md) | Translate user-facing text | code | 9 | Laravel, Node |
| [BP-003](BP-003/ward.md) | Change only what the request needs | code | 7 | Laravel, Node |
| [BP-004](BP-004/ward.md) | Prove API changes keep every consumer's requests working | design, code | 9 | Laravel, Node |
| [BP-005](BP-005/ward.md) | Reuse or generalize before adding a single-use component | design, code | 9 | Laravel, Node |
| [BP-006](BP-006/ward.md) | Make migrations safe for every state existing data can be in | code | 6 | Laravel, Node |
| [BP-007](BP-007/ward.md) | Validate ids against live rows, or against their enum | code | 7 | Laravel, Node |
| [BP-008](BP-008/ward.md) | Give each endpoint one contract, shaped like the domain | design, code | 8 | Laravel, Node |
| [BP-009](BP-009/ward.md) | Do per-set work once, not once per item | code | 7 | Laravel, Node |
| [BP-010](BP-010/ward.md) | Fit new code to the architecture tests instead of exempting it | code | 7 | Laravel, Node |
| [BP-011](BP-011/ward.md) | Name new concepts with the domain's existing terms | design, code | 7 | Laravel, Node |
| [BP-012](BP-012/ward.md) | Keep secrets in a secret store or encrypted columns, never in plain text | code | 14 | Laravel, Node |
| [BP-013](BP-013/ward.md) | Write the failing test before the code it proves | code | 12 | Laravel, Node |
| [BP-014](BP-014/ward.md) | Account for every state and path a transition can start from | design, code | 8 | Laravel, Node |
