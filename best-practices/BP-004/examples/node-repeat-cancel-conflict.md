# A repeat request turned into an error, checked against one consumer

## Bindings

- `<<paths>>`: `src/**`, `prisma/schema.prisma`
- `<<list_api_routes>>`: `git grep -nE '@(Controller|Get|Post|Put|Patch|Delete)\(' src`
- `<<fan_out_code>>`: `src/common/**`, the Prisma client extensions in `src/prisma/prisma.service.ts`
- `<<consumer_groups>>`: `/v1/*`: the web app in `acme/storefront-web` and the warehouse service in `acme/warehouse`
  (`gh search code --owner acme`); `/partner/*`: external partners, unsearchable
- `<<api_impact_record>>`: the design doc's `## API impact` section
- `<<api_test_cmd>>`: `npx jest <file>`, with supertest against the bootstrapped Nest app
- `<<api_features>>`: `?status=`, `?sort=`; `?take=` and `?cursor=`, defaulting to `PAGE_SIZE`; 400 for invalid input
- `<<follow_up_list>>`: an issue labelled `follow-up`
- `<<human_review>>`: "For each route listed as an unverified risk, can its external consumers absorb the contract
  change recorded for it?"

## Sample

```diff
// src/orders/orders.service.ts (POST /v1/orders/:id/cancel)
// Change: "an order that has shipped can't be cancelled (409)"
   async cancel(id: string): Promise<Order> {
     const order = await this.prisma.order.findUniqueOrThrow({ where: { id } });
-    if (order.status === 'CANCELLED') return order;
+    if (order.status !== 'PENDING') {
+      throw new ConflictException(`Order ${id} is ${order.status}`);
+    }
     return this.prisma.order.update({ where: { id }, data: { status: 'CANCELLED', cancelledAt: new Date() } });
   }
```

```markdown
## API impact

| Route | Method, URI | Consumers | Reached by |
|---|---|---|---|
| `OrdersController.cancel` | POST `/v1/orders/:id/cancel` | Web, warehouse | `OrdersService.cancel` |

**Consumers:** web `src/api/orders.ts:41` (cancel button, once); warehouse `src/sync/cancel-order.ts:27`, which
repeats the same POST after a timeout and alerts on any non-2xx.

| Test | Base | Head |
|---|---|---|
| `cancel › cancels a pending order, as the web app sends` | pass | pass |
| `cancel › returns 409 when the warehouse retries a cancelled order` | fail | pass (new behavior) |
| `cancel › returns 409 for a shipped order` | fail | pass (new behavior) |

**Already broken:** none. **Unverified risks:** none.
```

## Expected fix shape

- Only a shipped or delivered order gets 409; cancelling an already cancelled order still returns it with 200.
- The warehouse's retry of a cancelled order gets 200 again, proven by a probe from its call site's request.
- Each consumer request, and the new 409, has a test with base and head results; none regresses.

```ts
// src/orders/orders.service.ts
if (order.status === 'CANCELLED') return order;
if (order.status === 'SHIPPED' || order.status === 'DELIVERED') {
  throw new ConflictException(`Order ${id} is ${order.status}`);
}
```

```markdown
## API impact

| Route | Method, URI | Consumers | Reached by |
|---|---|---|---|
| `OrdersController.cancel` | POST `/v1/orders/:id/cancel` | Web, warehouse | `OrdersService.cancel` |

**Consumers:** web `src/api/orders.ts:41` (cancel button, once); warehouse `src/sync/cancel-order.ts:27`, which
repeats the same POST after a timeout and alerts on any non-2xx.

| Test | Base | Head |
|---|---|---|
| `cancel › cancels a pending order, as the web app sends` | pass | pass |
| `cancel › returns 200 when the warehouse retries a cancelled order` | pass | pass |
| `cancel › returns 409 for a shipped order` | fail | pass (new behavior) |

**Already broken:** none. **Unverified risks:** none.
```
