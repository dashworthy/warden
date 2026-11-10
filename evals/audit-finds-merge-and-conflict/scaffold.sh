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

# WARD-002: Paginate every list endpoint

**Description:** List endpoints must return pages (a limit and a cursor) instead of every record.

**Rationale:** Unpaginated endpoints get slower with every record added and eventually time out.

**Violations:**

```ts
export async function listOrders(req: Request) {
  return { orders: await db.order.findMany({ where: { accountId: req.query.accountId } }) }
}
```

**Compliant examples:**

```ts
export async function listOrders(req: Request) {
  const { accountId, cursor, limit } = ListOrders.parse(req.query)
  return paginate(db.order, { where: { accountId }, cursor, limit })
}
```

**Verification:**

1. Find the handlers the slice adds or changes that return a collection.
2. Check that each accepts `limit` and `cursor` and passes them to its query.

- PASS when every list handler is paginated.
- FAIL when any returns an unpaginated collection.

**Applicability:** HTTP handlers that return collections.

**Human review:** Not required

**Source:** Agreed in the team's engineering review, 2026-10-01
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-002/examples
cat > .warden/wards/WARD-002/examples/unpaginated-search.md <<'__WARDEN_EOF__'
# Customer search returns everything

## Sample

```ts
// src/handlers/customers.ts (excerpt)
export async function searchCustomers(req: { query: unknown }) {
  const { q } = SearchCustomers.parse(req.query)
  return { customers: await db.customer.findMany({ where: { name: { contains: q } } }) }
}
```

## Expected fix shape

- The handler accepts `limit` and `cursor` and passes both to the query.
- The response includes the cursor for the next page.

```ts
const SearchCustomers = z.object({
  q: z.string(),
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(100).default(25),
})

export async function searchCustomers(req: { query: unknown }) {
  const { q, cursor, limit } = SearchCustomers.parse(req.query)
  return paginate(db.customer, { where: { name: { contains: q } }, cursor, limit })
}
```
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-003
cat > .warden/wards/WARD-003/ward.md <<'__WARDEN_EOF__'
# WARD-003: Retry every external API call

**Description:** Calls to external HTTP APIs fail transiently and must be retried.

**Rationale:** A single dropped connection to a payment or shipping provider shouldn't fail a customer's request.

**Violations:**

```ts
const res = await fetch(`${PAYMENTS_URL}/charges`, { method: 'POST', body })
```

**Compliant examples:**

```ts
const res = await retryWithBackoff(() => fetch(`${PAYMENTS_URL}/charges`, { method: 'POST', body }))
```

**Verification:**

1. Find every `fetch` or HTTP client call to an external host the slice adds.
2. Check that each is wrapped in `retryWithBackoff`.

- PASS when every external call is wrapped.
- FAIL when any external call isn't.

**Applicability:** Every call to an external HTTP API.

**Human review:** Not required

**Source:** Agreed in the team's engineering review, 2026-10-01
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-003/examples
cat > .warden/wards/WARD-003/examples/bare-shipping-call.md <<'__WARDEN_EOF__'
# Shipping rates call without retry

## Sample

```ts
// src/shipping/rates.ts
export async function fetchRates(parcel: Parcel) {
  const res = await fetch(`${SHIPPING_URL}/rates`, { method: 'POST', body: JSON.stringify(parcel) })
  return res.json()
}
```

## Expected fix shape

- The external call is wrapped in `retryWithBackoff`.

```ts
export async function fetchRates(parcel: Parcel) {
  const res = await retryWithBackoff(() =>
    fetch(`${SHIPPING_URL}/rates`, { method: 'POST', body: JSON.stringify(parcel) }),
  )
  return res.json()
}
```
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-004
cat > .warden/wards/WARD-004/ward.md <<'__WARDEN_EOF__'
# WARD-004: Never retry non-idempotent requests

**Description:** Requests that create or change state must not be retried automatically unless they carry an idempotency key.

**Rationale:** Retrying a POST that already succeeded charges a customer twice or creates duplicate records.

**Violations:**

```ts
await retryWithBackoff(() => fetch(`${PAYMENTS_URL}/charges`, { method: 'POST', body }))
```

**Compliant examples:**

```ts
await retryWithBackoff(() =>
  fetch(`${PAYMENTS_URL}/charges`, { method: 'POST', body, headers: { 'Idempotency-Key': key } }),
)
```

**Verification:**

1. Find every retried POST or PATCH request in the slice.
2. Check that each sends an `Idempotency-Key` header.

- PASS when every retried POST or PATCH sends an idempotency key.
- FAIL when any is retried without one.

**Applicability:** Code that retries HTTP requests.

**Human review:** Not required

**Source:** Agreed in the team's engineering review, 2026-10-01
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-004/examples
cat > .warden/wards/WARD-004/examples/retried-capture.md <<'__WARDEN_EOF__'
# Payment capture retried without a key

## Sample

```ts
// src/payments/capture.ts
export async function capture(chargeId: string) {
  return retryWithBackoff(() => fetch(`${PAYMENTS_URL}/charges/${chargeId}/capture`, { method: 'POST' }))
}
```

## Expected fix shape

- The retried POST sends an `Idempotency-Key` header.
- The key is created once, outside the retry, so every attempt reuses it.

```ts
export async function capture(chargeId: string) {
  const key = `capture-${chargeId}`
  return retryWithBackoff(() =>
    fetch(`${PAYMENTS_URL}/charges/${chargeId}/capture`, { method: 'POST', headers: { 'Idempotency-Key': key } }),
  )
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
| [WARD-002](wards/WARD-002/ward.md) | Paginate every list endpoint | `src/handlers/**` | No |
| [WARD-003](wards/WARD-003/ward.md) | Retry every external API call | All | No |
| [WARD-004](wards/WARD-004/ward.md) | Never retry non-idempotent requests | All | No |

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
| WARD-005 | Use snake_case table names | Removed: enforced by the migration linter |
__WARDEN_EOF__
mkdir -p src/handlers
cat > src/handlers/health.ts <<'__WARDEN_EOF__'
export async function health() {
  return { ok: true }
}
__WARDEN_EOF__
git add -A
git commit -q -m "base"
