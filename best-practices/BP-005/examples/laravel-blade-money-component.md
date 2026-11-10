# A new generic money component built for callers it doesn't have yet

## Bindings

- `<<paths>>`: `resources/views/**`, `app/View/Components/**`
- `<<shared_ui_dirs>>`: `resources/views/components`, `app/View/Components`
- `<<component_catalog>>`: none: the listing of `resources/views/components`
- `<<component_file_pattern>>`: `\.blade\.php$|^app/View/Components/.*\.php$`
- `<<component_definition_pattern>>`: none: each Blade component is its own file
- `<<excluded_pattern>>`: `^resources/views/vendor/`
- `<<page_entry_points>>`: views named by `view()` or `Route::view()` in `routes/` and `app/Http/Controllers`
- `<<design_doc>>`: `docs/changes/<change>.md`
- `<<follow_ups>>`: `## Follow-ups` in `docs/changes/<change>.md`

## Sample

```blade
{{-- resources/views/components/money.blade.php (new) --}}
@props(['amount', 'currency' => 'USD', 'locale' => null, 'precision' => 2, 'showSign' => false, 'zeroAs' => null])

@if ($amount === 0 && $zeroAs !== null)
    <span {{ $attributes }}>{{ $zeroAs }}</span>
@else
    <span {{ $attributes->class('tabular-nums') }}>{{ $showSign && $amount > 0 ? '+' : '' }}{{ Number::currency($amount / 100, in: $currency, locale: $locale, precision: $precision) }}</span>
@endif

{{-- resources/views/invoices/show.blade.php (new page, rendered by InvoiceController@show) --}}
<dd><x-money :amount="$invoice->total_cents" :currency="$invoice->currency" /></dd>

{{-- resources/views/orders/show.blade.php:41 (changed; was {{ number_format($order->total_cents / 100, 2) }}) --}}
<dd><x-money :amount="$order->total_cents" /></dd>
```

```markdown
<!-- docs/changes/invoice-page.md (excerpt) -->
## Component decisions

Search: listed resources/views/components; `git grep -n 'number_format(' -- 'resources/views/**'`

| Component or hook | Decision | Compared with | Similar one-offs | Reason | Person's answer |
|---|---|---|---|---|---|
| `x-money` | New generic | `x-badge`, `x-stat` | `orders/show.blade.php:41`, `orders/index.blade.php:18` | | Approved |
```

## Expected fix shape

- `x-money` stays a new generic component in `resources/views/components`, and declares only `amount` and
  `currency`, the props `invoices/show.blade.php` passes: no `locale`, `precision`, `showSign` or `zeroAs`.
- `orders/show.blade.php` is left as it was; it and `orders/index.blade.php:18` are listed under `## Follow-ups` as
  migrations to `x-money`.
- The decision row is unchanged; there is no catalog entry to add.

```blade
{{-- resources/views/components/money.blade.php (new) --}}
@props(['amount', 'currency'])

<span {{ $attributes->class('tabular-nums') }}>{{ Number::currency($amount / 100, in: $currency) }}</span>
```

```markdown
<!-- docs/changes/invoice-page.md (excerpt) -->
## Follow-ups

- `resources/views/orders/show.blade.php:41`: show the order total through `<x-money>`. Same cents-to-currency formatting.
- `resources/views/orders/index.blade.php:18`: show each order total through `<x-money>`. Same cents-to-currency formatting.
```
