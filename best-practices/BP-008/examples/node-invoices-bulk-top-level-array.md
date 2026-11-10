# Bulk invoice route that takes a bare array of looser records and returns a count

## Bindings

- `<<paths>>`: `src/**/*.routes.ts`, `src/**/*.schema.ts`, `web/src/**`
- `<<route_files>>`: `src/**/*.routes.ts` (Express routers)
- `<<request_validator>>`: the zod schema the route parses its body with
- `<<response_type>>`: the handler's `Response<T>`
- `<<list_test>>`: `Array.isArray(`, `z.union([`, `.or(z.array(`
- `<<bulk_route_convention>>`: `POST /<resource>/bulk/<action>`, handler `bulk<Action>`
- `<<record_fields>>`: `model Invoice` and its `lines InvoiceLine[]` relation in `prisma/schema.prisma`
- `<<client_call>>`: `api.post<T>('/<resource>/…', …)` in `web/src/**`

## Sample

```ts
// src/invoices/invoice.routes.ts (excerpt; POST /invoices and createInvoiceSchema already exist)
export const createInvoiceSchema = z.object({
  customerId: z.number().int(),
  currency: z.string().length(3),
  dueDate: z.coerce.date(),
  lines: z.array(invoiceLineSchema).min(1),
});

router.post('/invoices', async (req, res: Response<InvoiceDto>) => {
  const invoice = await createInvoice(createInvoiceSchema.parse(req.body));
  res.status(201).json(toInvoiceDto(invoice));
});

// new
const bulkInvoicesSchema = z.array(
  z.object({
    customerId: z.number().int(),
    currency: z.string(),
    dueDate: z.coerce.date().optional(),
    lines: z.array(invoiceLineSchema),
  }),
);

router.post('/invoices/bulk/create', async (req, res: Response<{ created: number }>) => {
  const invoices = bulkInvoicesSchema.parse(req.body);
  const created = await prisma.$transaction(invoices.map((data) => createInvoice(data)));
  res.status(201).json({ created: created.length });
});
```

## Expected fix shape

- The body is an object with the records under `invoices`, not a top-level array.
- Each record is the single route's `createInvoiceSchema`, so `currency` keeps its length, `dueDate` stays required
  and `lines` keeps `min(1)`; a batch limit may be added.
- The route returns `InvoiceDto[]`, one per invoice in the order sent, not a count.
- `POST /invoices` and `createInvoiceSchema` are unchanged.

```ts
const bulkCreateInvoicesSchema = z.object({
  invoices: z.array(createInvoiceSchema).min(1).max(100),
});

router.post('/invoices/bulk/create', async (req, res: Response<InvoiceDto[]>) => {
  const { invoices } = bulkCreateInvoicesSchema.parse(req.body);
  const created = await prisma.$transaction(invoices.map((data) => createInvoice(data)));
  res.status(201).json(created.map(toInvoiceDto));
});

// web/src/invoices/api.ts
export const bulkCreateInvoices = (invoices: CreateInvoiceInput[]) =>
  api.post<InvoiceDto[]>('/invoices/bulk/create', { invoices });
```
