#!/usr/bin/env bash
set -euo pipefail
git init -q
git config user.email "eval@example.com"
git config user.name "eval"
git config commit.gpgsign false
cat > package.json <<'__WARDEN_EOF__'
{
  "name": "orders-service",
  "private": true,
  "type": "module",
  "scripts": { "test": "vitest run" },
  "dependencies": { "zod": "^3.23.8" },
  "devDependencies": { "vitest": "^2.1.3", "typescript": "^5.6.3" }
}
__WARDEN_EOF__
mkdir -p src/webhooks src/db
cat > src/db/schema.sql <<'__WARDEN_EOF__'
CREATE TABLE audit_log (
  id         uuid PRIMARY KEY,
  event_type varchar(64)  NOT NULL,
  note       varchar(500) NOT NULL
);
__WARDEN_EOF__
cat > src/webhooks/payments.ts <<'__WARDEN_EOF__'
import { db } from '../db'

export async function handlePayment(body: any) {
  const total = body.amount.value * body.quantity
  await db.payment.create({ data: { orderId: body.orderId, total } })
  await db.auditLog.create({ data: { eventType: 'payment', note: body.note } })
}
__WARDEN_EOF__
cat > src/webhooks/shipping.ts <<'__WARDEN_EOF__'
import { taxFor } from '../tax'

export async function handleShipment(body: any) {
  const rate = taxFor(body.country)
  return { orderId: body.orderId, tax: rate * body.subtotal }
}
__WARDEN_EOF__
cat > src/db/index.ts <<'__WARDEN_EOF__'
export { prisma as db } from './prisma'
__WARDEN_EOF__
cat > src/tax.ts <<'__WARDEN_EOF__'
const RATES: Record<string, number> = { US: 0.07, CA: 0.13, GB: 0.2 }
export function taxFor(country: string): number {
  const rate = RATES[country]
  if (rate === undefined) throw new Error(`no tax rate for ${country}`)
  return rate
}
__WARDEN_EOF__
git add -A
git commit -q -m "base"
