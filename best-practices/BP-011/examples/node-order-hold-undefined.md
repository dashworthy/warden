# An order "hold" used in code before it is defined

## Bindings

- `<<paths>>`: `src/**`, `prisma/**`, `locales/**`
- `<<vocabulary_sources>>`: `prisma/schema.prisma`, `locales/en`, `openapi.yaml`, `docs/glossary.md`
- `<<design_doc>>`: `docs/rfcs/<change>.md`
- `<<terms_section>>`: `## Terms`
- `<<declaration_pattern>>`: `(class|interface|enum|function|const|type|model) [A-Za-z_]+|@(Controller|Get|Post|Put|Patch|Delete)\('[^']*'\)|[a-z][A-Za-z]* *[?]? *:`
- `<<code_words>>`: Controller, Dto, Entity, Guard, Interceptor, Module, Pipe, Repository, Resolver, Service, Spec;
  `Props`, a leading `use`
- `<<generated_paths>>`: `src/generated/**`

## Sample

```prisma
// prisma/schema.prisma (added)
model OrderHold {
  id         Int       @id @default(autoincrement())
  orderId    Int
  order      Order     @relation(fields: [orderId], references: [id])
  reason     String
  releasedAt DateTime?
}
```

```ts
// src/orders/order-holds.controller.ts (new)
@Controller('orders/:orderId/holds')
export class OrderHoldsController {
  constructor(private readonly holds: OrderHoldsService) {}

  @Post()
  place(@Param('orderId', ParseIntPipe) orderId: number, @Body() dto: PlaceHoldDto) {
    return this.holds.place(orderId, dto.reason);
  }

  @Post(':holdId/release')
  release(@Param('holdId', ParseIntPipe) holdId: number) {
    return this.holds.release(holdId);
  }
}
```

```markdown
<!-- Vocabulary at the base: prisma/schema.prisma has Customer, Order (status PENDING | PAID | SHIPPED | CANCELLED,
     placedAt), OrderLine and Shipment, and docs/glossary.md defines each of them. None of them, locales/en or
     openapi.yaml mentions a hold or releasing one. docs/rfcs/order-holds.md has no ## Terms section. -->
```

## Expected fix shape

- `docs/rfcs/order-holds.md` gets a `## Terms` entry defining "hold" and releasing one, saying why no existing word
  (an order status, a shipment) fits, and recording who asked for the change and their answer.
- The code keeps its names: once defined, "hold" and "release" are the domain's words. Renaming them to an
  existing word that doesn't mean the same thing would break the ward the other way.

```markdown
<!-- docs/rfcs/order-holds.md (added section) -->
## Terms

- **Hold**: a pause the warehouse puts on one order, with a reason, so it isn't picked. An order may have several
  holds over its life and at most one open. **Releasing** a hold ends it, and the order can be picked again.
  - Why a new word: an order's status records how far fulfilment has gone (pending, paid, shipped, cancelled), and a
    hold can happen while it is pending or paid and has its own reason and history, so it isn't a status. Nothing in
    the schema, translations, API spec or glossary names it.
  - Answer: the warehouse lead who asked for the change, 2026-11-09: "Yes, we call it a hold, and we release it."
```
