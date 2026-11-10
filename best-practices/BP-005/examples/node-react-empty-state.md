# A third empty state, recorded as single-use because it reads the page's filters

## Bindings

- `<<paths>>`: `src/**`
- `<<shared_ui_dirs>>`: `src/components`, `src/hooks`
- `<<component_catalog>>`: Storybook: one story per component in `src/components/**/*.stories.tsx`
- `<<component_file_pattern>>`: `\.tsx?$`
- `<<component_definition_pattern>>`: `^\+export (default )?(function|const) ([A-Z]|use[A-Z])`
- `<<excluded_pattern>>`: `\.(test|spec|stories)\.tsx?$|/__tests__/|^src/api/generated/`
- `<<page_entry_points>>`: components a route mounts in `src/router.tsx`
- `<<design_doc>>`: the pull request description
- `<<follow_ups>>`: `## Follow-ups` in the pull request description

## Sample

```tsx
// src/features/orders/OrdersEmptyState.tsx (new)
import { InboxIcon } from 'lucide-react'
import { Button } from '@/components/Button'
import { useOrderFilters } from './useOrderFilters'

export function OrdersEmptyState() {
  const { filters, clear } = useOrderFilters()

  return (
    <div className="flex flex-col items-center gap-3 py-12 text-center">
      <InboxIcon className="size-10 text-muted" aria-hidden />
      <p className="text-sm text-muted">
        No orders match {filters.search ? `"${filters.search}"` : 'these filters'}.
      </p>
      <Button variant="secondary" onClick={clear}>Clear filters</Button>
    </div>
  )
}
```

```markdown
<!-- pull request description (excerpt) -->
## Component decisions

Search: read the Storybook stories under src/components

| Component or hook | Decision | Compared with | Similar one-offs | Reason | Person's answer |
|---|---|---|---|---|---|
| `OrdersEmptyState` | Single-use | `Card`, `Alert` | none | Reads the order filters through `useOrderFilters` | Approved |
```

The `useOrderFilters` hook already exists in `src/features/orders/useOrderFilters.ts`; the change doesn't add it.
`src/features/invoices/InvoiceTable.tsx:88` and `src/features/customers/CustomerList.tsx:64` render the same icon,
message and button markup inline.

## Expected fix shape

- The markup becomes a new generic `EmptyState` in `src/components`, with a story, declaring only the props the
  orders list passes (`message`, `actionLabel`, `onAction`).
- Reading `useOrderFilters` stays in the orders feature: the list passes its message and `clear` as props.
- The decision row lists both one-offs, and `## Follow-ups` lists them as migrations; neither file changes.

```tsx
// src/components/EmptyState.tsx (new)
type EmptyStateProps = { message: string; actionLabel: string; onAction: () => void }

export function EmptyState({ message, actionLabel, onAction }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center gap-3 py-12 text-center">
      <InboxIcon className="size-10 text-muted" aria-hidden />
      <p className="text-sm text-muted">{message}</p>
      <Button variant="secondary" onClick={onAction}>{actionLabel}</Button>
    </div>
  )
}

// src/components/EmptyState.stories.tsx (new)
export default { component: EmptyState }
export const NoMatches = { args: { message: 'No orders match these filters.', actionLabel: 'Clear filters', onAction: () => {} } }

// src/features/orders/OrderList.tsx (excerpt)
<EmptyState
  message={filters.search ? `No orders match "${filters.search}".` : 'No orders match these filters.'}
  actionLabel="Clear filters"
  onAction={clear}
/>
```

```markdown
<!-- pull request description (excerpt) -->
## Component decisions

Search: read the Storybook stories under src/components; `git grep -n -E 'InboxIcon|py-12 text-center' -- 'src/**'`

| Component or hook | Decision | Compared with | Similar one-offs | Reason | Person's answer |
|---|---|---|---|---|---|
| `EmptyState` | New generic | `Card`, `Alert` | `InvoiceTable.tsx:88`, `CustomerList.tsx:64` | | Approved |

## Follow-ups

- `src/features/invoices/InvoiceTable.tsx:88`: render the empty table through `EmptyState`. Same markup.
- `src/features/customers/CustomerList.tsx:64`: render the empty list through `EmptyState`. Same markup.
```
