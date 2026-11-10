---
version: 1
phases:
  - code
---

# BP-006: Make migrations safe for every state existing data can be in

**Description:** A migration that changes a table's structure or data is written against the table as its schema
defines it now, and handles every state its rows can be in on every database it runs on: an empty table on a new
database, every value the current column definitions allow on an existing one, soft-deleted rows included, and a
run that stops part way and is run again.

**Rationale:** A migration runs at deploy on every database the deploy reaches. Where an application keeps a
database per customer, or serves customers whose data differs, those include new databases with empty tables and
old ones holding years of rows written by older code, imports and hand fixes; even a single production database
holds rows the developer's never had. A migration tested only against the developer's database can fail on one
database in production and leave it half migrated, because a database that doesn't roll back schema changes commits
each one as it runs; the deploy then stops for every database after it. A data fix that skips NULLs or
soft-deleted rows leaves bad data that looks fixed. The schema, not today's code, is the limit of what the data can
hold, so that is what a migration has to handle.

**Violations:**

```php
// Laravel. customers.tax_number is a nullable string with no unique index today
Schema::table('customers', function (Blueprint $table) {
    $table->unique('tax_number');
});
```

Existing databases can hold duplicate tax numbers, and soft-deleted customers keep theirs: the index fails on any
such database, and it counts deleted rows without saying why.

```ts
// Node (Knex). orders.warehouse_id is nullable: orders placed before warehouses existed have none
await knex.schema.alterTable('orders', (table) => {
  table.integer('warehouse_id').notNullable().alter()
})
```

Making the column required fails on any database holding an older order, and the change gives no value or decision
for those rows.

**Compliant examples:**

```text
up:
  merge the customers that share a tax number (a tested <<data_change_unit>>)
  add the unique index on tax_number, following <<soft_delete_unique_rule>>
```

```ts
// Node (Knex). Inserts the status on a new database and leaves a database that has it alone, so a rerun succeeds
await knex('order_statuses').insert({ id: 4, name: 'On hold' }).onConflict('id').ignore()
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where migrations live, for every database kind the project migrates | The migration tool's config (`knexfile`, its `migrations.directory`; `prisma/migrations`; the framework's migrations folder), or `git ls-files \| grep -i migration \| cut -d/ -f1-3 \| sort -u`. Include each folder, such as one for a shared database and one for per-customer databases. No migrations: the ward doesn't apply. | `database/migrations/**` | `migrations/**` |
| `<<schema_source>>` | Where a table's current definition is read | Look for a schema dump or schema file: `git ls-files \| grep -i -E '(schema\|structure)\.(sql\|prisma\|rb)$'`. The definition is that file's table, then every later migration that changes it. If there is none, read every migration that touches the table, in order. | `database/schema/mysql-schema.sql`, then later migrations | the migrations that touch the table, in order |
| `<<soft_delete_column>>` | Optional. The column that marks a row deleted without removing it | `git grep -n -E 'softDeletes\|SoftDeletes\|deleted_at\|paranoid\|is_deleted' -- <app and migration folders>`. Without it, the soft-deleted state and the unique-index rule don't apply. | `deleted_at` | `deleted_at` |
| `<<soft_delete_unique_rule>>` | Optional. How a unique index leaves soft-deleted rows out | Read the existing unique indexes on tables with `<<soft_delete_column>>`; the pattern they share is the rule. If they have none, or differ, the person decides; until then each unique index on such a table records whether deleted rows count. | a generated column, 1 for live rows and NULL for deleted ones, added to the index (`unique(['tax_number', 'is_live'])`): MySQL has no partial indexes | a partial unique index `WHERE deleted_at IS NULL` (PostgreSQL) |
| `<<transactional_schema_changes>>` | Whether a migration that fails part way rolls back its schema changes | The database driver (the default connection, the `knexfile` client): PostgreSQL and SQLite roll back schema changes in a transaction; MySQL, MariaDB and Oracle commit each one. Then whether the migration runner wraps each migration in a transaction, and whether this migration opts out. Several databases of different kinds: No if any is No. | No (MySQL) | Yes (PostgreSQL, and Knex runs each migration in a transaction) |
| `<<data_change_unit>>` | Where a data change on existing rows lives so it can be tested, and where its tests go | Look for existing backfills or data fixes (`git grep -l -i -E 'backfill\|data migration'`) and the classes or functions migrations already call. If none, the project's usual place for domain logic, with a test where the project's other tests of that code live. | an invokable class in `app/Actions` with a Pest test in `tests/Feature/Actions` | an exported function in `src/db/backfills/` with a Vitest test against a test database |

**Verification:**

1. List the migrations the change adds or changes, using one `':(glob)<glob>'` pathspec per glob of `<<paths>>`.
   If none, the ward is N/A.
   `git diff --name-only --diff-filter=AM <base>...HEAD -- ':(glob)<<paths>>'`
2. For each table a migration touches, read its current definition from `<<schema_source>>`, then every later
   migration that changes it: ``git grep -l -E "[\"'\`]<table>[\"'\`]" -- ':(glob)<<paths>>'``.
3. List the states the migration must handle, from that definition:
   - an empty table, as on a database created after this deploy;
   - NULL in every nullable column it reads, constrains or changes;
   - soft-deleted rows (`<<soft_delete_column>>` set), which still occupy unique indexes and foreign keys;
   - rows that break the constraint being added: duplicates for a unique index, NULLs for a required column, values
     that don't fit a narrower type or length, rows with no parent for a foreign key;
   - every value the column's type allows, not only the ones current code writes: every enum or status value, and
     any text or number for a free-text or numeric column;
   - a rerun: the migration run again after stopping part way, and its data change run a second time; neither may
     fail or apply its change twice.
4. Check that the migration handles each state:
   - a constraint added to existing data is preceded, in the same migration or an earlier one, by resolving the
     rows that break it, or the migration or its pull request records why none can exist;
   - a unique index on a table with `<<soft_delete_column>>` follows `<<soft_delete_unique_rule>>`, unless the
     migration or its pull request records why soft-deleted rows must count;
   - a data change is idempotent (an insert that ignores or merges an existing row, an upsert, a `where` that
     matches only rows still to change) and works on an empty table;
   - when `<<transactional_schema_changes>>` is No, a migration with more than one step (schema changes, or a
     schema change and a data change) can be rerun after any step fails: each schema change is guarded by a check
     that it hasn't happened yet, or the migration holds a single step;
   - a data change that updates, deletes or derives rows from existing data runs in `<<data_change_unit>>`, whose
     tests cover each state from step 3 that applies, including the empty table and a second run. Inserting a fixed
     set of rows (lookup values) may stay in the migration.

- PASS when every state from step 3 that applies to the migration is handled by its code or by a tested
  `<<data_change_unit>>`, and each data change's tests cover those states.
- FAIL when a constraint is added without resolving the existing rows that break it; a unique index on a
  soft-deleting table leaves deleted rows in with no recorded reason; a data change fails or repeats on a rerun or
  an empty table; a migration can't be rerun after a step fails when `<<transactional_schema_changes>>` is No; or a
  data change on existing rows has no test for a state that applies.

**Applicability:** Migrations under `<<paths>>` that a change adds or changes, whether they change structure
(columns, types, indexes, foreign keys) or data (inserts, updates, deletes, backfills), for every database the
project migrates, whether it has one or many. Creating a new table with no existing rows only needs the rerun
check. Seeders, factories and test fixtures are out of scope.
