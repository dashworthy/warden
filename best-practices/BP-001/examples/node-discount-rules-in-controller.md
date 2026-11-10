# Discount rules and pricing written in a NestJS controller

## Bindings

- `<<paths>>`: `src/**/*.controller.ts`, `src/**/*.service.ts`
- `<<controller_paths>>`: `':(glob)src/**/*.controller.ts'`
- `<<domain_operation>>`: a method on the module's `@Injectable()` service, such as `OrdersService`
- `<<domain_operation_paths>>`: `':(glob)src/**/*.service.ts'`
- `<<request_validation>>`: a class-validator DTO checked by the global `ValidationPipe`, plus route guards
- `<<transaction_fn>>`: `this.prisma.$transaction()`
- `<<write_signals>>`: `\.(create|createMany|update|updateMany|upsert|delete|deleteMany)\(|\$transaction|\$executeRaw|FOR UPDATE|\.emit\(|mailer\.|fetch\(|axios\.`
- `<<list_query_helpers>>`: none
- `<<bulk_endpoint_convention>>`: none

## Sample

```ts
// src/orders/orders.controller.ts (excerpt)
@Post(':id/discount')
async applyDiscount(
  @Param('id', ParseIntPipe) id: number,
  @Body() dto: ApplyDiscountDto,
): Promise<OrderResponse> {
  const order = await this.prisma.order.findUniqueOrThrow({ where: { id }, include: { lines: true } });
  const discount = await this.prisma.discountCode.findUnique({ where: { code: dto.code } });

  if (!discount || discount.expiresAt < new Date()) {
    throw new UnprocessableEntityException({ code: 'DISCOUNT_INVALID' });
  }

  const subtotal = order.lines.reduce((sum, line) => sum + line.unitPrice * line.quantity, 0);
  const discountTotal = Math.round((subtotal * discount.percentOff) / 100);

  const updated = await this.prisma.order.update({
    where: { id },
    data: { discountCodeId: discount.id, discountTotal, total: subtotal - discountTotal },
  });

  return OrderResponse.from(updated);
}
```

## Expected fix shape

- The discount code lookup, the expiry guard, the subtotal and discount calculation and the order update move into
  one `OrdersService` method.
- The controller makes that one call and maps its result to `OrderResponse`.
- The route, `ApplyDiscountDto`, the response shape and the exception thrown for an invalid code stay the same.

```ts
// src/orders/orders.controller.ts (excerpt)
@Post(':id/discount')
async applyDiscount(
  @Param('id', ParseIntPipe) id: number,
  @Body() dto: ApplyDiscountDto,
): Promise<OrderResponse> {
  return OrderResponse.from(await this.orders.applyDiscount(id, dto.code));
}

// src/orders/orders.service.ts (excerpt)
async applyDiscount(id: number, code: string): Promise<Order> {
  const order = await this.prisma.order.findUniqueOrThrow({ where: { id }, include: { lines: true } });
  const discount = await this.prisma.discountCode.findUnique({ where: { code } });

  if (!discount || discount.expiresAt < new Date()) {
    throw new UnprocessableEntityException({ code: 'DISCOUNT_INVALID' });
  }

  const subtotal = order.lines.reduce((sum, line) => sum + line.unitPrice * line.quantity, 0);
  const discountTotal = Math.round((subtotal * discount.percentOff) / 100);

  return this.prisma.order.update({
    where: { id },
    data: { discountCodeId: discount.id, discountTotal, total: subtotal - discountTotal },
  });
}
```
