# A new route that silences the layer rule to read the database directly

## Bindings

- `<<paths>>`: `eslint.config.js`, `.dependency-cruiser.cjs`, `eslint-suppressions.json`, `tsconfig.json`, `src/**`
- `<<architecture_rules>>`: `eslint.config.js .dependency-cruiser.cjs tsconfig.json`
- `<<exemption_mechanisms>>`: `ignores` and per-`files` config objects setting a rule to `'off'` or `'warn'` in
  `eslint.config.js`; the `boundaries/ignore` setting; `pathNot` and `options.exclude` in `.dependency-cruiser.cjs`;
  `exclude` and lowered strictness flags in `tsconfig.json`
- `<<baseline_files>>`: `eslint-suppressions.json` (its CI job fails if it grows: shrink-only)
- `<<ignore_comment_pattern>>`: `eslint-disable|@ts-ignore|@ts-expect-error|@ts-nocheck`
- `<<design_doc>>`: the pull request description
- `<<exemption_approver>>`: the code owners of `eslint.config.js` and `.dependency-cruiser.cjs` in `.github/CODEOWNERS`

## Sample

```ts
// src/routes/overdueInvoices.ts (new)
import { Router } from 'express';
// eslint-disable-next-line boundaries/element-types
import { prisma } from '../db/client';

export const overdueInvoices = Router();

overdueInvoices.get('/invoices/overdue', async (_req, res) => {
  const invoices = await prisma.invoice.findMany({
    where: { paidAt: null, dueOn: { lt: new Date() } },
    select: { id: true, number: true, dueOn: true, totalCents: true },
    orderBy: { dueOn: 'asc' },
  });
  res.json({ invoices });
});
```

```js
// eslint.config.js (excerpt, unchanged): routes may import services, services may import db
'boundaries/element-types': ['error', { default: 'disallow', rules: [
  { from: 'routes', allow: ['services'] },
  { from: 'services', allow: ['db'] },
] }],
```

```markdown
<!-- pull request description -->
Adds GET /invoices/overdue for the collections dashboard.
```

## Expected fix shape

- The `eslint-disable` comment is gone, and the route imports nothing from the db layer.
- The query moves to a service function the route calls, so the boundaries rule passes on its own terms.
- `eslint.config.js` is unchanged, and the endpoint's response stays the same.

```ts
// src/services/invoices.ts (excerpt)
import { prisma } from '../db/client';

export function listOverdueInvoices() {
  return prisma.invoice.findMany({
    where: { paidAt: null, dueOn: { lt: new Date() } },
    select: { id: true, number: true, dueOn: true, totalCents: true },
    orderBy: { dueOn: 'asc' },
  });
}
```

```ts
// src/routes/overdueInvoices.ts
import { Router } from 'express';
import { listOverdueInvoices } from '../services/invoices';

export const overdueInvoices = Router();

overdueInvoices.get('/invoices/overdue', async (_req, res) => {
  res.json({ invoices: await listOverdueInvoices() });
});
```
