# React order summary with untranslated labels beside translated ones

## Bindings

- `<<paths>>`: `src/**/*.tsx`, `public/locales/**`
- `<<translate_fn>>`: `t()` from react-i18next's `useTranslation()`
- `<<translation_files>>`: `public/locales/en/*.json`
- `<<user_text_signals>>`: `(Error|Exception)\(|message:|toast\.|\b(title|label|placeholder|alt|aria-label)=|>[^<>{}]*[A-Za-z]{2,}[^<>{}]*<|\bt\(`
- `<<validation_defaults>>`: not bound (the UI has no form validation messages of its own)
- `<<validation_overrides>>`: not bound
- `<<design_record>>`: the PR description
- `<<resolve_key_cmd>>`: `jq -e '.<key path>' public/locales/en/<namespace>.json`
- `<<key_convention>>`: one namespace per feature, nested camelCase keys, plural forms as `_one` and `_other`

## Sample

```tsx
// src/orders/OrderSummary.tsx (excerpt)
export function OrderSummary({ order, onCancel }: OrderSummaryProps) {
  const { t } = useTranslation('orders');
  const count = order.lines.length;

  return (
    <section aria-label="Order summary">
      <h2>{t('summary.title')}</h2>
      <p>{'Order #' + order.number}</p>
      <p>{count} {count === 1 ? 'item' : 'items'}</p>
      <p>Total: {formatMoney(order.total)}</p>
      <button onClick={onCancel} disabled={order.status !== 'PENDING'}>
        Cancel order
      </button>
    </section>
  );
}
```

```json
// public/locales/en/orders.json (excerpt, before the change)
"summary": {
  "title": "Your order"
}
```

## Expected fix shape

- The accessible label, the order number line, the item count, the total line and the button label each come from
  `t()` with a key in `public/locales/en/orders.json`.
- The order number, the count and the formatted total are passed as named placeholders; the item count uses the
  `_one` and `_other` plural keys, not a ternary around literals.
- `summary.title`, the status check, `formatMoney` and the click handler are unchanged.
- The double braces in `orders.json` are i18next's interpolation syntax, not ward bindings.

```json
// public/locales/en/orders.json (excerpt)
"summary": {
  "label": "Order summary",
  "title": "Your order",
  "number": "Order #{{number}}",
  "itemCount_one": "{{count}} item",
  "itemCount_other": "{{count}} items",
  "total": "Total: {{total}}",
  "cancel": "Cancel order"
}
```

```tsx
// src/orders/OrderSummary.tsx (excerpt)
export function OrderSummary({ order, onCancel }: OrderSummaryProps) {
  const { t } = useTranslation('orders');

  return (
    <section aria-label={t('summary.label')}>
      <h2>{t('summary.title')}</h2>
      <p>{t('summary.number', { number: order.number })}</p>
      <p>{t('summary.itemCount', { count: order.lines.length })}</p>
      <p>{t('summary.total', { total: formatMoney(order.total) })}</p>
      <button onClick={onCancel} disabled={order.status !== 'PENDING'}>
        {t('summary.cancel')}
      </button>
    </section>
  );
}
```
