# A discount test that passes before the discount exists

## Bindings

- `<<paths>>`: `src/**`, `test/**`
- `<<test_paths>>`: `**/*.test.ts`, `test/**`
- `<<test_command>>`: `npx vitest run -t '<test name>'`
- `<<exempt_paths>>`: `prisma/migrations/**`, `src/generated/**`, `*.config.ts`
- `<<task_list>>`: the PR description's Tasks checklist and Review table
- `<<test_first_record>>`: the commit history: a `test:` commit before the `feat:` or `fix:` commit that makes it pass
- `<<behavior_spec>>`: the linked issue's acceptance criteria
- `<<assertion_pattern>>`: `expect\(|assert\.|toBe|toEqual|toMatch`
- `<<mock_assertion_pattern>>`: `toHaveBeenCalled|vi\.fn|jest\.fn|mockResolvedValue`
- `<<ui_paths>>`: none (an API-only service), so step 5 is N/A
- `<<ui_test_paths>>`: none
- `<<page_error_check>>`: none

## Sample

```ts
// src/orders/orders.routes.test.ts (excerpt; added in 9c41e07)
it('takes 10% off an order over $100', async () => {
  const res = await request(app)
    .post('/orders')
    .send({ items: [{ sku: 'MUG-01', qty: 3, unitPriceCents: 4000 }] });

  expect(res.status).toBe(201);
  expect(res.body.totalCents).toBeLessThanOrEqual(12000);
});
```

```text
$ git log --oneline --name-only develop..HEAD
9c41e07 feat: 10% off orders over $100 (issue #214)
src/orders/pricing.ts
src/orders/orders.routes.test.ts
```

Run on the base with only the test file applied, the order totals 12000 (no discount yet) and the test passes.

## Expected fix shape

- The test asserts the discounted total exactly (10800 for a 12000 order), so it fails on the base for the
  discount being missing.
- The history shows it failing first: the test is committed on its own before the pricing change, and running it on
  the base fails with the expected and received totals.
- `src/orders/pricing.ts` is unchanged by the fix.
- Run on the base with only the test file applied, it fails with "expected 10800, received 12000".

```text
$ git log --oneline --name-only develop..HEAD
b72d5a1 feat: 10% off orders over $100 (issue #214)
src/orders/pricing.ts
3e09f8c test: an order over $100 gets 10% off (fails: expected 10800, received 12000)
src/orders/orders.routes.test.ts
```

```ts
it('takes 10% off an order over $100', async () => {
  const res = await request(app)
    .post('/orders')
    .send({ items: [{ sku: 'MUG-01', qty: 3, unitPriceCents: 4000 }] });

  expect(res.status).toBe(201);
  expect(res.body.totalCents).toBe(10800);
});
```
