# Order schema with an unchecked customer, a hand-listed priority and a product check that counts deleted rows

## Bindings

- `<<paths>>`: `src/**/*.schema.ts`
- `<<id_param_pattern>>`: names ending `Id`, or `Ids` holding an array
- `<<exists_rule>>`: an async zod `.refine()` (parsed with `parseAsync`) that counts matching rows with Prisma
- `<<exclude_deleted>>`: `deletedAt: null` in the existence check's `where`
- `<<soft_delete_marker>>`: a `deletedAt DateTime?` field on the model in `prisma/schema.prisma`
- `<<enum_cast>>`: a domain type that maps the field to a TypeScript `enum`
- `<<enum_rule>>`: `z.nativeEnum(<Enum>)`

## Sample

```ts
// src/orders/order.schema.ts (new, excerpt; the route parses it with parseAsync)
import { z } from 'zod';
import { prisma } from '../db';

export const createOrderSchema = z.object({
  customerId: z.number().int().positive(),
  priorityId: z.number().int().refine((v) => [1, 2, 3].includes(v), 'Unknown priority'),
  productIds: z
    .array(z.number().int())
    .min(1)
    .refine(
      async (ids) => (await prisma.product.count({ where: { id: { in: ids } } })) === new Set(ids).size,
      'Unknown product',
    ),
  warehouseId: z.number().int().refine(async (id) => (await prisma.warehouse.count({ where: { id } })) > 0),
});

// prisma/schema.prisma: model Customer and model Product each have `deletedAt DateTime?`; Warehouse doesn't
// src/domain/order-priority.ts: export enum OrderPriority { Low = 1, Normal = 2, High = 3 }
// src/domain/order.ts: export type Order = { ...; priorityId: OrderPriority }
```

## Expected fix shape

- `customerId` gets an existence check, limited to rows with `deletedAt: null`.
- `productIds` adds `deletedAt: null` to its `where`, so a deleted product doesn't count.
- `priorityId` uses `z.nativeEnum(OrderPriority)`, not a hand-written list of numbers.
- `warehouseId` keeps its plain existence check: `Warehouse` doesn't soft-delete.
- The schema's other fields and the route that parses it stay the same.

```ts
const liveCustomer = async (id: number) => (await prisma.customer.count({ where: { id, deletedAt: null } })) > 0;

export const createOrderSchema = z.object({
  customerId: z.number().int().positive().refine(liveCustomer, 'Unknown customer'),
  priorityId: z.nativeEnum(OrderPriority),
  productIds: z
    .array(z.number().int())
    .min(1)
    .refine(
      async (ids) =>
        (await prisma.product.count({ where: { id: { in: ids }, deletedAt: null } })) === new Set(ids).size,
      'Unknown product',
    ),
  warehouseId: z.number().int().refine(async (id) => (await prisma.warehouse.count({ where: { id } })) > 0),
});
```
