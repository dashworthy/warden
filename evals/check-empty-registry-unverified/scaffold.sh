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
mkdir -p src/handlers
cat > src/handlers/orders.ts <<'__WARDEN_EOF__'
import { z } from 'zod'
import { db } from '../db'

const ListOrders = z.object({
  accountId: z.string().uuid(),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  offset: z.coerce.number().int().min(0).default(0),
})

export async function listOrders(req: { query: unknown }) {
  const { accountId, limit, offset } = ListOrders.parse(req.query)
  const orders = await db.order.findMany({ where: { accountId }, take: limit, skip: offset })
  return { orders }
}
__WARDEN_EOF__
mkdir -p src
cat > src/routes.ts <<'__WARDEN_EOF__'
import { listOrders } from './handlers/orders'

export const routes = {
  'GET /orders': listOrders,
}
__WARDEN_EOF__
mkdir -p .warden
cat > .warden/.ignore <<'__WARDEN_EOF__'
wards/*/examples/
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

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
__WARDEN_EOF__
git add -A
git commit -q -m "base"
# the slice under review: left uncommitted
mkdir -p src
cat > src/routes.ts <<'__WARDEN_EOF__'
import { listOrders } from './handlers/orders'
import { listInvoices } from './handlers/invoices'

export const routes = {
  'GET /orders': listOrders,
  'GET /invoices': listInvoices,
}
__WARDEN_EOF__
mkdir -p src/handlers
cat > src/handlers/invoices.ts <<'__WARDEN_EOF__'
import { z } from 'zod'
import { db } from '../db'

const ListInvoices = z.object({ accountId: z.string().uuid() })

export async function listInvoices(req: { query: unknown }) {
  const { accountId } = ListInvoices.parse(req.query)
  const invoices = await db.invoice.findMany({
    where: { accountId },
    orderBy: { issuedAt: 'desc' },
  })
  return { invoices }
}
__WARDEN_EOF__
