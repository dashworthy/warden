# A new action's static analysis error added to the baseline

## Bindings

- `<<paths>>`: `tests/Arch/**`, `phpstan.neon`, `phpstan-baseline.neon`, `app/**`
- `<<architecture_rules>>`: `tests/Arch phpstan.neon`
- `<<exemption_mechanisms>>`: Pest `->ignoring([...])` in `tests/Arch/*.php`; `ignoreErrors` and `excludePaths` in
  `phpstan.neon`
- `<<baseline_files>>`: `phpstan-baseline.neon` (not marked shrink-only)
- `<<ignore_comment_pattern>>`: `@phpstan-ignore|@pest-arch-ignore`
- `<<design_doc>>`: the pull request description
- `<<exemption_approver>>`: the code owners of `tests/Arch/` and `phpstan.neon` in `.github/CODEOWNERS`

## Sample

```php
// app/Actions/Invoices/CustomerBalanceAction.php (new)
final class CustomerBalanceAction
{
    public function handle(Customer $customer): int
    {
        return Invoice::query()
            ->whereBelongsTo($customer)
            ->whereNull('paid_at')
            ->get()
            ->sum('total_cents');
    }
}
```

```diff
# phpstan-baseline.neon (regenerated with --generate-baseline)
 parameters:
 	ignoreErrors:
+		-
+			message: '#^Called ''sum'' on Laravel collection, but could have been retrieved as a query\.$#'
+			count: 1
+			path: app/Actions/Invoices/CustomerBalanceAction.php
```

```markdown
<!-- pull request description -->
Adds the customer balance action for the account page, and regenerates the PHPStan baseline so CI passes.
```

## Expected fix shape

- The baseline entry is gone: `phpstan-baseline.neon` is unchanged from the base.
- The action sums in the query, so static analysis passes on its own terms.
- The balance it returns stays the same.

```php
// app/Actions/Invoices/CustomerBalanceAction.php
final class CustomerBalanceAction
{
    public function handle(Customer $customer): int
    {
        return (int) Invoice::query()
            ->whereBelongsTo($customer)
            ->whereNull('paid_at')
            ->sum('total_cents');
    }
}
```
