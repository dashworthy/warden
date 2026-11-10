# Discount codes moved to a foreign key, for the codes that still match

## Bindings

- `<<paths>>`: `migrations/**`
- `<<schema_source>>`: the migrations that touch the table, in order
- `<<soft_delete_column>>`: `deleted_at`
- `<<soft_delete_unique_rule>>`: a partial unique index `WHERE deleted_at IS NULL`
- `<<transactional_schema_changes>>`: Yes (PostgreSQL, and Knex runs each migration in a transaction)
- `<<data_change_unit>>`: an exported function in `src/db/backfills/` with a Vitest test against a test database

## Sample

```ts
// migrations/20261112120000_link_orders_to_discounts.ts
// orders.discount_code text NULL; orders.deleted_at timestamptz NULL
// discounts.code text NOT NULL UNIQUE; no deleted_at: a discount row is hard-deleted when its promotion ends
export async function up(knex: Knex): Promise<void> {
  await knex.schema.alterTable('orders', (table) => {
    table.integer('discount_id').references('discounts.id')
  })

  const orders = await knex('orders').whereNull('deleted_at').whereNotNull('discount_code')
  for (const order of orders) {
    const discount = await knex('discounts').where({ code: order.discount_code }).first()
    await knex('orders').where({ id: order.id }).update({ discount_id: discount.id })
  }

  await knex.schema.alterTable('orders', (table) => {
    table.dropColumn('discount_code')
  })
}
```

## Expected fix shape

- Linking runs in a tested function, in one statement, deleted orders included, setting only orders still unlinked.
- A code that matches no discount (its promotion ended, or it was imported misspelled) doesn't fail the migration
  and isn't lost: `discount_code` is kept, and dropping it is left to a later change once those orders are resolved.
- Tests cover an empty table, a matching code, a code with no discount, a NULL code, a deleted order and a second
  run.
- No guard for a part-way rerun: the migration runs in a transaction.

```ts
// migrations/20261112120000_link_orders_to_discounts.ts
// orders.discount_code text NULL; orders.deleted_at timestamptz NULL
// discounts.code text NOT NULL UNIQUE; no deleted_at: a discount row is hard-deleted when its promotion ends
export async function up(knex: Knex): Promise<void> {
  await knex.schema.alterTable('orders', (table) => {
    table.integer('discount_id').nullable().references('discounts.id')
  })
  // discount_code stays: orders whose code matches no discount keep it until someone resolves them
  await linkOrdersToDiscounts(knex)
}

// src/db/backfills/linkOrdersToDiscounts.ts
/** Links every order, deleted ones included, to the discount its code names, if there still is one */
export async function linkOrdersToDiscounts(knex: Knex): Promise<number> {
  const result = await knex.raw(`
    UPDATE orders SET discount_id = discounts.id
    FROM discounts
    WHERE orders.discount_code = discounts.code AND orders.discount_id IS NULL
  `)
  return result.rowCount
}

// src/db/backfills/linkOrdersToDiscounts.test.ts
it('changes nothing on an empty table', async () => { /* … */ })
it('links an order to the discount its code names', async () => { /* … */ })
it('leaves an order whose code matches no discount unlinked, with its code', async () => { /* … */ })
it('leaves an order with no code alone', async () => { /* … */ })
it('links a deleted order', async () => { /* … */ })
it('changes nothing on a second run', async () => { /* … */ })
```
