# An accounting API secret read with env() in a service and put in an exception

## Bindings

- `<<paths>>`: `app/**`, `config/**`, `database/**`, `tests/**`, `.env.example`
- `<<schema_paths>>`: `database/migrations`
- `<<config_module>>`: `config/*.php`, read elsewhere with `config()`
- `<<env_read>>`: `env\(`
- `<<env_example>>`: `.env.example`
- `<<secret_store>>`: AWS Secrets Manager, loaded into the environment at deploy
- `<<secret_listing>>`: a "New environment variables" section in the change's design document or PR body
- `<<encrypted_field>>`: the `encrypted` cast (or `encrypted:array`, `encrypted:collection`, `AsEncryptedArrayObject`)
  on a `text` column
- `<<output_exclusion>>`: `$hidden` on the model
- `<<token_hash>>`: `hash('sha256', $token)` with `hash_equals()`, or `Hash::make()` with `Hash::check()`
- `<<response_layer>>`: API Resources, Inertia props, `response()->json()`
- `<<log_calls>>`: `Log::`, `logger()`, `report()`, activity log properties
- `<<env_guard>>`: none
- `<<human_review>>`: Has each new secret this change lists been added to the secret store for every environment
  that runs it?

## Sample

```php
// app/Services/Accounting/LedgerClient.php (new)
class LedgerClient
{
    public function pushInvoice(Invoice $invoice): void
    {
        $secret = env('LEDGER_API_SECRET');

        $response = Http::withToken($secret)
            ->post('https://api.ledger.example/v2/invoices', [
                'number' => $invoice->number,
                'total'  => $invoice->total,
            ]);

        if ($response->failed()) {
            throw new RuntimeException(
                "Ledger rejected invoice {$invoice->number} using key {$secret}: {$response->body()}"
            );
        }
    }
}
```

```markdown
<!-- .env.example and config/ are unchanged, and the PR body has no "New environment variables" section. -->
```

## Expected fix shape

- `config/services.php` reads `LEDGER_API_SECRET` with `env()` and no default, and `LedgerClient` reads it with
  `config()`; no `env()` call is left outside `config/`.
- `.env.example` gets `LEDGER_API_SECRET=` with no value, and the PR body lists the variable for the secret store.
- The exception message names the invoice and the HTTP status, not the secret.
- The request the client sends is unchanged.

```php
// config/services.php (added)
'ledger' => ['secret' => env('LEDGER_API_SECRET')],

// .env.example (added)
LEDGER_API_SECRET=

// app/Services/Accounting/LedgerClient.php
$response = Http::withToken(config('services.ledger.secret'))
    ->post('https://api.ledger.example/v2/invoices', [
        'number' => $invoice->number,
        'total'  => $invoice->total,
    ]);

if ($response->failed()) {
    throw new RuntimeException("Ledger rejected invoice {$invoice->number} with HTTP {$response->status()}");
}
```

```markdown
<!-- PR body (added section) -->
## New environment variables

- `LEDGER_API_SECRET`: the ledger's API secret, needed in every environment that pushes invoices.
```
