---
version: 1
phases:
  - code
---

# BP-007: Validate ids against live rows, or against their enum

**Description:** A request parameter that holds an id is validated against what the id may really point at: when it
references a table that soft-deletes, its existence check excludes deleted rows; when its valid values are fixed in
code by an enum, it is validated against that enum instead of looked up in a table.

**Rationale:** An existence check that ignores the soft-delete marker accepts a deleted row: a customer, product or
route a user deleted can still be attached to a new record, which then points at something every list hides and every
lookup treats as missing, so later reads fail with "not found" or a server error on data that passed validation. For
an enum-backed id, a table lookup costs a query and follows the table rather than the code: a row added or removed by
hand changes what validation accepts, while the code maps the value to an enum that may not have that member, which
fails later as a server error instead of a validation error the caller can fix. An id with no check at all fails the
same way, later and further from the request.

**Violations:**

```php
// Laravel
'customer_id' => ['required', 'integer', Rule::exists('customers', 'id')],
'status_id'   => ['required', 'integer', Rule::exists('invoice_statuses', 'id')],
```

```ts
// Node (zod + Prisma)
customerId: z.number().int().refine(async (id) => (await prisma.customer.count({ where: { id } })) > 0),
statusId: z.number().int().refine(async (id) => (await prisma.invoiceStatus.count({ where: { id } })) > 0),
```

Customers soft-delete, so a deleted customer passes; the invoice maps `status_id` to an `InvoiceStatus` enum, so the
status is checked against the table instead of the enum the code uses.

**Compliant examples:**

```php
// Laravel
'customer_id' => ['required', 'integer', Rule::exists('customers', 'id')->withoutTrashed()],
'status_id'   => ['required', 'integer', Rule::enum(InvoiceStatus::class)],
```

```ts
// Node (zod + Prisma)
customerId: z.number().int().refine(async (id) => (await prisma.customer.count({ where: { id, deletedAt: null } })) > 0),
statusId: z.nativeEnum(InvoiceStatus),
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where request input is validated | Find the validation library's entry points (`git grep -ln 'extends FormRequest'`, `git grep -ln "from 'zod'"`, `git grep -ln "from 'class-validator'"`) and write the narrowest globs that cover the files that validate request bodies and query strings. If requests aren't validated in a declared place, the ward doesn't apply; say so. | `app/Http/Requests/**` | `src/**/*.schema.ts`, `src/**/dto/**` |
| `<<id_param_pattern>>` | How the repository names a parameter that holds an id, or a list of them | Read five existing validators and note the suffixes their id parameters use. | names ending `_id`, or `_ids` with rules on `_ids.*` | names ending `Id`, or `Ids` holding an array |
| `<<exists_rule>>` | The validation that checks a referenced row exists | Search the validators for how an existing `_id`/`Id` parameter is checked against its table. If the repository has none, use the stack's standard one shown here. | `Rule::exists(<table>, <column>)`, or the string rule `exists:<table>,<column>` | an async zod `.refine()` (parsed with `parseAsync`) that runs `prisma.<model>.count({ where: { id } })`, or a class-validator constraint that does the same |
| `<<exclude_deleted>>` | What limits `<<exists_rule>>` to rows that aren't soft-deleted | Read how the data layer hides deleted rows, and check whether `<<exists_rule>>` goes through that layer or queries the table directly. If a global filter already applies to the existence check, bind it here and note that `<<exists_rule>>` satisfies it as written. | `->withoutTrashed()` (the rule queries the table directly, so the model's soft-delete scope doesn't apply) | `deletedAt: null` in the existence check's `where` |
| `<<soft_delete_marker>>` | What marks a table as soft-deleting | Search the models or schema for a deleted-at column and the trait, base class or extension that hides those rows; check base classes too. If nothing soft-deletes, every existence check needs only `<<exists_rule>>`. | `use SoftDeletes;` on the model or a base model it extends | a `deletedAt DateTime?` field on the model in `prisma/schema.prisma` |
| `<<enum_cast>>` | Where code declares that a column holds a member of an enum | Search the models or domain types for columns mapped to an enum type. If none are, no id is enum-backed. | the model's `casts()` mapping the column to a backed enum (`'status_id' => InvoiceStatus::class`) | a Prisma `enum` field type, or a domain type that maps the field to a TypeScript `enum` (`statusId: InvoiceStatus`) |
| `<<enum_rule>>` | The validation that accepts only an enum's members, and how it is narrowed | Search the validators for an existing enum check; otherwise use the stack's standard one shown here. | `Rule::enum(<Enum>::class)`, narrowed with `->only([...])` or `->except([...])` | `z.nativeEnum(<Enum>)` (narrowed with `z.union([z.literal(<Enum>.A), z.literal(<Enum>.B)])`), or `@IsEnum(<Enum>)` |

**Verification:**

1. List the request validators the change adds or changes. If none, the ward is N/A.
   `git diff --name-only <base>...HEAD -- ':(glob)<<paths>>'` (one `':(glob)…'` per glob)
2. In each, list the parameters the change adds or changes that hold an id: names matching `<<id_param_pattern>>`,
   and any other parameter whose value is written to a foreign key column or to a column mapped to an enum.
3. For each parameter, find what it references:
   - Enum-backed when the target record maps the column to an enum (`<<enum_cast>>`; grep the model or type for the
     column), or an enum in code names the referenced table and declares a member for each of its ids. An enum that
     `<<enum_rule>>` can't read, such as a class or object of plain constants with no enum members, doesn't count:
     treat its table as an ordinary one.
   - Soft-deleting when the referenced table's model has `<<soft_delete_marker>>` (grep the model and the classes or
     extensions it inherits from).
4. Check the rule:
   - an enum-backed id uses `<<enum_rule>>`, narrowed as the binding shows when only some members are allowed, and
     not `<<exists_rule>>` or a hand-written list of raw literal values (`3`, `'paid'`) in place of enum members;
   - any other id on a soft-deleting table uses `<<exists_rule>>` with `<<exclude_deleted>>`;
   - an id on a table that doesn't soft-delete uses `<<exists_rule>>`;
   - for a list of ids, `<<exists_rule>>` requires every distinct id to exist: the count of live matches equals the
     number of distinct ids.

- PASS when every parameter from step 2 uses the rule step 4 gives for what it references.
- FAIL when an id has no existence or enum check; an id on a soft-deleting table uses `<<exists_rule>>` without
  `<<exclude_deleted>>`; a list of ids passes when only some of its distinct ids exist; an enum-backed id uses
  `<<exists_rule>>` or a hand-written list of raw literal values instead of `<<enum_rule>>`; or `<<enum_rule>>` names an
  enum with no members.

**Applicability:** Request validators in `<<paths>>` that the change adds or changes, for the parameters it adds or
changes, including ids nested in lists of records. A parameter meant to reference a deleted row, such as the id on a
restore endpoint, uses an existence check limited to deleted rows, or `<<exists_rule>>` alone, and says why in a
comment. Ids in the URL path that the router resolves to a record are out of scope, as are rules the change doesn't
touch.
