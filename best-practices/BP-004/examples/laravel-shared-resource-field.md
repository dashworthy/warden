# A shared resource's field reformatted for one page

## Bindings

- `<<paths>>`: `routes/api.php`, `app/Http/**`, `app/Models/**`
- `<<list_api_routes>>`: `php artisan route:list --json --path=api`
- `<<fan_out_code>>`: `app/Http/Controllers/Api/ApiController.php`, the `api` middleware group
- `<<consumer_groups>>`: `api/v1/*`: this repository's pages via `resources/js/api/**`, and the Android app in
  `acme/billing-android` (`gh search code --owner acme`); `api/partner/*`: external partners, unsearchable
- `<<api_impact_record>>`: the plan's `## API impact` section
- `<<api_test_cmd>>`: `php artisan test --filter=<Test>`, with `$this->getJson(...)`
- `<<api_features>>`: `filter[...]`, `sort`; `per_page` defaulting to `config('api.per_page')`; 422 for invalid input
- `<<follow_up_list>>`: the plan's `## Follow-ups` section
- `<<human_review>>`: "For each route listed as an unverified risk, can its external consumers absorb the contract
  change recorded for it?"

## Sample

```diff
// app/Http/Resources/InvoiceResource.php (returned by InvoiceController@index and @show)
// Change: "the invoice page shows the amount with its currency"
     return [
         'id'     => $this->id,
         'number' => $this->number,
-        'amount' => $this->amount_cents,
+        'amount' => Number::currency($this->amount_cents / 100, $this->currency),
         'status' => $this->status,
     ];
```

```markdown
## API impact

| Route | Method, URI | Consumers | Reached by |
|---|---|---|---|
| `api.v1.invoices.show` | GET `/api/v1/invoices/{invoice}` | Web | `InvoiceResource` |

| Test | Base | Head |
|---|---|---|
| `InvoiceShowTest::it shows the amount with its currency` | fail | pass (new behavior) |

**Already broken:** none. **Unverified risks:** none.
```

## Expected fix shape

- `amount` stays an integer number of cents for every consumer; the formatted value is a new field the page reads.
- The record lists both routes that return `InvoiceResource`, `api.v1.invoices.index` and `api.v1.invoices.show`.
- The Android app's request (the list, with `updated_since` and no `per_page`) is listed with its call site, and it
  and the show request have tests that `amount` is still an integer, with base and head results; none regresses.

```php
// app/Http/Resources/InvoiceResource.php
'amount'           => $this->amount_cents,
'amount_formatted' => Number::currency($this->amount_cents / 100, $this->currency),
```

```markdown
## API impact

| Route | Method, URI | Consumers | Reached by |
|---|---|---|---|
| `api.v1.invoices.index` | GET `/api/v1/invoices` | Web, Android | `InvoiceResource` |
| `api.v1.invoices.show` | GET `/api/v1/invoices/{invoice}` | Web | `InvoiceResource` |

**Consumers:** web `resources/js/api/invoices.ts:12` (`GET /api/v1/invoices/{id}`); Android `InvoiceApi.kt:18`
(`GET /api/v1/invoices`), called by the invoice sync with `updated_since` and no `per_page`, reading `amount` as a Long.

| Test | Base | Head |
|---|---|---|
| `InvoiceIndexTest::it returns amount in cents to the Android sync request` | pass | pass |
| `InvoiceShowTest::it returns amount in cents` | pass | pass |
| `InvoiceShowTest::it returns amount_formatted with its currency` | fail | pass (new behavior) |

**Already broken:** none. **Unverified risks:** none.
```
