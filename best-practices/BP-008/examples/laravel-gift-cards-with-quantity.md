# Create-many gift cards that takes a quantity instead of the cards

## Bindings

- `<<paths>>`: `routes/api.php`, `app/Http/Controllers/Api/**`, `app/Http/Requests/**`, `resources/js/**`
- `<<route_files>>`: `routes/api.php`
- `<<request_validator>>`: the route's FormRequest and its `rules()`
- `<<response_type>>`: the controller method's return type: `GiftCardResource`, or a collection of it
- `<<list_test>>`: `array_is_list(`, `isList(`, `->getContent()`
- `<<bulk_route_convention>>`: `POST <resource>/bulk/<action>`, named `<resource>.bulk.<action>`, method `bulk<Action>`
- `<<record_fields>>`: the `gift_cards` table in `database/migrations/**`: `amount`, `currency`, `expires_on`,
  `recipient_email`
- `<<client_call>>`: `axios.post<T>(route('<name>'), …)` in `resources/js/**`

## Sample

```php
// routes/api.php (excerpt; the gift-cards.store route already exists)
Route::post('gift-cards/create-many', [GiftCardController::class, 'createMany'])->name('gift-cards.create-many');

// app/Http/Requests/StoreGiftCardRequest.php rules() (unchanged)
'amount'          => ['required', 'numeric', 'min:5', 'max:500'],
'currency'        => ['required', 'string', 'size:3'],
'expires_on'      => ['nullable', 'date', 'after:today'],
'recipient_email' => ['nullable', 'email'],

// app/Http/Requests/CreateManyGiftCardsRequest.php rules() (new)
'batch'          => ['required', 'array'],
'batch.amount'   => ['required', 'numeric', 'min:5', 'max:500'],
'batch.currency' => ['required', 'string', 'size:3'],
'batch.quantity' => ['required', 'integer', 'min:1', 'max:100'],

// app/Http/Controllers/Api/GiftCardController.php (new method)
public function createMany(CreateManyGiftCardsRequest $request): AnonymousResourceCollection
{
    $batch = $request->validated('batch');
    $cards = collect(range(1, $batch['quantity']))
        ->map(fn () => GiftCard::create(Arr::except($batch, 'quantity')));

    return GiftCardResource::collection($cards);
}
```

## Expected fix shape

- The route becomes `gift-cards/bulk/create`, named `gift-cards.bulk.create`, with a `bulkCreate` method and its own
  FormRequest.
- Its body is a list of whole gift cards under `gift_cards`, each taking exactly the fields `store` takes, with rules
  at least as strict; there is no `batch` key and no `quantity`.
- The issuing form expands its quantity into that many gift cards before it sends.
- `store` and its FormRequest are unchanged, and the bulk route returns a `GiftCardResource` collection in the order
  sent.

```php
// routes/api.php
Route::post('gift-cards/bulk/create', [GiftCardController::class, 'bulkCreate'])->name('gift-cards.bulk.create');

// app/Http/Requests/BulkCreateGiftCardsRequest.php rules()
'gift_cards'                   => ['required', 'array', 'min:1', 'max:100'],
'gift_cards.*.amount'          => ['required', 'numeric', 'min:5', 'max:500'],
'gift_cards.*.currency'        => ['required', 'string', 'size:3'],
'gift_cards.*.expires_on'      => ['nullable', 'date', 'after:today'],
'gift_cards.*.recipient_email' => ['nullable', 'email'],

// app/Http/Controllers/Api/GiftCardController.php
public function bulkCreate(BulkCreateGiftCardsRequest $request): AnonymousResourceCollection
{
    $cards = DB::transaction(fn () => array_map(
        fn (array $card) => GiftCard::create($card),
        $request->validated('gift_cards'),
    ));

    return GiftCardResource::collection($cards);
}

// resources/js/Pages/GiftCards/IssueForm.tsx: { gift_cards: Array.from({ length: quantity }, () => ({ amount, currency })) }
```
