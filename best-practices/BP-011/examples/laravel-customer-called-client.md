# A customer called a client on a new API endpoint

## Bindings

- `<<paths>>`: `app/**`, `resources/js/**`, `routes/**`, `lang/**`
- `<<vocabulary_sources>>`: `app/Models`, `lang/en`, `routes/api.php`, `docs/glossary.md`
- `<<design_doc>>`: `docs/decisions/<change>.md`
- `<<terms_section>>`: `## Terms`
- `<<declaration_pattern>>`: `(class|interface|enum|trait|function|const|type) [A-Za-z_]+|->name\('[^']+'\)|'[a-z_.]+' *=>|[a-z][A-Za-z]* *[?]? *:`
- `<<code_words>>`: Action, Controller, Data, Event, Factory, Job, Listener, Policy, Query, Request, Resource, Rule,
  Seeder, Test; `Props`, a leading `use`
- `<<generated_paths>>`: `resources/js/actions/**`

## Sample

```php
// routes/api.php (added)
Route::get('clients/{customer}/overdue-invoices', ClientOverdueInvoicesController::class)
    ->name('api.clients.overdue-invoices');

// app/Http/Controllers/Api/ClientOverdueInvoicesController.php (new)
class ClientOverdueInvoicesController
{
    public function __invoke(Customer $customer): AnonymousResourceCollection
    {
        return InvoiceResource::collection($customer->invoices()->overdue()->paginate());
    }
}

// app/Http/Resources/InvoiceResource.php (added key)
'client_name' => $this->customer->name,

// lang/en/invoices.php (added)
'client_overdue_title' => 'Overdue invoices for :client',
```

```markdown
<!-- Vocabulary at the base: app/Models has Customer and Invoice (with an overdue() scope), and lang/en/invoices.php
     labels "customer" and "overdue". "client" appears nowhere in app/Models, lang/en, routes/api.php or
     docs/glossary.md. docs/decisions/overdue-invoices-endpoint.md has no ## Terms section. -->
```

## Expected fix shape

- The route path, route name, controller, response key and translation key use "customer", the domain's word for
  the concept, in place of "client".
- No `## Terms` entry is added: "customer" is already the domain's word, so there is nothing new to define.
- What the endpoint does, and the rest of `InvoiceResource`, stay as they were.

```php
// routes/api.php (added)
Route::get('customers/{customer}/overdue-invoices', CustomerOverdueInvoicesController::class)
    ->name('api.customers.overdue-invoices');

// app/Http/Controllers/Api/CustomerOverdueInvoicesController.php (new)
class CustomerOverdueInvoicesController
{
    public function __invoke(Customer $customer): AnonymousResourceCollection
    {
        return InvoiceResource::collection($customer->invoices()->overdue()->paginate());
    }
}

// app/Http/Resources/InvoiceResource.php (added key)
'customer_name' => $this->customer->name,

// lang/en/invoices.php (added)
'customer_overdue_title' => 'Overdue invoices for :customer',
```
