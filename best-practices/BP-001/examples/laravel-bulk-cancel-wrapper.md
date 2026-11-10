# A bulk cancel action that only repeats the single cancel

## Bindings

- `<<paths>>`: `app/Http/Controllers/**`, `app/Actions/**`
- `<<controller_paths>>`: `':(glob)app/Http/Controllers/**'`
- `<<domain_operation>>`: an Action class with one `execute()` method, in `app/Actions/<Area>/`
- `<<domain_operation_paths>>`: `':(glob)app/Actions/**'`
- `<<request_validation>>`: a FormRequest (`authorize()` and `rules()`)
- `<<transaction_fn>>`: `DB::transaction()`
- `<<write_signals>>`: `->(save|update|delete|forceDelete|restore|increment|decrement|attach|detach|sync[A-Za-z]*|notify|lockForUpdate)\(|::(create|insert|destroy|updateOrCreate|firstOrCreate)\(|DB::|transaction\(|event\(|Notification::|Mail::|Http::`
- `<<list_query_helpers>>`: none
- `<<bulk_endpoint_convention>>`: route `<resource>.bulk.<action>` handled by a `bulk<Action>()` controller method

## Sample

```php
// app/Actions/Orders/CancelOrdersAction.php (new)
class CancelOrdersAction
{
    public function __construct(private CancelOrderAction $cancelOrder) {}

    /**
     * @param  array<int, int>  $orderIds
     * @return Collection<int, Order>
     */
    public function execute(array $orderIds, string $reason): Collection
    {
        return Order::query()
            ->findMany($orderIds)
            ->map(fn (Order $order) => $this->cancelOrder->execute($order, $reason));
    }
}

// app/Http/Controllers/Api/OrderController.php (excerpt), behind the orders.bulk.cancel route
public function bulkCancel(BulkCancelOrdersRequest $request, CancelOrdersAction $cancelOrders): AnonymousResourceCollection
{
    $orders = $cancelOrders->execute($request->validated('order_ids'), $request->validated('reason'));

    return OrderResource::collection($orders);
}
```

## Expected fix shape

- `CancelOrdersAction` and its test are deleted; no other bulk or generic action replaces it.
- `bulkCancel` runs the existing `CancelOrderAction` once per validated order inside one `DB::transaction()`.
- `CancelOrderAction`, the route, `BulkCancelOrdersRequest` and the response stay the same.

```php
// app/Http/Controllers/Api/OrderController.php (excerpt)
public function bulkCancel(BulkCancelOrdersRequest $request, CancelOrderAction $cancelOrder): AnonymousResourceCollection
{
    $orders = DB::transaction(fn () => Order::query()
        ->findMany($request->validated('order_ids'))
        ->map(fn (Order $order) => $cancelOrder->execute($order, $request->validated('reason'))));

    return OrderResource::collection($orders);
}
```
