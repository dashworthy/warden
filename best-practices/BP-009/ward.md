---
version: 1
phases:
  - 'code'
---

# BP-009: Do per-set work once, not once per item

**Description:** Code that loops over items whose count comes from input or data (a bulk endpoint, an import, a
backfill, an export, a mapper or factory applied to a list) loads what the loop needs before it starts, instead of one
query per item, and recomputes shared state once per affected group after the loop, instead of once per item.

**Rationale:** A query per item turns a 100-item bulk create into 100 extra round trips. A recomputation per item is
worse: work that rewrites or recomputes every member of a group (re-sequencing a list, recalculating a parent's
totals, re-indexing a document) costs in proportion to the group's size, so running it after each of 100 inserts into
one group does the whole group 100 times, inside one transaction that holds its locks the whole time. Neither shows up
in a test with two items, so it ships, and then times out or deadlocks for the customer with the biggest group. The
cheap form is usually a small edit: <<batch_load>> before the loop, and <<group_deferral>> with one run per distinct
group after it.

**Violations:**

```php
// Laravel: one customer lookup per imported row
foreach ($rows as $row) {
    $customer = Customer::query()->where('email', $row['customer_email'])->firstOrFail();
    Invoice::query()->create([...$row, 'customer_id' => $customer->id]);
}
```

```ts
// Node (Prisma): one product lookup per order line in a bulk create
for (const line of input.lines) {
  const product = await prisma.product.findUniqueOrThrow({ where: { sku: line.sku } });
  await prisma.orderLine.create({ data: { orderId, productId: product.id, quantity: line.quantity } });
}
```

Each item costs a lookup that one query before the loop could answer for every item.

```text
// Any stack: the group recomputed per item
for each item in items:
    insert item into its list
    renumber every item in that list      <- once per item, though many items share a list
```

The renumbering runs once per item, so a list that gains n items is rewritten n times.

**Compliant examples:**

```php
// Laravel: one query for every customer the rows name, looked up by key in the loop
$customers = Customer::query()->whereIn('email', array_column($rows, 'customer_email'))->get()->keyBy('email');

foreach ($rows as $row) {
    Invoice::query()->create([...$row, 'customer_id' => $customers[$row['customer_email']]->id]);
}
```

```ts
// Node (Prisma): one query for every product the lines name
const products = await prisma.product.findMany({ where: { sku: { in: input.lines.map((l) => l.sku) } } });
const bySku = new Map(products.map((p) => [p.sku, p]));

for (const line of input.lines) {
  await prisma.orderLine.create({ data: { orderId, productId: bySku.get(line.sku)!.id, quantity: line.quantity } });
}
```

```text
// Any stack: group work off in the loop, once per distinct group after it
for each item in items:
    insert item into its list, without renumbering
for each distinct list the items touched:
    renumber that list once
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where code that loops over data lives: handlers, services, jobs, imports, exports, backfills | List the source roots (`git ls-files \| cut -d/ -f1-2 \| sort -u`) and keep those holding application code and data backfills; leave out tests, frontend and generated code | `app/**`, `database/migrations/**` | `src/**`, `scripts/**` |
| `<<loop_pattern>>` | An extended regex matching the loop constructs of the project's server-side language | Take the language's loop statements and the collection methods that take a callback (`map`, `each`, `forEach`, `filter`, `reduce`, `flatMap`); check it with `git grep -nE '<pattern>' -- <paths> \| head` | `foreach *\(\|for *\(\|while *\(\|->(map\|each\|filter\|reduce\|flatMap)\(\|array_map\(` | `for *\(\|while *\(\|\.(map\|forEach\|filter\|reduce\|flatMap)\(` |
| `<<query_calls>>` | The calls that read from the database, including relation reads that load lazily | Read the ORM or query builder the project uses (its package manifest and the data-access folder), list its read methods, and note whether relations load lazily on access | Eloquent and `DB` reads (`find`, `findOrFail`, `first`, `get`, `exists`, `count`, `sum`), and a relation property read that wasn't loaded with `with()`/`load()` | Prisma reads (`findUnique`, `findUniqueOrThrow`, `findFirst`, `findMany`, `count`, `aggregate`, `$queryRaw`); Prisma never loads relations lazily |
| `<<batch_load>>` | How the project loads many rows in one query and looks them up by key | Search the code for existing set lookups (`git grep -nE 'whereIn\|keyBy\|\{ in:\|new Map\('`) and eager loading; if none exist, the ORM's "where key in list" query plus an in-memory map | `whereIn(...)->get()->keyBy()`, `pluck('value', 'id')`, `with()`/`load()`, `withSum()`/`withCount()` | `findMany({ where: { id: { in: ids } } })` then `new Map(rows.map((r) => [r.id, r]))`; `include`/`select` on the outer query |
| `<<group_recompute>>` | Operations that recompute or rewrite state for a whole group, and the hooks that run them on each write | Search for functions that take a parent or group id and rewrite every member or a derived total (`git grep -niE 'recalculat\|resequenc\|renumber\|reindex\|refresh.*total'`), and for model events, observers or ORM middleware that call them on create or update. If none exist, step 2 still applies to any such work the change adds | Actions or jobs that rewrite every child of a parent, model observers on `created`/`saved`, search re-indexing on save | Service functions that recompute a parent, Prisma client extensions or middleware on `create`/`update`, search-index sync |
| `<<group_deferral>>` | How group work is turned off for each item and run once per group | Look for an existing bulk path (an import or batch job) and copy how it skips the per-item group work; if none exists, the change calls the item write without the group step and runs the group step once per distinct group after the loop | An option or method on the action that skips the recompute, or `Model::withoutEvents()` around the loop, then the recompute once per distinct parent | An option such as `{ recalculate: false }` on the item write, then the recompute once per distinct parent in the same transaction |
| `<<query_count_assertion>>` | Optional: how a test pins the number of queries. Without it, step 4 is skipped | Search the tests for an existing query-count assertion (`git grep -nE 'QueryLog\|QueryCount\|\$on\(.query'`); otherwise the test framework's or ORM's query log | `$this->expectsDatabaseQueryCount(n)`, or `DB::enableQueryLog()` then `DB::getQueryLog()` | A `PrismaClient` with `log: [{ emit: 'event', level: 'query' }]` and a counter on `$on('query')` |

**Verification:**

1. List the loops the change adds or changes, under `<<paths>>`, over a collection whose size comes from input or data.
   A loop over a fixed set (an enum's cases, a constant list) is out of scope. If there are none, the ward is N/A.
   `git diff -U0 <base>...HEAD -- <each of <<paths>> as ':(glob)<path>'> | grep -E '^\+' | grep -E '<<loop_pattern>>'`
2. For each loop, read its body and everything it calls, down to the queries, and list the per-item work:
   - a query: any of `<<query_calls>>`, a mapper, factory or constructor that runs one, or a relation read that
     isn't loaded before the loop;
   - shared-state work: any of `<<group_recompute>>`, or other work the change adds that recomputes or rewrites
     state for a whole group (renumbering, totals, re-indexing), run once per item when several items can share the
     group.
   Writes of the item itself (its own insert or update, or the function that creates it) are the loop's job and don't
   count.
3. Check each per-item query and recomputation is lifted out of the loop: lookups loaded once before it
   (`<<batch_load>>`), and group work turned off in the loop and run once per distinct group after it
   (`<<group_deferral>>`).
4. When `<<query_count_assertion>>` is bound and the change adds a test for the loop, check it pins the count with
   several items, or shows a table read once.

- PASS when no loop from step 1 runs a query or a group recomputation per item, beyond writing the item itself.
- FAIL when a loop runs a lookup query per item that could be loaded once before it, reads a relation that isn't
  loaded before it, or runs a group recomputation per item when items can share the group.

**Applicability:** Code under `<<paths>>` that the change adds or changes: request handlers, services and actions,
query objects, mappers and factories, imports, exports, jobs and data backfills. Out of scope: loops over a fixed
handful of known values, per-item work that is a write the item needs, and existing loops the change doesn't touch,
which belong in a change of their own.
