# A real bug fixed in a shared file the change doesn't need

## Bindings

- `<<scope_document>>`: `docs/design/<change>.md`
- `<<planned_files>>`: the design's "Files touched" list
- `<<follow_up_list>>`: an issue labelled `follow-up`
- `<<project_conventions>>`: a module, controller, service and DTO per resource; Prisma access only in services
- `<<static_checks>>`: `npx tsc --noEmit` and `npx eslint .`
- `<<generated_outputs>>`: `package-lock.json`, and `prisma/migrations/**` from `prisma migrate dev`
- `<<formatter>>`: `npx prettier --write`

## Sample

```diff
// Scope (docs/design/cancel-reason.md): "Cancelling an order records the reason the customer gave."
//   Files touched: src/orders/orders.service.ts, src/orders/orders.controller.ts, prisma/schema.prisma,
//   test/orders.e2e-spec.ts. New: src/orders/dto/cancel-order.dto.ts

// src/orders/orders.service.ts
-  async cancel(id: string): Promise<Order> {
+  async cancel(id: string, dto: CancelOrderDto): Promise<Order> {
     return this.prisma.order.update({
       where: { id },
-      data: { status: 'CANCELLED', cancelledAt: new Date() },
+      data: { status: 'CANCELLED', cancelledAt: new Date(), cancelReason: dto.reason },
     });
   }

// src/common/pagination.ts
 export function toPrismaPage(page: number, take: number) {
-  return { skip: page * take, take };
+  // pages are 1-based in the API, so page 1 was skipping the first page of results
+  return { skip: (page - 1) * take, take };
 }
```

## Expected fix shape

- The change to `orders.service.ts` (and the listed controller, DTO, schema, migration and test) stays exactly as it is.
- The edit to `src/common/pagination.ts`, a file the design doesn't list and the cancel reason doesn't need, is
  reverted, even though it fixes a real bug: it changes every paginated list.
- The bug is recorded as a `follow-up` issue with file:line, the proposed change and why, to be fixed in its own change
  once a person approves it.

```ts
// src/orders/orders.service.ts: as in the sample
// src/common/pagination.ts: unchanged
export function toPrismaPage(page: number, take: number) {
  return { skip: page * take, take };
}
```

```markdown
<!-- New issue "Pagination skips the first page", label: follow-up -->
`src/common/pagination.ts:2`: `toPrismaPage` computes `skip: page * take`, but API pages are 1-based, so `page=1`
skips the first `take` results on every paginated list. Proposed: `skip: (page - 1) * take`, with a test per list
endpoint that the first page returns the first records.
```
