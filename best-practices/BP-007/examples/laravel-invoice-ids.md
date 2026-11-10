# Invoice request whose string and nested rules accept deleted rows and raw status values

## Bindings

- `<<paths>>`: `app/Http/Requests/**`
- `<<id_param_pattern>>`: names ending `_id`, or `_ids` with rules on `_ids.*`
- `<<exists_rule>>`: `Rule::exists(<table>, <column>)`, or the string rule `exists:<table>,<column>`
- `<<exclude_deleted>>`: `->withoutTrashed()`
- `<<soft_delete_marker>>`: `use SoftDeletes;` on the model or a base model it extends
- `<<enum_cast>>`: the model's `casts()` mapping the column to a backed enum
- `<<enum_rule>>`: `Rule::enum(<Enum>::class)`, narrowed with `->only([...])` or `->except([...])`

## Sample

```php
// app/Http/Requests/StoreInvoiceRequest.php (new, excerpt)
public function rules(): array
{
    return [
        'customer_id'             => ['required', 'integer', 'exists:customers,id'],
        'currency_id'             => ['required', 'integer', Rule::exists('currencies', 'id')],
        // A new invoice starts as a draft or is sent straight away
        'status_id'               => ['required', 'integer', 'in:1,2'],
        'line_items'              => ['required', 'array', 'min:1'],
        'line_items.*.product_id' => ['required', 'integer', Rule::exists('products', 'id')],
        'line_items.*.quantity'   => ['required', 'integer', 'min:1'],
    ];
}

// app/Models/Customer.php, app/Models/Product.php: use SoftDeletes;
// app/Models/Currency.php: no SoftDeletes
// app/Models/Invoice.php casts(): 'status_id' => InvoiceStatus::class
// app/Enums/InvoiceStatus.php
enum InvoiceStatus: int { case Draft = 1; case Sent = 2; case Paid = 3; case Void = 4; }
```

## Expected fix shape

- `customer_id` and `line_items.*.product_id` use `Rule::exists(...)->withoutTrashed()`, because `Customer` and
  `Product` soft-delete; the string `exists:` rule is replaced, since it can't exclude deleted rows.
- `status_id` uses `Rule::enum(InvoiceStatus::class)` narrowed to `Draft` and `Sent`, not an `in:` list of raw values.
- `currency_id` keeps plain `Rule::exists()`: `Currency` doesn't soft-delete.
- Every other rule, and the parameters' types, stay the same.

```php
public function rules(): array
{
    return [
        'customer_id'             => ['required', 'integer', Rule::exists('customers', 'id')->withoutTrashed()],
        'currency_id'             => ['required', 'integer', Rule::exists('currencies', 'id')],
        'status_id'               => ['required', 'integer', Rule::enum(InvoiceStatus::class)->only([InvoiceStatus::Draft, InvoiceStatus::Sent])],
        'line_items'              => ['required', 'array', 'min:1'],
        'line_items.*.product_id' => ['required', 'integer', Rule::exists('products', 'id')->withoutTrashed()],
        'line_items.*.quantity'   => ['required', 'integer', 'min:1'],
    ];
}
```
