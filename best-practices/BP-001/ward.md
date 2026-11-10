---
version: 1
phases:
  - 'code'
---

# BP-001: Keep business logic out of controllers

**Description:** A controller turns an HTTP request into one call into the domain (one `<<domain_operation>>`, or
one background job) and turns the result into a response. Writes, transactions, locks, state transitions, guard
rules, domain calculations, external calls and notifications belong in `<<domain_operation>>`, never in the
controller. The one exception is a bulk endpoint, which runs the existing per-item `<<domain_operation>>` once per
item inside one transaction, since doing several at once is an HTTP concern and not a new business process.

**Rationale:** Logic in a controller runs only over HTTP, so a background job, a CLI command, another API surface or
another domain operation can't reuse it, and the same rule ends up copied, with drift, into every controller that
serves the same record (web pages, public API, mobile API). It also sits outside the transaction the domain layer
runs in: a controller that saves a record and then syncs its roles can fail half-way and leave the first write
behind. Tests then have to drive HTTP to reach a rule that could have been tested directly. A bulk or generic domain
operation written only to repeat an existing one over a list adds a second home for the same process; the loop
belongs in the bulk endpoint, and the process stays in one operation.

**Violations:**

```php
// Laravel: app/Http/Controllers/UserController.php (excerpt)
public function update(UpdateUserRequest $request, User $user): UserResource
{
    $user->name  = $request->validated('name');
    $user->email = $request->validated('email');
    $user->save();
    $user->roles()->sync($request->validated('role_ids'));

    return UserResource::make($user);
}
```

The controller writes the record and its roles itself, outside any transaction, instead of calling one operation.

```ts
// Node (NestJS + Prisma): src/addresses/addresses.controller.ts (excerpt)
@Patch(':id')
async update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateAddressDto) {
  const address = await this.prisma.$transaction(async (tx) => {
    const current = await tx.address.findUniqueOrThrow({ where: { id } });
    if (current.status === 'NEEDS_REVIEW' && dto.status === 'ACTIVE') {
      return this.addresses.approve(tx, current, dto);
    }
    return this.addresses.save(tx, current, dto);
  });
  return AddressResponse.from(address);
}
```

The controller opens a transaction and decides the address's status transition, choosing between two operations.

**Compliant examples:**

```php
// Laravel
public function update(UpdateUserRequest $request, User $user, SaveUserAction $saveUser): UserResource
{
    return UserResource::make($saveUser->execute($user, $request->validated()));
}
```

```ts
// Node (NestJS)
@Patch(':id')
async update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateAddressDto) {
  return AddressResponse.from(await this.addresses.update(id, dto));
}
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where the governed code lives: every glob in `<<controller_paths>>` and `<<domain_operation_paths>>` | Combine the two bindings below. | `app/Http/Controllers/**`, `app/Actions/**` | `src/**/*.controller.ts`, `src/**/*.service.ts` |
| `<<controller_paths>>` | The controllers and route handlers, written as git pathspecs | Read how routes are registered and note where their handlers live: Laravel `routes/*.php`; NestJS `git grep -l '@Controller('`; Express `git grep -lE 'Router\(\)\|app\.(get\|post\|put\|patch\|delete)\('`. Take the narrowest globs covering those files. No HTTP handlers: the ward doesn't apply. | `':(glob)app/Http/Controllers/**'` | `':(glob)src/**/*.controller.ts'` (NestJS) or `':(glob)src/routes/**'` (Express) |
| `<<domain_operation>>` | The unit that holds one business process and that a controller calls | Open three controllers that save data and follow the call they make. Look for `class \w+Action`, `@Injectable()` services, or folders named `Actions`, `Services`, `UseCases`, `Commands`, `Handlers`. If controllers write directly everywhere and no such layer exists, the person names the layer the ward should require; without one the ward is not applicable. | An Action class with one `execute()` method | A method on the module's `@Injectable()` service (NestJS), or a use-case function in `src/services/` (Express) |
| `<<domain_operation_paths>>` | Where `<<domain_operation>>` code lives, written as git pathspecs | The folders found for `<<domain_operation>>`. | `':(glob)app/Actions/**'` | `':(glob)src/**/*.service.ts'` |
| `<<request_validation>>` | Where a request's authorization and input validation are declared, before the controller body runs | Look at what existing controller methods take as their request parameter, and at middleware, guards and pipes registered on routes. | A FormRequest (`authorize()` and `rules()`) | A DTO validated by `ValidationPipe`, plus guards (NestJS); a schema-validation middleware such as zod (Express) |
| `<<transaction_fn>>` | How the project opens a database transaction | `git grep -nE 'transaction\('` in the domain layer; read the ORM in `composer.json` or `package.json`. | `DB::transaction()` | `prisma.$transaction()` |
| `<<write_signals>>` | An extended regex matching the calls that write data, open transactions or locks, or fire events, mail, notifications or HTTP calls | Start from this table's value for the stack, then add the project's own ORM write and lock calls, event bus, mailer, notifier and HTTP client (read the dependencies in `composer.json` or `package.json`). | `->(save\|update\|delete\|forceDelete\|restore\|increment\|decrement\|attach\|detach\|sync[A-Za-z]*\|notify\|lockForUpdate)\(\|::(create\|insert\|destroy\|updateOrCreate\|firstOrCreate)\(\|DB::\|transaction\(\|event\(\|Notification::\|Mail::\|Http::` | `\.(create\|createMany\|update\|updateMany\|upsert\|delete\|deleteMany)\(\|\$transaction\|\$executeRaw\|FOR UPDATE\|\.emit\(\|mailer\.\|fetch\(\|axios\.` |
| `<<list_query_helpers>>` | Optional. Shared helpers that apply a list request's filters, sort and paging | Look at existing index or list endpoints for a helper they all call (`git grep -nE 'allowedFilters\|paginate\|applyFilters'`). Without it, a list read may apply only filters, sort and paging copied unchanged from validated input. | `QueryBuilder::for(...)->allowedFilters(...)` from spatie/laravel-query-builder, or `->paginate()` | A shared `paginate(query, dto)` helper, if the project has one |
| `<<bulk_endpoint_convention>>` | Optional. How the project names a bulk endpoint | Look for routes or methods named `bulk*` or taking an array of items. Without it, a bulk endpoint is any handler whose validated input is a list of items for one existing per-item `<<domain_operation>>`. | Route `<resource>.bulk.<action>` handled by a `bulk<Action>()` method | `POST /<resource>/bulk-<action>` handled by a `bulk<Action>()` method |

**Verification:**

1. List the controllers and the new domain operations the slice touches. If both lists are empty, the ward is N/A.
   `git diff --name-only <base>...HEAD -- <<controller_paths>>` and
   `git ls-files --others --exclude-standard -- <<controller_paths>>`;
   `git diff --name-only --diff-filter=A <base>...HEAD -- <<domain_operation_paths>>` and
   `git ls-files --others --exclude-standard -- <<domain_operation_paths>>`.
2. For each controller, list the added lines that carry the usual signals of business logic (for an untracked file,
   grep the whole file):
   `git diff -U0 <base>...HEAD -- <file> | grep -E '^\+' | grep -E -- '<<write_signals>>'`
   Each hit is business logic unless step 3 shows it is one of the allowed statements.
3. Read every controller method the slice adds or changes, and sort each statement the slice adds into one of the two
   lists below.

   Allowed in a controller:
   - receiving the request through `<<request_validation>>` (authorization and validation live there), and records
     the framework resolves from route parameters;
   - turning validated input into the arguments of the one domain call (a data object, or plain values);
   - one call into the domain per request: one `<<domain_operation>>`, or dispatching one background job as the
     method's only operation;
   - simple reads: loading the record a route parameter names or failing with not found, and list reads made only of
     eager loading plus `<<list_query_helpers>>`. Any other condition, aggregate or computed value is a domain query;
   - shaping the response: serializers or resources, view rendering, redirects, status codes, eager loading what the
     response returns, and private helpers that do only these;
   - in a bulk endpoint (`<<bulk_endpoint_convention>>`): one `<<transaction_fn>>` that runs the existing per-item
     `<<domain_operation>>` once per validated item. Lookups the items share may be loaded before the loop, and where
     the per-item operation lets its per-set work be deferred, that work runs once per affected set after the loop,
     through the existing operation that does it.

   Business logic:
   - writing persisted state: create, update, delete, upsert, relation sync, attach or detach, increment, or a
     query-level update;
   - opening a transaction or taking a lock, except the bulk endpoint's one `<<transaction_fn>>` above;
   - branching on record state or input to decide what happens to the data: status transitions, guard checks that
     throw, choosing which operation runs;
   - more than one `<<domain_operation>>`, or one plus another write, for one request, except the bulk endpoint's
     per-item operation and its deferred per-set work above;
   - anywhere in the slice, a new `<<domain_operation>>` whose body only iterates its input and calls an existing
     `<<domain_operation>>` once per item, adding no rule of its own;
   - computing domain values (statuses, dates, totals, prices, sequence numbers) or calling an external service as
     part of the operation;
   - sending notifications or mail, or firing domain events.

- PASS when every statement the slice adds to a controller is on the allowed list, and no new domain operation only
  repeats an existing one over a list.
- FAIL when the slice adds business logic to a controller: a new statement, branch, write, transaction or second
  domain call from the business-logic list, or a new domain operation that only repeats an existing one over a list.
  Logic that was already there before the slice isn't this slice's violation: editing an existing line without adding
  behaviour passes, and the checker notes the method as a follow-up.

**Applicability:** Every controller or route handler under `<<controller_paths>>` that the slice adds or changes,
for every surface alike (web pages, public API, mobile API, webhooks). Session and login handling in authentication
controllers (checking credentials, regenerating the session, logging out) is HTTP work, not business logic. Request
validators, serializers, read-only domain queries and jobs are out of scope, and domain operations are in scope only
for a new one that repeats an existing one over a list.
