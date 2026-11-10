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
source: 'Incident review after the October export outage'
decided: 2026-10-20
phases:
  - 'design'
---

# WARD-002: State how every plan's change is rolled back

**Description:** Plans that don't say how to undo their schema, data and deploy changes leave the on-call engineer to invent a rollback during an incident.

**Rationale:** A migration or backfill with no rollback path turns a bad deploy into hours of manual repair; deciding the path while planning costs minutes.

**Violations:**

```markdown
## Changes
- Add a `status` column to `payments` and backfill it from `paid_at`.
- Deploy behind no flag.
```

The plan changes the schema and data and says nothing about undoing either.

**Compliant examples:**

```markdown
## Rollback
- Turn off the `payment_status` flag; the old code path ignores the column.
- Revert the deploy; the column stays and is unused.
- If needed, drop the column with the migration's `down`; the backfill is derived data and needs no restore.
```

**Verification:**

1. List every schema, data, configuration and deploy change the plan proposes.
2. Find the plan's Rollback section and check that it gives the steps that undo each change, or says why a change needs none.

- PASS when the plan has a Rollback section covering every change it proposes.
- FAIL when it has none, or a change has no rollback step and no reason.

**Applicability:** Plans and design documents that propose changes to code, schema, data, configuration or deploys.
__WARDEN_EOF__
mkdir -p .warden/wards/WARD-002/examples
cat > .warden/wards/WARD-002/examples/queue-migration-plan.md <<'__WARDEN_EOF__'
# Queue migration plan without a rollback

## Sample

```markdown
docs/plans/move-webhooks-to-sqs.md (excerpt)
## Changes
- Publish webhook jobs to SQS instead of Redis.
- Delete the Redis queue workers after one week.
## Testing
- Load-test 10k jobs on staging.
```

## Expected fix shape

- A Rollback section gives the undo step for each change: publishing and the worker removal.
- The Changes and Testing sections stay the same.

```markdown
## Rollback
- Switch `WEBHOOK_QUEUE` back to `redis`; the Redis workers keep running for the first week.
- After the workers are deleted, redeploy them from the tagged release before switching back.
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
| [WARD-002](wards/WARD-002/ward.md) | State how every plan's change is rolled back | design | All | No |

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
__WARDEN_EOF__
mkdir -p docs/plans
cat > docs/plans/invoice-export.md <<'__WARDEN_EOF__'
# Plan: invoice CSV export

## Goal

Let customers download their invoices as CSV from the billing page.

## Changes

1. Add a migration that adds an `exported_at` timestamp column to `invoices`.
2. Add `GET /invoices/export`, which streams the account's invoices as CSV in pages of 500 and sets
   `exported_at` on each exported invoice.
3. Add an "Export CSV" button to the billing page.
4. Release to all accounts in one deploy.

## Testing

- Unit tests for the CSV formatting.
- An integration test that exports 1,200 invoices across three pages.
__WARDEN_EOF__
git add -A
git commit -q -m "chore: initial billing api and export plan"
