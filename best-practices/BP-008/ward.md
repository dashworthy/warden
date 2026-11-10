---
version: 1
phases:
  - design
  - code
---

# BP-008: Give each endpoint one contract, shaped like the domain

**Description:** Each API route takes one request shape and returns one response shape, both made of the domain's
records. Creating or changing several records at once is its own route, handler and request validator, and a concept
that exists only in a form, such as a quantity of identical records, is expanded by the client before it sends.

**Rationale:** A route whose body can be one record or a list of them makes every caller guess which response it gets:
the handler returns a union, the validator branches its rules, a generated or hand-written client can't type the
response, and callers cast it. Each branch then needs its own tests, and its own exceptions everywhere the validator is
shared. A form concept in the API, such as a quantity, ties the contract to one screen: the next caller that wants
specific records, or a different grouping, needs the API changed again, while a contract of plain records serves them
all. A bulk route whose records take fewer fields, or looser rules, than the single route lets data in through the
side door that the single route would have rejected.

**Violations:**

```php
// Laravel
public function store(StoreOrderRequest $request): OrderResource|AnonymousResourceCollection
{
    if (array_is_list($request->all())) {
        return OrderResource::collection(array_map($this->createOrder(...), $request->validated()));
    }
    return new OrderResource($this->createOrder($request->validated()));
}
```

```ts
// Node (Express)
router.post('/orders', async (req, res: Response<OrderDto | OrderDto[]>) => {
  if (Array.isArray(req.body)) return res.json(await Promise.all(req.body.map(createOrder)));
  res.json(await createOrder(req.body));
});
```

One route takes a top-level list or one record and returns a union, so each caller types the response its own way.

**Compliant examples:**

```php
// Laravel: store() is unchanged; the several-record operation is its own route
Route::post('orders/bulk/create', [OrderController::class, 'bulkCreate'])->name('orders.bulk.create');
// BulkCreateOrdersRequest::rules(): a keyed list of exactly the records store() takes
'orders'               => ['required', 'array', 'min:1', 'max:100'],
'orders.*.customer_id' => ['required', 'integer', Rule::exists('customers', 'id')->withoutTrashed()],
```

```ts
// Node (Express + zod): POST /orders is unchanged
const bulkCreateOrdersSchema = z.object({ orders: z.array(createOrderSchema).min(1).max(100) });
router.post('/orders/bulk/create', async (req, res: Response<OrderDto[]>) => { /* ... */ });
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where API routes, their handlers and validators, and the client code that calls them live | Find the files that declare API routes (`<<route_files>>`), the handlers and validators they name, and any client code in the repository that calls them; write the narrowest globs covering them. Leave out routes that render pages or take HTML form posts. If the repository has no API routes, the ward doesn't apply. | `routes/api.php`, `app/Http/Controllers/Api/**`, `app/Http/Requests/**`, `resources/js/**` | `src/routes/**`, `src/**/*.controller.ts`, `src/**/*.schema.ts`, `src/**/dto/**`, `web/src/**` |
| `<<route_files>>` | The files that declare API routes | Read the routing setup (the router or module the app mounts) and list the files where API routes are declared. | `routes/api.php` | `src/routes/**` (Express), or the `@Controller` classes in `src/**/*.controller.ts` (NestJS) |
| `<<request_validator>>` | The unit that validates one route's request body | Open the handler of an existing write route and follow what validates its input. | the route's FormRequest and its `rules()` | the zod schema the route parses its body with, or the NestJS `@Body()` DTO class with class-validator decorators |
| `<<response_type>>` | Where a handler declares what it returns | Read an existing handler's signature and its return statement. | the controller method's return type: a `JsonResource`, or a collection of it | the handler's `Response<T>` (Express) or the method's `Promise<T>` (NestJS) |
| `<<list_test>>` | The calls that test whether a request body, or a value in it, is a list | Take the language's list test and any validator construct that accepts either of two shapes, and add any helper the repository uses for this (`git grep -n -i -e ismany -e islist`). | `array_is_list(`, `isList(`, `->getContent()` | `Array.isArray(`, `z.union([`, `.or(z.array(`, and `z.array(` as a route's whole body schema |
| `<<bulk_route_convention>>` | How a route that creates or changes several records is named | Look for existing bulk routes (`git grep -n -i -e bulk -e batch -- <route files>`) and copy their path, name and handler naming. If there are none, use the values here and say so. | `POST <resource>/bulk/<action>`, named `<resource>.bulk.<action>`, method `bulk<Action>` | `POST /<resource>/bulk/<action>`, handler `bulk<Action>`; an inline handler is judged by its path, not a handler name |
| `<<record_fields>>` | Where a record's fields and child relations are defined | Find the schema source of truth: migrations, an ORM schema file, or entity classes. | the model's table in `database/migrations/**`, and its relations on the model | the model's fields and relations in `prisma/schema.prisma` |
| `<<client_call>>` | How client code calls an API route with a typed response | Search the client code for calls to an existing API route by its path or name. Optional: if the repository has no client code, step 6 is skipped. | `axios.post<T>(route('<name>'), …)`, or the repository's generated API hooks, in `resources/js/**` | `api.post<T>('/<resource>/…', …)`, or the generated client, in `web/src/**` |

**Verification:**

1. List the API routes the change adds or changes, with their handlers, request validators and client callers. If none,
   the ward is N/A.
   `git diff --name-only <base>...HEAD -- ':(glob)<<paths>>'` (one `':(glob)…'` per glob), then read the route
   declarations the diff adds or changes in `<<route_files>>`.
2. Each handler behind those routes declares and returns one type in `<<response_type>>`: its signature names one
   response type (one type made nullable is still one), and it doesn't branch on the body's shape. Inspect each handler,
   and every hit of
   `git diff -U0 <base>...HEAD -- ':(glob)<<paths>>' | grep -E '^\+' | grep -F -e '<each <<list_test>> value>'`
3. Each `<<request_validator>>` validates one body shape: an object whose top-level keys are fields. A list of records
   sits under a key named for those records (the plural of the record's name, such as `invoices`), never as the
   top-level body or under an invented name (`batch`, `data`, or `items` when the records aren't items). No property, flag or override makes one
   validator accept two shapes.
4. Each field the change adds to a request is a column, attribute or child relation of the record the route creates or
   changes, as `<<record_fields>>` defines it, or an operation parameter the change's plan names (a value that
   controls how the operation runs, not what a record holds). A form-only concept is not: a quantity of identical
   records, a row or line grouping that no record has, a display order.
5. A route that creates or changes several records is its own route, named by `<<bulk_route_convention>>`, with its
   own handler and `<<request_validator>>`. Each record in it accepts exactly the single route's fields, with rules at
   least as strict: a rule may be tightened (required, distinct across the batch, a maximum batch size) but a field is
   never dropped, added or loosened. It returns a list of the single route's `<<response_type>>`, in the order sent.
   The single route is unchanged.
6. Each client call of these routes (`<<client_call>>`; `git grep -n '<route path or name>' -- ':(glob)<<paths>>'`)
   passes a response type matching the route's one response, and every caller of a route passes the same type.
7. In the `design` phase, check the plan instead of a diff: the plan gives each new or changed route one request shape
   and one response type, puts a several-record operation on its own bulk route with the single route's fields, keys
   lists of records, and leaves form-only concepts such as a quantity to the client.

- PASS when every route from step 1 has one request shape and one response type, lists of records are keyed by the
  records' name, every accepted field belongs to the domain record or the plan, several-record operations have their
  own bulk route whose records take the single route's fields with rules at least as strict and which returns a list
  of the single route's response, and every caller of a route types the same response.
- FAIL when a handler returns a union of shapes or branches on the body's shape; a validator takes a top-level list,
  two shapes, or a list under an invented key; the API accepts a form-only concept such as a quantity; a several-record
  operation shares the single route or doesn't follow `<<bulk_route_convention>>`; a bulk record drops, adds or loosens
  a field the single route takes, or the bulk route returns something other than a list of the single route's
  response; or callers type one route's response two ways.

**Applicability:** API routes in `<<paths>>` that the change adds or changes, their handlers and request validators,
and the client code that calls them; in the `design` phase, any route a plan adds or changes. Routes that render pages
or take HTML form posts are out of scope. Whether a change breaks an existing consumer is a separate question; this
ward decides how a new or changed contract is shaped, so a bulk operation is added as a new route instead of reshaping
one that consumers already call.
