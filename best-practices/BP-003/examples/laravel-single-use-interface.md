# An interface with one implementation, bound in a file the plan doesn't list

## Bindings

- `<<scope_document>>`: `docs/plans/<change>.md`
- `<<planned_files>>`: the plan's "Files this change edits" table
- `<<follow_up_list>>`: the plan's `## Follow-ups` section
- `<<project_conventions>>`: an Action, a FormRequest, an API Resource and a Policy per use case
- `<<static_checks>>`: `vendor/bin/phpstan analyse` and `php artisan test --testsuite=Arch`
- `<<generated_outputs>>`: `composer.lock`
- `<<formatter>>`: `vendor/bin/pint --dirty`

## Sample

```php
// Scope (docs/plans/void-invoices.md): "A draft invoice can be voided; voiding sets its status and voided_at."
//   New files: app/Actions/VoidInvoice.php, app/Http/Controllers/Api/VoidInvoiceController.php,
//   app/Http/Requests/VoidInvoiceRequest.php, tests/Feature/Api/VoidInvoiceTest.php. Files this change edits: routes/api.php

// app/Contracts/VoidsInvoices.php (new)
interface VoidsInvoices
{
    public function handle(Invoice $invoice): Invoice;
}

// app/Actions/VoidInvoice.php (new)
class VoidInvoice implements VoidsInvoices
{
    public function handle(Invoice $invoice): Invoice
    {
        try {
            $invoice->update(['status' => InvoiceStatus::Void, 'voided_at' => now()]);
        } catch (QueryException $e) {
            throw $e;
        }

        return $invoice;
    }
}

// app/Providers/AppServiceProvider.php
     public function register(): void
     {
+        $this->app->bind(VoidsInvoices::class, VoidInvoice::class);
     }

// app/Http/Controllers/Api/VoidInvoiceController.php (new)
public function __invoke(VoidInvoiceRequest $request, Invoice $invoice, VoidsInvoices $voider): InvoiceResource
{
    return InvoiceResource::make($voider->handle($invoice));
}
```

## Expected fix shape

- `VoidsInvoices`, its only implementation's `implements`, and its binding are removed; the controller takes
  `VoidInvoice` directly, so `AppServiceProvider.php`, which the plan doesn't list, is left unchanged.
- The `try`/`catch` that only rethrows is removed.
- The Action, FormRequest, Resource and route stay: they are the project's conventions.
- Voiding still sets the status to void and stamps `voided_at`.

```php
// app/Actions/VoidInvoice.php
class VoidInvoice
{
    public function handle(Invoice $invoice): Invoice
    {
        $invoice->update(['status' => InvoiceStatus::Void, 'voided_at' => now()]);

        return $invoice;
    }
}

// app/Http/Controllers/Api/VoidInvoiceController.php
public function __invoke(VoidInvoiceRequest $request, Invoice $invoice, VoidInvoice $voidInvoice): InvoiceResource
{
    return InvoiceResource::make($voidInvoice->handle($invoice));
}
```
