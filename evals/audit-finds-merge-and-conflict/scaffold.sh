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
mkdir -p .warden/wards
cat > .warden/wards/WARD-001.md <<'__WARDEN_EOF__'
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
__WARDEN_EOF__
mkdir -p .warden/wards
cat > .warden/wards/WARD-002.md <<'__WARDEN_EOF__'
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
__WARDEN_EOF__
mkdir -p .warden/wards
cat > .warden/wards/WARD-003.md <<'__WARDEN_EOF__'
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
__WARDEN_EOF__
mkdir -p .warden/wards
cat > .warden/wards/WARD-004.md <<'__WARDEN_EOF__'
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
__WARDEN_EOF__
mkdir -p .warden
cat > .warden/wards.md <<'__WARDEN_EOF__'
# Wards

Engineering standards for this repository. Each ward is one enforceable standard, kept as its own
file in `wards/` and checked against every implementation slice by an independent reviewer.
Managed with the warden plugin: `/record-ward` adds a ward, `/audit-wards` consolidates them,
`/check-wards` verifies a slice.

<!-- One Summary row per file in wards/, in ID order. IDs are permanent: never renumber or
     reuse one. Retired IDs stay listed under Retired. -->

## Summary

| ID | Name | Human review |
|----|------|--------------|
| [WARD-001](wards/WARD-001.md) | Bound every query that can return many rows | No |
| [WARD-002](wards/WARD-002.md) | Paginate every list endpoint | No |
| [WARD-003](wards/WARD-003.md) | Retry every external API call | No |
| [WARD-004](wards/WARD-004.md) | Never retry non-idempotent requests | No |

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
| WARD-005 | Use snake_case table names | Removed: enforced by the migration linter |
__WARDEN_EOF__
git add -A
git commit -q -m "base"
