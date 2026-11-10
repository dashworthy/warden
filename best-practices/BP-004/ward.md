---
version: 1
phases:
  - 'design'
  - 'code'
---

# BP-004: Prove API changes keep every consumer's requests working

**Description:** A change whose code reaches an API route proves, with tests run on the base and the head, that every
request its consumers already send still works, and records the routes, consumers and results in
<<api_impact_record>>.

**Rationale:** A change can be correct on its own and still break a request a consumer already sends: a new required
param, a renamed field, a changed type or status code, a dropped related record, a stricter rule or a smaller page.
Clients that ship on their own schedules (mobile apps, other teams' services, partners' integrations) can't be fixed
by changing a caller in this repository, so a break reaches users in the field and stays there until they update,
and a client that keeps synced data leaves any record an incremental sync missed stale on the device. Shared code
(filtering and sorting helpers, query scopes, base handlers, serializers, pagination) reaches dozens of routes from
one edit, which a reviewer reading the diff won't see. A test run on the base separates what this change broke from
what was already broken.

**Violations:**

```text
// Pseudocode. Change: "the new dispatch page always sends route_id, so the order list requires it"
validate GET /api/orders:
    route_id: required, integer, exists in routes

// Plan, API impact: "none, only the dispatch page uses this filter"
```

The mobile app's order sync calls the same list without `route_id`, so every sync is now rejected, and the plan never
looked for the route's consumers.

```text
// Pseudocode. The partner order endpoint's response
  order: id, status, lines
- order.shipments           (dropped to make the response smaller)
```

Dropping a related record removes it from the response, and from any filter or sort partners send through it, and
the change records no unverified risk for those external consumers.

**Compliant examples:**

```text
// Pseudocode. route_id filters when sent, and the existing request still works
validate GET /api/orders:
    route_id: optional, integer, exists in routes
```

```markdown
## API impact

| Route | Method, URI | Consumers | Reached by |
|---|---|---|---|
| `orders.index` | GET `/api/orders` | Mobile app, web | the order list's request validator |

**Consumers:** mobile app `OrdersApi` (`GET /api/orders`), called by the order sync with `updated_since` and no
`route_id`; web dispatch page `useOrders()`, with `route_id`.

| Test | Base | Head |
|---|---|---|
| `it lists orders without a route_id, as the mobile sync sends` | pass | pass |
| `it filters orders by route_id` | fail | pass (new behavior) |

**Already broken:** none. **Unverified risks:** none.
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where the API's route declarations, the code that serves them and the shared code they use live | Start from the files <<list_api_routes>> reads or prints, follow each route to its handler's folder, and add the folders of shared code those handlers import (models, schemas, queries, serializers, internal packages). Leave out folders only the repository's own pages use. | `routes/api.php`, `app/Http/**`, `app/Actions/**`, `app/Models/**`, `packages/**` | `src/**`, `prisma/schema.prisma` |
| `<<list_api_routes>>` | The command or search that lists every API route with its method, URI, name if any, and handler | Use the framework's route-list command if it has one; otherwise search the route registrations or route decorators. If the repository serves no API, the ward doesn't apply. | `php artisan route:list --json --path=api` | Express: `git grep -nE '\b(router\|app)\.(get\|post\|put\|patch\|delete)\(' src`; NestJS: `git grep -nE '@(Controller\|Get\|Post\|Put\|Patch\|Delete)\(' src` |
| `<<fan_out_code>>` | Optional. Shared code that reaches many routes from one edit | Find the base class or wrapper API handlers share, middleware applied to a whole API group, query scopes or ORM extensions, serializers reused across endpoints, and the filtering, sorting and pagination helpers; rank each by how many handlers use it (`git grep -l '<name>' \| wc -l`). Without it, each changed file is still walked up to its routes; the list only flags where one edit fans out. | `app/Http/Controllers/Api/ApiController.php`, global scopes in `app/Models/Scopes/**`, query macros in `AppServiceProvider`, the `api` middleware group | `src/common/**` (pipes, interceptors, the pagination helper), the Prisma client extensions in `src/prisma/prisma.service.ts` |
| `<<consumer_groups>>` | Each group of API routes, who calls it, and where their call sites can be searched, or that they can't be | Group routes by prefix or name from <<list_api_routes>>. Find clients in this repository's frontend (`git grep -nE "'/api/\|route\('"`) and any generated client, in the organization's other repositories (`gh search code --owner <org> '<uri path>'`), and in API docs or an OpenAPI file; ask the person which consumers are external. A group with no consumer found is treated as external. | `api/v1/*`: this repository's pages via `resources/js/api/**`, and the mobile app in `<org>/orders-mobile`; `api/partner/*`: external partners, unsearchable | `/v1/*`: the web app in `<org>/storefront-web` and the warehouse service in `<org>/warehouse`; `/partner/*`: external partners, unsearchable |
| `<<api_impact_record>>` | Where a change records the routes it reaches, their consumers, the tests and their base and head results; in the design phase, the same section of the plan | Read the plan template and the PR template for an "API impact" or "Compatibility" section. If neither has one, bind it to an `## API impact` section in the change's plan, or in the PR description when the repository writes no plans. | the plan's `## API impact` section | the design doc's `## API impact` section |
| `<<api_test_cmd>>` | How to run a test that sends a request through the real route (routing, middleware, validation, serialization) on any checkout | Read the test scripts in `composer.json` or `package.json` and find an existing test that makes an HTTP request (`git grep -lE 'getJson\|postJson\|supertest\|inject\('`). If the repository has none, ask the person how requests are tested; without a way to send a request through the route, the ward can't be met. | `php artisan test --filter=<Test>`, with `$this->getJson(...)` | `npx jest <file>`, with supertest against the bootstrapped app |
| `<<api_features>>` | The shared request features the API offers, each needing a probe when the change reaches the code that serves it: filters, sorts, related-record includes, pagination and its default page size, incremental sync, and the status invalid input gets | Read the shared filter, sort, include, pagination and validation code (start from <<fan_out_code>>), the API docs, and the config holding the default page size. Leave out features the API doesn't have. | `filter[...]`, `sort`, `include`; `per_page` defaulting to `config('api.per_page')`; `updated_since`; 422 for invalid input | `?status=`, `?sort=`; `?take=` and `?cursor=`, defaulting to `PAGE_SIZE` in `src/common/pagination.ts`; 400 for invalid input |
| `<<follow_up_list>>` | Where already-broken results are recorded instead of being fixed in the change | Look for a "Follow-ups" or "Out of scope" section in recent plans, or a tracker label (`gh label list \| grep -iE 'follow\|debt'`). If there is none, ask the person; the usual answer is a new issue in the project's tracker. | the plan's `## Follow-ups` section | an issue labelled `follow-up` |
| `<<human_review>>` | Optional. The question a person answers for each route whose consumers can't be searched | Keep the default question, naming the repository's external consumers if that helps. If <<consumer_groups>> has no external group, leave it out: the ward then needs no human review. | "For each route listed as an unverified risk, can its external consumers absorb the contract change recorded for it?" | "For each route listed as an unverified risk, can its external consumers absorb the contract change recorded for it?" |

**Verification:**

1. Find the routes the change reaches. List the changed files (`git diff --name-only <base>...HEAD`) and walk up from
   each to the handlers that use it (`git grep -ln '<name>'`), then to their routes (<<list_api_routes>>). A handler,
   request validator or serializer reaches its own routes; a shared action, query, model, schema, mixin or package
   reaches every handler that uses it; anything in <<fan_out_code>> reaches every route that uses it. If no route
   from <<list_api_routes>> is reached, the ward is N/A.
2. Confirm <<api_impact_record>> has a table listing every route from step 1: its name or handler, method and URI,
   consumer group, and the changed file that reaches it. A reached route missing from the table fails.
3. Confirm each route's consumers, from <<consumer_groups>>, are listed with the exact request each sends (params,
   page size, sync params) and its call site:
   - a consumer in this repository or another searchable one: its call sites, with file:line and the params each
     sends;
   - an external, unsearchable consumer: the route is listed under unverified risks with what changed in its contract
     (params, response shape, status codes), for <<human_review>>.
   A consumer the checker finds that the record doesn't list fails.
4. Confirm a test exists, run with <<api_test_cmd>>, that sends each consumer request from step 3 through the real
   route, with any write it depends on made through the application's own write code rather than by editing rows
   directly. Confirm a probe test also exists for each feature in <<api_features>> whose serving code the change
   reaches on that route: a filter and a sort through each related record the response returns, of every relation
   kind it returns (to-one, to-many, many-to-many, polymorphic); a sort through an optional relation, with records
   that lack it still returned; the page size actually returned against its configured default; an incremental sync
   after a write to a related record; and invalid input getting the API's validation status, never a server error.
   Each test is run on the base (for example in a `git worktree` of the base with the test file copied in) and on
   the head, and both results are recorded.
5. Classify each recorded result: base pass and head fail is a regression; fail on both is already broken; base fail
   and head pass is fixed by this change, and the record says whether that was intended. A changed status code for a
   state a consumer can reach by repeating its own request (a retry after a timeout, a double submit) is a regression
   even when recorded as new behavior, unless a probe proves that consumer's call site copes with the new status.
6. In the `design` phase, check the plan instead of a diff: its <<api_impact_record>> has the routes the planned
   change reaches, each route's consumers and their requests, the probe tests run on the base only, the
   already-broken results and the unverified risks.

- PASS when the record lists every reached route and consumer, every consumer request and relevant probe has a test
  with base and head results, no test is a regression, and every already-broken result is listed in
  <<follow_up_list>> rather than fixed in the change.
- FAIL when a reached route or consumer is missing, a consumer request has no test or lacks a base or head result,
  any test regresses, a contract change breaks a request a consumer sends, a status code changes for a state a
  consumer can reach by repeating a request with no probe proving that consumer copes, or a reached route with an
  external consumer isn't listed as an unverified risk.

**Applicability:** Changes whose diff reaches a route that <<list_api_routes>> lists, through any of the code in step
1, whoever its consumers are, including this repository's own frontend. Routes that only render this repository's
own pages (server-rendered views or the props a page is rendered with) are out of scope. A change that reaches no API
route needs only a one-line <<api_impact_record>> saying so and why.
