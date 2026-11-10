#!/usr/bin/env bash
set -euo pipefail
git init -q
git config user.email "eval@example.com"
git config user.name "eval"
git config commit.gpgsign false
cat > package.json <<'__WARDEN_EOF__'
{
  "name": "billing-api",
  "private": true,
  "type": "module",
  "scripts": { "test": "vitest run", "lint": "eslint ." },
  "dependencies": { "zod": "^3.23.8" },
  "devDependencies": { "eslint": "^9.12.0", "vitest": "^2.1.3", "typescript": "^5.6.3" }
}
__WARDEN_EOF__
mkdir -p src
cat > src/db.ts <<'__WARDEN_EOF__'
// Thin wrapper over the ORM client; models expose findMany / findUnique / create / deleteMany.
export { prisma as db } from './prisma'
__WARDEN_EOF__
mkdir -p .warden
cat > .warden/.ignore <<'__WARDEN_EOF__'
wards/*/examples/
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-001
cat > .warden/wards/WARD-001/ward.md <<'__WARDEN_EOF__'
---
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

**Human review:** Not required

**Source:** Agreed in the team's engineering review, 2026-10-01
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
paths:
  - 'src/handlers/**'
---

# WARD-002: Validate request input at the handler boundary

**Description:** Handlers that pass raw request input to services let malformed or hostile data deep into the system.

**Rationale:** Validation scattered across services gets missed; one unvalidated field becomes a 500 or an injection.

**Violations:**

```ts
export async function createInvoice(req: Request) {
  return invoices.create(req.body)
}
```

Raw `req.body` reaches the service.

**Compliant examples:**

```ts
export async function createInvoice(req: Request) {
  const input = CreateInvoice.parse(req.body)
  return invoices.create(input)
}
```

**Verification:**

1. For each handler the slice adds or changes, find where request input (body, query, params) is first used.
2. Check that a zod schema parses it (`.parse` or `.safeParse`) before any other use.

- PASS when every handler parses its input before using it.
- FAIL when any handler uses raw request input.

**Applicability:** HTTP handlers in `src/handlers/`. Exception: handlers that read no request input.

**Human review:** Not required

**Source:** Agreed in the team's engineering review, 2026-10-01
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-002/examples
cat > .warden/wards/WARD-002/examples/raw-refund-body.md <<'__WARDEN_EOF__'
# Refund created from the raw body

## Sample

```ts
// src/handlers/refunds.ts (excerpt)
export async function createRefund(req: { body: unknown }) {
  const { paymentId, amountCents } = req.body as { paymentId: string; amountCents: number }
  return refunds.create({ paymentId, amountCents })
}
```

## Expected fix shape

- A zod schema parses `req.body` before anything else uses it.
- The service receives the parsed values, never `req.body`.

```ts
export async function createRefund(req: { body: unknown }) {
  const { paymentId, amountCents } = req.body as { paymentId: string; amountCents: number }
  if (!paymentId || amountCents <= 0) throw new Error('invalid refund')
  return refunds.create({ paymentId, amountCents })
}
```
__WARDEN_EOF__
mkdir -p .warden
cat > .warden/wards.md <<'__WARDEN_EOF__'
# Wards

Engineering standards for this repository. Each ward is one enforceable standard with its own
folder in `wards/`, checked against every implementation slice by an independent reviewer.
Managed with the warden plugin: `/record-ward` adds a ward, `/audit-wards` consolidates them,
`/check-wards` verifies a slice.

<!-- One Summary row per folder in wards/, in ID order. IDs are permanent: never renumber or
     reuse one. Retired IDs stay listed under Retired. -->

## Summary

| ID | Name | Applies to | Human review |
|----|------|------------|--------------|
| [WARD-001](wards/WARD-001/ward.md) | Bound every query that can return many rows | `src/**` | No |
| [WARD-002](wards/WARD-002/ward.md) | Validate request input at the handler boundary | `src/handlers/**` | No |

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
__WARDEN_EOF__
mkdir -p src/handlers
cat > src/handlers/health.ts <<'__WARDEN_EOF__'
export async function health() {
  return { ok: true }
}
__WARDEN_EOF__
git add -A
git commit -q -m "base"
