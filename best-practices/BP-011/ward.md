---
version: 1
phases:
  - design
  - code
---

# BP-011: Name new concepts with the domain's existing terms

**Description:** A name a change adds (a file, type, function, method, route, request or response field, component
prop or translation key) names its concept with the word the domain already uses for it, and never reuses a domain
word for something else. A concept the domain has no word for is defined in the <<terms_section>> of the change's
<<design_doc>>, and confirmed by the person who asked for the change, before code uses it.

**Rationale:** Names are how the next reader finds code and how an API's consumers read its contract. An invented
term ("lines" for the invoices a bulk form creates) sends readers looking for a concept that doesn't exist, and every
follow-up has to rename it: the endpoint, the classes behind it and the request body its consumers already send.
Reusing a word the domain already owns is worse: when "line" already means an invoice line (`invoice_line_id` in the
public API), a second meaning makes both harder to search, easy to confuse, and impossible for a consumer to tell
apart.

**Violations:**

```php
// Laravel: a bulk-create endpoint (new)
public function bulkStore(BulkStoreInvoicesRequest $request): AnonymousResourceCollection
{
    $invoices = CreateInvoicesForLinesAction::make()->execute($request->validated('lines'));
    // body: { "lines": [{ "customer_id": 41, "amount": 1200 }, ...] }
```

"Line" already means an invoice line, and here it names one invoice to create: one word, two concepts.

```tsx
// Node (React UI): a shipments panel (new)
export function DispatchList({ dispatches }: { dispatches: ShipmentResource[] }) {
```

"Dispatch" appears in no model, schema, translation or glossary; the domain calls these shipments.

**Compliant examples:**

```php
// Laravel
public function bulkStore(BulkStoreInvoicesRequest $request): AnonymousResourceCollection
// body: { "invoices": [{ "customer_id": 41, "amount": 1200 }, ...] }
```

```tsx
// Node (React UI)
export function ShipmentList({ shipments }: { shipments: ShipmentResource[] }) {
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where code that adds names lives: source, routes, UI and translation files | List the top-level folders (`git ls-files \| cut -d/ -f1 \| sort \| uniq -c`) and keep the ones holding application code, routes, UI, schema and translations; leave out vendored code, build output and docs | `app/**`, `resources/js/**`, `routes/**`, `lang/**` | `src/**`, `prisma/**`, `locales/**` |
| `<<vocabulary_sources>>` | The files that record the domain's words: models or schema, translations, the public API's routes or spec, and any glossary or product spec | Read the models folder or ORM schema, the default language's translation files, the API route files or OpenAPI spec, and any glossary or spec (`git ls-files \| grep -iE 'glossary\|spec\|openapi\|schema\|models'`). Required: when the repository has none of these, it records no vocabulary, so the person names the source or the ward doesn't apply | `app/Models`, `lang/en`, `routes/api.php`, `docs/glossary.md` | `prisma/schema.prisma`, `locales/en`, `openapi.yaml`, `docs/glossary.md` |
| `<<design_doc>>` | The document a change is planned in before code is written | Look for a design, RFC, ADR or proposal folder (`git ls-files \| grep -iE 'rfc\|adr\|design\|decision\|proposal'`). When the repository writes none, bind the glossary file from `<<vocabulary_sources>>` (create `docs/glossary.md` if there is none), so a new term is defined in the diff itself, and drop the `design` phase | `docs/decisions/<change>.md` | `docs/rfcs/<change>.md` |
| `<<terms_section>>` | The heading under which a design document defines a new term | Look in existing design documents for a Terms, Glossary or Definitions heading and use it; when none has one, use `## Terms` | `## Terms` | `## Terms` |
| `<<declaration_pattern>>` | A `grep -E` pattern that matches the names the repository's languages declare: types, functions, routes, request and response keys, schema models, props | Start from `(class\|interface\|enum\|function\|const\|type) [A-Za-z_]+` and add how the repository declares route names, request keys, schema models and props. Test it on a recent feature's diff: it should list that diff's new names | `(class\|interface\|enum\|trait\|function\|const\|type) [A-Za-z_]+\|->name\('[^']+'\)\|'[a-z_.]+' *=>\|[a-z][A-Za-z]* *[?]? *:` | `(class\|interface\|enum\|function\|const\|type\|model) [A-Za-z_]+\|@(Controller\|Get\|Post\|Put\|Patch\|Delete)\('[^']*'\)\|[a-z][A-Za-z]* *[?]? *:` |
| `<<code_words>>` | The words the repository's conventions put in names for the code's role rather than the business: layer suffixes and framework prefixes | List the endings repeated across file names (`git ls-files \| sed -E 's#.*/##; s/\..*//' \| grep -oE '[A-Z][a-z]+$' \| sort \| uniq -c \| sort -rn \| head -30`) and keep the ones that name a layer or a framework mechanic; add UI framework conventions such as a hook prefix | Action, Controller, Data, Event, Factory, Job, Listener, Policy, Query, Request, Resource, Rule, Seeder, Test; `Props`, a leading `use` | Controller, Dto, Entity, Guard, Interceptor, Module, Pipe, Repository, Resolver, Service, Spec; `Props`, a leading `use` |
| `<<generated_paths>>` | Optional. Generated code, whose names come from elsewhere | Read `.gitattributes` for `linguist-generated`, the build and codegen config, and look for "generated" header comments (`git grep -l -i 'auto-generated\|do not edit'`). Without it, nothing beyond tests is excluded | `resources/js/actions/**` | `src/generated/**` |

**Verification:**

1. List the names the change adds: new files, and new types, functions, methods, routes, request and response keys,
   props and translation keys. If there are none, the ward is N/A.
   `git diff --name-only --diff-filter=A <base>...HEAD -- <<paths>>`
   `git diff -U0 <base>...HEAD -- <<paths>> | grep -E '^\+' | grep -oE "<<declaration_pattern>>"`
2. Split each name into its words (`CreateInvoicesForLinesAction` → create, invoices, for, lines, action) and drop the
   words that describe the code rather than the business: CRUD and query verbs (create, store, update, delete,
   destroy, index, show, list, get, find), mechanics with no business meaning (bulk, many, item, payload, row, cache,
   id, data), UI event handlers named for the event they handle (`onClick`, `onClose`, `onSubmit`), and
   <<code_words>>.
3. For each remaining word, search the domain's vocabulary as it was before the change (`<base>`, or `HEAD` in the
   `design` phase) for the word, in lower case and capitalized, at the start of any word part (snake_case,
   kebab-case, camelCase or PascalCase), and read the matches:
   `git grep -nE '(^|[^A-Za-z])<word>|<Word>' <base> -- <<vocabulary_sources>>`
   - Found with the same meaning: the word is the domain's.
   - Found with a different meaning (`invoice_line_id` is looked up as an invoice line, not an invoice): the word is
     taken.
   - Found nowhere: the word is new. It is allowed only when the change's <<design_doc>> has a <<terms_section>>
     entry that defines it, says why no existing word fits, and records the answer of the person who asked for the
     change (who answered, and what).
4. In the `design` phase, check the plan instead of a diff: every name the plan introduces uses the domain's word for
   its concept, and a word the domain doesn't have is defined in a <<terms_section>> entry as step 3 says.

- PASS when every remaining word is the domain's, or new and defined in a <<terms_section>> entry with the requester's
  recorded answer.
- FAIL when a name uses a word that is taken for a different concept, a new word for a concept the domain already
  has a word for, or a new word with no <<terms_section>> entry or no recorded answer.

**Applicability:** Names a change adds under <<paths>>, in any language there. Existing names the change doesn't add
are out of scope, and renaming them is separate follow-up work. Test names, local variables inside one function, and
<<generated_paths>> are out of scope.
