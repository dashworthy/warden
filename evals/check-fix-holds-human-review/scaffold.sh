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
# WARD-002: Confirm destructive bulk actions in plain language

**Description:** Bulk deletes and other irreversible bulk changes must go through a confirmation that states the consequence.

**Rationale:** One misclick deletes a customer's data, and support can't undo it.

**Violations:**

```tsx
<Button onClick={() => deleteSelected(ids)}>Delete</Button>
```

**Compliant examples:**

```tsx
<ConfirmDialog
  title={`Delete ${ids.length} invoices?`}
  body="This permanently deletes them. It can't be undone."
  onConfirm={() => deleteSelected(ids)}
/>
```

**Verification:**

1. Find UI actions the slice adds that delete or irreversibly change several records.
2. Check that each runs only after a confirmation dialog that names how many records are affected and says the action can't be undone.

- PASS when every such action is confirmed that way.
- FAIL when any runs without such a confirmation.

**Applicability:** UI code under `src/ui/` that triggers bulk destructive actions.

**Human review:** Required: is the confirmation wording clear to a non-technical customer about exactly what will be lost?
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
| [WARD-002](wards/WARD-002.md) | Confirm destructive bulk actions in plain language | Yes |

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
mkdir -p src/ui
cat > src/ui/BulkDeleteInvoices.tsx <<'__WARDEN_EOF__'
import { useState } from 'react'
import { Button, ConfirmDialog } from './kit'
import { deleteInvoices } from '../api'

export function BulkDeleteInvoices({ ids }: { ids: string[] }) {
  const [open, setOpen] = useState(false)
  return (
    <>
      <Button variant="danger" onClick={() => setOpen(true)}>Delete selected</Button>
      <ConfirmDialog
        open={open}
        title="Delete invoices?"
        body="Are you sure?"
        onCancel={() => setOpen(false)}
        onConfirm={() => deleteInvoices(ids)}
      />
    </>
  )
}
__WARDEN_EOF__
