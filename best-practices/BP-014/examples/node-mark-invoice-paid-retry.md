# A payment webhook whose conditional update is never checked, so a retry pays twice

## Bindings

- `<<paths>>`: `prisma/schema.prisma`, `src/**/*.service.ts`, `src/**/*.controller.ts`, `src/jobs/**`
- `<<state_definitions>>`: `enum InvoiceStatus { DRAFT OPEN PAID VOID }` in `prisma/schema.prisma`
- `<<state_write_pattern>>`: `status:|Status\.[A-Z_]+|At:|Until:|\.delete(Many)?\(`
- `<<transition_map>>`: none
- `<<concurrency_guard>>`: `updateMany({ where: { id, status: from } })` in `prisma.$transaction()`, checking `count`
- `<<early_checks>>`: NestJS pipes and guards, the webhook signature guard
- `<<side_effect_calls>>`: `\.add\(|\.publish\(|\.emit\(|fetch\(|axios\.|sendMail\(`
- `<<after_commit>>`: the queue call made after `prisma.$transaction()` resolves

## Sample

```ts
// src/invoices/invoices.service.ts (excerpt)
// The slice adds markPaid. States: DRAFT, OPEN, PAID, VOID; Invoice has no soft delete and no other column that
// gates paying. Paths: PaymentsWebhookController (POST /webhooks/payments, which the provider may deliver more
// than once) is the only caller, and nothing else writes PAID. The existing issue() and void() already reject a
// PAID invoice with conditional updates.
@Injectable()
export class InvoicesService {
  constructor(
    private readonly prisma: PrismaService,
    @InjectQueue('receipts') private readonly receipts: Queue,
  ) {}

  async markPaid(invoiceId: string, providerRef: string, amountCents: number) {
    return this.prisma.$transaction(async (tx) => {
      await tx.payment.create({ data: { invoiceId, providerRef, amountCents } });
      await tx.invoice.updateMany({
        where: { id: invoiceId, status: InvoiceStatus.OPEN },
        data: { status: InvoiceStatus.PAID, paidAt: new Date() },
      });
      await this.receipts.add('send-receipt', { invoiceId });
      return tx.invoice.findUniqueOrThrow({ where: { id: invoiceId } });
    });
  }
}
```

```ts
// src/invoices/invoices.service.test.ts (added)
it('marks an open invoice paid and queues a receipt', ...);
```

## Expected fix shape

- `OPEN` is the only allowed from-state; `DRAFT`, `PAID` and `VOID` are rejected. The conditional update runs first
  and its `count` is the guard: when it is 0 the call throws, so no payment row is created and no receipt is queued.
- The payment row is written in the same transaction as the status change, after the guard.
- The receipt is queued only after the transaction commits.
- Tests cover each rejected from-state, asserting no payment and no receipt, and a repeated call for the same
  invoice, asserting one payment and one receipt.

```ts
async markPaid(invoiceId: string, providerRef: string, amountCents: number) {
  const invoice = await this.prisma.$transaction(async (tx) => {
    const { count } = await tx.invoice.updateMany({
      where: { id: invoiceId, status: InvoiceStatus.OPEN },
      data: { status: InvoiceStatus.PAID, paidAt: new Date() },
    });
    if (count === 0) throw new InvoiceNotPayableError(invoiceId);

    await tx.payment.create({ data: { invoiceId, providerRef, amountCents } });
    return tx.invoice.findUniqueOrThrow({ where: { id: invoiceId } });
  });

  await this.receipts.add('send-receipt', { invoiceId }); // after commit
  return invoice;
}
```

```ts
it.each(['DRAFT', 'PAID', 'VOID'] as const)('rejects paying a %s invoice', async (status) => {
  const invoice = await createInvoice({ status });

  await expect(service.markPaid(invoice.id, 'ch_1', 5000)).rejects.toThrow(InvoiceNotPayableError);
  expect(await prisma.payment.count({ where: { invoiceId: invoice.id } })).toBe(0);
  expect(receipts.add).not.toHaveBeenCalled();
});

it('records one payment and one receipt when the webhook is retried', async () => {
  const invoice = await createInvoice({ status: 'OPEN' });

  await service.markPaid(invoice.id, 'ch_1', 5000);
  await expect(service.markPaid(invoice.id, 'ch_1', 5000)).rejects.toThrow(InvoiceNotPayableError);

  expect(await prisma.payment.count({ where: { invoiceId: invoice.id } })).toBe(1);
  expect(receipts.add).toHaveBeenCalledTimes(1);
});
```
