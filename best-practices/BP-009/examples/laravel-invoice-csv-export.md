# An invoice CSV export that loads each invoice's customer and lines one at a time

## Bindings

- `<<paths>>`: `app/**`, `database/migrations/**`
- `<<loop_pattern>>`: `foreach *\(|for *\(|while *\(|->(map|each|filter|reduce|flatMap)\(|array_map\(`
- `<<query_calls>>`: Eloquent and `DB` reads (`find`, `findOrFail`, `first`, `get`, `exists`, `count`, `sum`), and a
  relation property read (`$invoice->customer`, `$invoice->lines`) that wasn't loaded with `with()`/`load()`
- `<<batch_load>>`: `with()`/`load()`, `withSum()`/`withCount()`, `whereIn(...)->get()->keyBy()`
- `<<group_recompute>>`: `App\Actions\Invoices\RecalculateInvoiceTotalsAction`, run by `InvoiceLineObserver::saved`
- `<<group_deferral>>`: `InvoiceLine::withoutEvents()` around the loop, then `RecalculateInvoiceTotalsAction` once per
  distinct invoice
- `<<query_count_assertion>>`: `$this->expectsDatabaseQueryCount(n)`

## Sample

```php
// app/Http/Controllers/InvoiceExportController.php (new)
class InvoiceExportController extends Controller
{
    public function __invoke(ExportInvoicesRequest $request): StreamedResponse
    {
        $invoices = Invoice::query()
            ->whereBetween('issued_on', [$request->date('from'), $request->date('to')])
            ->orderBy('number')
            ->get();

        return response()->streamDownload(function () use ($invoices) {
            $out = fopen('php://output', 'w');

            foreach ($invoices as $invoice) {
                fputcsv($out, [
                    $invoice->number,
                    $invoice->customer->name,
                    $invoice->lines->sum('amount_cents') / 100,
                ]);
            }

            fclose($out);
        }, 'invoices.csv');
    }
}
```

## Expected fix shape

- The customer and the line total are loaded with the invoices before the loop (eager loading and an aggregate on
  the invoice query), so the export runs a fixed number of queries however many invoices it writes.
- The loop reads no relation that wasn't loaded before it.
- The CSV's rows, columns and order stay the same.

```php
public function __invoke(ExportInvoicesRequest $request): StreamedResponse
{
    $invoices = Invoice::query()
        ->with('customer:id,name')
        ->withSum('lines', 'amount_cents')
        ->whereBetween('issued_on', [$request->date('from'), $request->date('to')])
        ->orderBy('number')
        ->get();

    return response()->streamDownload(function () use ($invoices) {
        $out = fopen('php://output', 'w');

        foreach ($invoices as $invoice) {
            fputcsv($out, [
                $invoice->number,
                $invoice->customer->name,
                ($invoice->lines_sum_amount_cents ?? 0) / 100,
            ]);
        }

        fclose($out);
    }, 'invoices.csv');
}
```
