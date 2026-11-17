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
  "scripts": { "test": "node --test" },
  "dependencies": { "zod": "^3.23.8" }
}
__WARDEN_EOF__
mkdir -p src
cat > src/db.ts <<'__WARDEN_EOF__'
// Thin wrapper over the ORM client; models expose findMany / findUnique / create / deleteMany.
export { prisma as db } from './prisma'
__WARDEN_EOF__
mkdir -p src/services
cat > src/services/orders.ts <<'__WARDEN_EOF__'
import { db } from '../db'

export async function ordersForAccount(accountId: string, limit: number, offset: number) {
  return db.order.findMany({ where: { accountId }, take: limit, skip: offset })
}
__WARDEN_EOF__
mkdir -p src/handlers
cat > src/handlers/orders.ts <<'__WARDEN_EOF__'
import { z } from 'zod'
import { ordersForAccount } from '../services/orders'

const ListOrders = z.object({
  accountId: z.string().uuid(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
})

export async function listOrders(req: { query: unknown }) {
  const { accountId, limit, offset } = ListOrders.parse(req.query)
  return { orders: await ordersForAccount(accountId, limit, offset) }
}
__WARDEN_EOF__
mkdir -p tests/arch
cat > tests/arch/handlers-use-services.test.mjs <<'__WARDEN_EOF__'
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readdirSync, readFileSync } from 'node:fs'
import { join } from 'node:path'

test('handlers reach the database only through services', () => {
  const dir = 'src/handlers'
  const offenders = []
  for (const file of readdirSync(dir)) {
    readFileSync(join(dir, file), 'utf8').split('\n').forEach((line, i) => {
      if (/from ['"]\.\.\/db['"]/.test(line)) offenders.push(`${dir}/${file}:${i + 1}`)
    })
  }
  assert.deepEqual(offenders, [], `handlers import the db module directly: ${offenders.join(', ')}`)
})
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
  - 'src/handlers/**'
enforced-by:
  - 'tests/arch/handlers-use-services.test.mjs'
---

# WARD-001: Reach the database from handlers only through services

**Description:** HTTP handlers that query the database directly mix transport concerns with data access and duplicate query logic.

**Rationale:** Queries written inside handlers can't be reused by jobs or other handlers, and each copy drifts: one gets pagination or tenancy scoping and the next doesn't.

**Violations:**

```ts
import { db } from '../db'

export async function listOrders(req: { query: { accountId: string } }) {
  return { orders: await db.order.findMany({ where: { accountId: req.query.accountId }, take: 50 }) }
}
```

The handler imports `db` and queries it itself.

**Compliant examples:**

```ts
import { ordersForAccount } from '../services/orders'

export async function listOrders(req: { query: { accountId: string } }) {
  return { orders: await ordersForAccount(req.query.accountId, 50, 0) }
}
```

**Verification:**

1. Run the `enforced-by` test.
2. For each handler the slice adds or changes, check that it imports no database module and calls a service function for data.

- PASS when the test passes and no handler imports the database module.
- FAIL when the test fails or any handler imports or queries the database directly.

**Applicability:** HTTP handlers in `src/handlers/`.
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-001/examples
cat > .warden/wards/WARD-001/examples/refund-handler-queries-db.md <<'__WARDEN_EOF__'
# Refund handler queries the database

## Sample

```ts
// src/handlers/refunds.ts (excerpt)
import { db } from '../db'

export async function listRefunds(req: { query: { paymentId: string } }) {
  const refunds = await db.refund.findMany({ where: { paymentId: req.query.paymentId }, take: 20 })
  return { refunds }
}
```

## Expected fix shape

- The handler imports a service function, not `db`.
- The query moves into `src/services/` unchanged.

```ts
import { refundsForPayment } from '../services/refunds'

export async function listRefunds(req: { query: { paymentId: string } }) {
  return { refunds: await refundsForPayment(req.query.paymentId) }
}
```
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-002
cat > .warden/wards/WARD-002/ward.md <<'__WARDEN_EOF__'
---
source: 'Team engineering review'
decided: 2026-10-01
paths:
  - 'src/handlers/**'
enforced-by:
  - 'tests/arch/handlers-validate-input.test.mjs'
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

1. Run the `enforced-by` test.
2. For each handler the slice adds or changes, find where request input (body, query, params) is first used, and check that a zod schema parses it (`.parse` or `.safeParse`) before any other use.

- PASS when the test passes and every handler parses its input before using it.
- FAIL when the test fails or any handler uses raw request input.

**Applicability:** HTTP handlers in `src/handlers/`. Exception: handlers that read no request input.
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
const CreateRefund = z.object({ paymentId: z.string().uuid(), amountCents: z.number().int().positive() })

export async function createRefund(req: { body: unknown }) {
  const input = CreateRefund.parse(req.body)
  return refunds.create(input)
}
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

| ID | Name | Applies to | Human review |
|----|------|------------|--------------|
| [WARD-001](wards/WARD-001/ward.md) | Reach the database from handlers only through services | `src/handlers/**` | No |
| [WARD-002](wards/WARD-002/ward.md) | Validate request input at the handler boundary | `src/handlers/**` | No |

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
__WARDEN_EOF__
git add -A
git commit -q -m "base"
# the slice under review: left uncommitted
cat > src/handlers/invoices.ts <<'__WARDEN_EOF__'
import { z } from 'zod'
import { db } from '../db'

const ListInvoices = z.object({ accountId: z.string().uuid() })

export async function listInvoices(req: { query: unknown }) {
  const { accountId } = ListInvoices.parse(req.query)
  const invoices = await db.invoice.findMany({ where: { accountId }, take: 50 })
  return { invoices }
}
__WARDEN_EOF__
