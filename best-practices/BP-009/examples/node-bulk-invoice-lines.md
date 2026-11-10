# Adding many invoice lines, with the invoice's totals recalculated after each one

## Bindings

- `<<paths>>`: `src/**`, `scripts/**`
- `<<loop_pattern>>`: `for *\(|while *\(|\.(map|forEach|filter|reduce|flatMap)\(`
- `<<query_calls>>`: Prisma reads (`findUnique`, `findUniqueOrThrow`, `findFirst`, `findMany`, `count`, `aggregate`,
  `$queryRaw`) on `prisma` or a transaction client `tx`
- `<<batch_load>>`: `findMany({ where: { id: { in: ids } } })` then `new Map(rows.map((r) => [r.id, r]))`
- `<<group_recompute>>`: `recalculateInvoiceTotals(tx, invoiceId)` in `src/services/invoiceLines.ts`, which
  aggregates every line of the invoice and rewrites its totals
- `<<group_deferral>>`: write each line without `recalculateInvoiceTotals`, then call it once per distinct invoice in
  the same transaction
- `<<query_count_assertion>>`: a `PrismaClient` with `log: [{ emit: 'event', level: 'query' }]` and a counter on
  `$on('query')`

## Sample

```ts
// src/services/invoiceLines.ts (excerpt)
export async function addInvoiceLines(lines: NewInvoiceLine[]) {
  return prisma.$transaction(async (tx) => {
    const created: InvoiceLine[] = [];
    for (const line of lines) {
      created.push(await addInvoiceLine(tx, line));
    }
    return created;
  });
}

export async function addInvoiceLine(tx: Prisma.TransactionClient, line: NewInvoiceLine) {
  const created = await tx.invoiceLine.create({ data: line });
  await recalculateInvoiceTotals(tx, line.invoiceId);
  return created;
}

async function recalculateInvoiceTotals(tx: Prisma.TransactionClient, invoiceId: string) {
  const sums = await tx.invoiceLine.aggregate({
    where: { invoiceId },
    _sum: { amountCents: true, taxCents: true },
  });
  await tx.invoice.update({
    where: { id: invoiceId },
    data: { subtotalCents: sums._sum.amountCents ?? 0, taxCents: sums._sum.taxCents ?? 0 },
  });
}
```

## Expected fix shape

- The loop writes each line without recalculating its invoice's totals.
- After the loop, inside the same transaction, the totals are recalculated once per distinct invoice the lines touch.
- `addInvoiceLine` called on its own still recalculates; the created lines and the final totals stay the same.

```ts
export async function addInvoiceLines(lines: NewInvoiceLine[]) {
  return prisma.$transaction(async (tx) => {
    const created: InvoiceLine[] = [];
    for (const line of lines) {
      created.push(await addInvoiceLine(tx, line, { recalculate: false }));
    }
    for (const invoiceId of new Set(lines.map((line) => line.invoiceId))) {
      await recalculateInvoiceTotals(tx, invoiceId);
    }
    return created;
  });
}

export async function addInvoiceLine(
  tx: Prisma.TransactionClient,
  line: NewInvoiceLine,
  { recalculate = true }: { recalculate?: boolean } = {},
) {
  const created = await tx.invoiceLine.create({ data: line });
  if (recalculate) {
    await recalculateInvoiceTotals(tx, line.invoiceId);
  }
  return created;
}
```
