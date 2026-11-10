#!/usr/bin/env bash
set -euo pipefail
git init -q -b main
git config user.email "eval@example.com"
git config user.name "eval"
git config commit.gpgsign false
cat > package.json <<'__WARDEN_EOF__'
{
  "name": "billing-api",
  "private": true,
  "type": "module",
  "dependencies": { "zod": "^3.23.8" }
}
__WARDEN_EOF__
mkdir -p src
cat > src/db.ts <<'__WARDEN_EOF__'
// Thin wrapper over the ORM client; models expose findMany / findUnique / create / deleteMany.
export { prisma as db } from './prisma'
__WARDEN_EOF__
mkdir -p src/handlers
cat > src/handlers/health.ts <<'__WARDEN_EOF__'
export async function health() {
  return { ok: true }
}
__WARDEN_EOF__
mkdir -p .warden
cat > .warden/.ignore <<'__WARDEN_EOF__'
wards/*/examples/
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-001
cat > .warden/wards/WARD-001/ward.md <<'__WARDEN_EOF__'
---
source: 'Team engineering review'
decided: 2026-10-01
paths:
  - 'src/**'
---

# WARD-001: Bound every query that can return many rows

**Description:** List and export queries that load every matching row exhaust memory and time out as data grows.

**Rationale:** One large customer turns an unbounded query into a multi-second response or an out-of-memory crash, usually in production first.

**Violations:**

```ts
const orders = await db.order.findMany({ where: { accountId } })
```

Loads every order the account has ever placed.

**Compliant examples:**

```ts
const orders = await db.order.findMany({ where: { accountId }, take: limit, skip: offset })
```

**Verification:**

1. Find every collection query (`findMany`, `findAll`, raw `SELECT`) the slice adds or changes.
2. Check that each is bounded by `take`/`limit`, cursor pagination, or streaming in batches.

- PASS when every such query is bounded.
- FAIL when any can return an unbounded number of rows.

**Applicability:** Code that queries collections of records. Exception: tables with a hard, documented size cap, such as enums.
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-001/examples
cat > .warden/wards/WARD-001/examples/overdue-payments-report.md <<'__WARDEN_EOF__'
# Overdue payments report

## Sample

```ts
// src/reports/overdue.ts (excerpt)
export async function overduePayments(now: Date) {
  const payments = await db.payment.findMany({ where: { dueAt: { lt: now }, paidAt: null } })
  return payments.map(toReportRow)
}
```

## Expected fix shape

- The query is bounded: `take`/`skip`, a cursor, or processing in fixed-size batches.
- The filter and the report rows stay the same.

```ts
export async function* overduePayments(now: Date) {
  let cursor: string | undefined
  do {
    const batch = await db.payment.findMany({
      where: { dueAt: { lt: now }, paidAt: null },
      take: 500,
      ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
      orderBy: { id: 'asc' },
    })
    yield batch.map(toReportRow)
    cursor = batch.length === 500 ? batch[batch.length - 1].id : undefined
  } while (cursor)
}
```
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-002
cat > .warden/wards/WARD-002/ward.md <<'__WARDEN_EOF__'
---
source: 'Team engineering review'
decided: 2026-10-01
phases:
  - 'pr'
---

# WARD-002: Write commit subjects in Conventional Commits form

**Description:** Commit subjects like "wip" or "stuff" make history unsearchable and break the changelog generated from commit types.

**Rationale:** The release notes are built from commit types; a commit without one disappears from them, and reviewers can't tell from the log what a commit changed.

**Violations:**

```text
a1b2c3d misc fixes
```

No type, no scope, nothing about what changed.

**Compliant examples:**

```text
a1b2c3d fix(invoices): bound the invoice list query
```

**Verification:**

1. List every commit on the branch: `git log --format='%h %s' <base>..HEAD`.
2. Check that each subject has the form `<type>(<optional scope>): <summary>`, with type one of `feat`, `fix`, `docs`, `refactor`, `test` or `chore`, and a summary that says what changed.

- PASS when every commit subject has that form.
- FAIL when any commit subject doesn't.

**Applicability:** Every commit on the pull request's branch. Exception: merge commits that git generates.
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-002/examples
cat > .warden/wards/WARD-002/examples/review-fixups.md <<'__WARDEN_EOF__'
# Review fix-up commits

## Sample

```text
Commits on the branch
9f8e7d6 feat(refunds): add partial refunds
5c4b3a2 address review comments
1a2b3c4 oops
```

## Expected fix shape

- Every subject has a type, an optional scope and a summary of what changed.
- The commits' content stays the same.

```text
9f8e7d6 feat(refunds): add partial refunds
5c4b3a2 refactor(refunds): rename amount fields after review
1a2b3c4 fix(refunds): reject refunds above the captured amount
```
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-003
cat > .warden/wards/WARD-003/ward.md <<'__WARDEN_EOF__'
---
source: 'Team engineering review'
decided: 2026-10-01
phases:
  - 'pr'
---

# WARD-003: Link the issue in every pull request description

**Description:** A PR description that doesn't link its issue leaves reviewers without the requirement the change is meant to meet.

**Rationale:** Reviewers can't check a change against requirements they can't find, and the issue isn't closed when the PR merges.

**Violations:**

```markdown
Adds CSV export for invoices.
```

No issue reference.

**Compliant examples:**

```markdown
Adds CSV export for invoices. Closes #88.
```

**Verification:**

1. Read the PR body (or the draft body, when there's no PR yet).
2. Look for a reference to an issue: `#<number>`, `Closes #<number>`, `Fixes #<number>` or an issue URL.

- PASS when the body references at least one issue.
- FAIL when it references none.

**Applicability:** Every pull request. Exception: release PRs opened by automation.
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-003/examples
cat > .warden/wards/WARD-003/examples/body-without-issue.md <<'__WARDEN_EOF__'
# PR body without an issue

## Sample

```markdown
PR body
## Summary
Retries failed webhook deliveries with exponential backoff.
## Testing
Unit tests for the backoff schedule.
```

## Expected fix shape

- The body references the issue the change resolves.
- The summary and testing notes stay.

```markdown
## Summary
Retries failed webhook deliveries with exponential backoff. Closes #131.
## Testing
Unit tests for the backoff schedule.
```
__WARDEN_EOF__
cat > .warden/wards.md <<'__WARDEN_EOF__'
# Wards

Engineering standards for this repository. Each ward is one enforceable standard with its own
folder in `wards/`, checked against every implementation slice by an independent reviewer.
Managed with the warden plugin: `/record-ward` adds a ward, `/audit-wards` consolidates them,
`/check-wards` verifies a slice.

<!-- One Summary row per folder in wards/, in ID order. IDs are permanent: never renumber or
     reuse one. Retired IDs stay listed under Retired. -->

## Summary

| ID | Name | Phases | Applies to | Human review |
|----|------|--------|------------|--------------|
| [WARD-001](wards/WARD-001/ward.md) | Bound every query that can return many rows | code | `src/**` | No |
| [WARD-002](wards/WARD-002/ward.md) | Write commit subjects in Conventional Commits form | pr | All | No |
| [WARD-003](wards/WARD-003/ward.md) | Link the issue in every pull request description | pr | All | No |

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
__WARDEN_EOF__
git add -A
git commit -q -m "chore: initial billing api"
# the branch under review: two commits, one with a bad subject and a code-ward violation
git checkout -q -b feat/invoice-export
cat > src/handlers/invoice-export.ts <<'__WARDEN_EOF__'
import { db } from '../db'

export async function exportInvoices(req: { query: { accountId: string } }) {
  const invoices = await db.invoice.findMany({ where: { accountId: req.query.accountId } })
  return invoices.map((i) => [i.number, i.totalCents, i.issuedAt].join(',')).join('\n')
}
__WARDEN_EOF__
git add -A
git commit -q -m "feat(invoices): add CSV export endpoint"
cat > src/routes.ts <<'__WARDEN_EOF__'
import { exportInvoices } from './handlers/invoice-export'

export const routes = {
  'GET /invoices/export': exportInvoices,
}
__WARDEN_EOF__
git add -A
git commit -q -m "stuff"
