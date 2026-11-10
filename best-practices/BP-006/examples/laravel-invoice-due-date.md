# A required due date derived from columns that can be NULL

## Bindings

- `<<paths>>`: `database/migrations/**`
- `<<schema_source>>`: `database/schema/mysql-schema.sql`, then later migrations
- `<<soft_delete_column>>`: `deleted_at`
- `<<soft_delete_unique_rule>>`: a generated `is_live` column (1 for live rows, NULL for deleted ones) in the index
- `<<transactional_schema_changes>>`: No (MySQL)
- `<<data_change_unit>>`: an invokable class in `app/Actions` with a Pest test in `tests/Feature/Actions`

## Sample

```php
// database/migrations/2026_11_12_090000_add_due_date_to_invoices_table.php
// invoices.issued_at datetime NULL (drafts have none); payment_terms_days int unsigned NULL; deleted_at timestamp NULL
public function up(): void
{
    Schema::table('invoices', function (Blueprint $table) {
        $table->date('due_date')->nullable();
    });

    DB::table('invoices')
        ->whereNull('deleted_at')
        ->update(['due_date' => DB::raw('DATE_ADD(issued_at, INTERVAL payment_terms_days DAY)')]);

    Schema::table('invoices', function (Blueprint $table) {
        $table->date('due_date')->nullable(false)->change();
    });
}
```

## Expected fix shape

- `due_date` stays nullable: a draft has no issue date, so it has no due date (recorded in the migration).
- An issued invoice with no `payment_terms_days` is due after the default terms the application already applies.
- The backfill runs in a tested Action, deleted invoices included, updating only rows still to change, with tests
  for an empty table, issued with and without terms, a draft, a deleted invoice and a second run.
- Adding the column is guarded, because MySQL commits it before the backfill runs.

```php
// database/migrations/2026_11_12_090000_add_due_date_to_invoices_table.php
public function up(): void
{
    if (! Schema::hasColumn('invoices', 'due_date')) {
        Schema::table('invoices', function (Blueprint $table) {
            $table->date('due_date')->nullable(); // a draft has no issue date, so no due date
        });
    }

    app(BackfillInvoiceDueDates::class)();
}

// app/Actions/Invoices/BackfillInvoiceDueDates.php
/** Sets the due date of every issued invoice, deleted ones included, that has none yet */
class BackfillInvoiceDueDates
{
    public function __invoke(): int
    {
        return DB::table('invoices')
            ->whereNotNull('issued_at')
            ->whereNull('due_date')
            ->update(['due_date' => DB::raw(sprintf(
                'DATE_ADD(issued_at, INTERVAL COALESCE(payment_terms_days, %d) DAY)',
                (int) config('invoices.default_terms_days'),
            ))]);
    }
}

// tests/Feature/Actions/Invoices/BackfillInvoiceDueDatesTest.php
test('an empty table changes nothing');
test('an issued invoice is due its terms after issue');
test('an issued invoice with no terms is due the default terms after issue');
test('a draft keeps no due date');
test('a deleted issued invoice gets its due date');
test('a second run changes nothing');
```
