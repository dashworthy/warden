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
# WARD-002: Make every migration reversible

**Description:** Migrations without a working `down` step can't be rolled back during an incident.

**Rationale:** A bad deploy with an irreversible migration turns a rollback into manual data repair.

**Violations:**

```ts
export async function down() {
  throw new Error('irreversible')
}
```

**Compliant examples:**

```ts
export async function down(db: Db) {
  await db.schema.dropTable('invoices')
}
```

**Verification:**

1. List the migrations the slice adds under `migrations/`.
2. Check that each has a `down` that undoes its `up`.

- PASS when every new migration's `down` reverses its `up`.
- FAIL when any new migration has no `down` or one that doesn't reverse `up`.

**Applicability:** Files under `migrations/`. N/A when the slice adds no migration.

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
| [WARD-002](wards/WARD-002.md) | Make every migration reversible | No |

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
__WARDEN_EOF__
git add -A
git commit -q -m "base"
