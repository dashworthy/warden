# An order cancel guarded under a lock, whose jobs leave before commit and whose rejections are untested

## Bindings

- `<<paths>>`: `app/Enums/**`, `app/Models/**`, `app/Actions/**`, `app/Jobs/**`, `app/Http/Controllers/**`, `app/Http/Requests/**`
- `<<state_definitions>>`: `app/Enums/OrderStatus.php` (`Pending`, `Paid`, `Shipped`, `Cancelled`), cast on `Order::$status`
- `<<state_write_pattern>>`: `status.? =>|Status::[A-Za-z]+|_at.? =>|_until.? =>|->(delete|restore|forceDelete|associate)\(`
- `<<transition_map>>`: none
- `<<concurrency_guard>>`: `DB::transaction()` re-reading the row with `lockForUpdate()`
- `<<early_checks>>`: form request `authorize()` and `after()` hooks, route model binding
- `<<side_effect_calls>>`: `dispatch\(|::dispatch|Notification::|->notify\(|Mail::|event\(|Http::`
- `<<after_commit>>`: `->afterCommit()` on each job (the queue connection's `after_commit` option is `false`)

## Sample

```php
// app/Actions/Orders/CancelOrder.php
// The slice adds this action. States: Pending, Paid, Shipped, Cancelled; Order has no soft deletes and no other
// column that gates cancelling. Paths: OrderController::cancel is its only caller, and nothing else writes
// Cancelled. The existing MarkOrderPaid and ShipOrder already reject a Cancelled order under their own locks.
class CancelOrder
{
    public function handle(Order $order, string $reason): Order
    {
        return DB::transaction(function () use ($order, $reason) {
            $order = Order::query()->lockForUpdate()->findOrFail($order->id);

            if ($order->status !== OrderStatus::Pending) {
                throw OrderNotCancellable::from($order->status);
            }

            $order->update(['status' => OrderStatus::Cancelled, 'cancelled_at' => now(), 'cancel_reason' => $reason]);

            ReleaseReservedStock::dispatch($order);
            SendOrderCancelledEmail::dispatch($order);

            return $order;
        });
    }
}
```

```php
// tests/Feature/Orders/CancelOrderTest.php (added)
it('cancels a pending order and emails the customer', ...);
```

## Expected fix shape

- The lock and the `Pending`-only guard stay as they are: `Paid`, `Shipped` and `Cancelled` are rejected, and
  `OrderController::cancel` is the only path.
- Both jobs wait for the commit with `->afterCommit()`, so a rolled-back cancel releases no stock and sends no email,
  and a job never reads the order before the cancel is visible.
- Tests cover each rejected from-state (`Paid`, `Shipped`, `Cancelled`), asserting the status is unchanged and no
  job is pushed, and a cancel from a copy loaded before an earlier cancel, asserting it is rejected and one email job
  is pushed.

```php
$order->update(['status' => OrderStatus::Cancelled, 'cancelled_at' => now(), 'cancel_reason' => $reason]);

ReleaseReservedStock::dispatch($order)->afterCommit();
SendOrderCancelledEmail::dispatch($order)->afterCommit();
```

```php
it('cannot cancel an order that is not pending', function (OrderStatus $status) {
    Queue::fake();
    $order = Order::factory()->create(['status' => $status]);

    expect(fn () => app(CancelOrder::class)->handle($order, 'changed my mind'))->toThrow(OrderNotCancellable::class)
        ->and($order->fresh()->status)->toBe($status);
    Queue::assertNothingPushed();
})->with([OrderStatus::Paid, OrderStatus::Shipped, OrderStatus::Cancelled]);

it('rejects a cancel from a copy loaded before an earlier cancel, and emails once', function () {
    Queue::fake();
    $order = Order::factory()->create(['status' => OrderStatus::Pending]);
    $stale = Order::find($order->id);

    app(CancelOrder::class)->handle($order, 'changed my mind');

    expect(fn () => app(CancelOrder::class)->handle($stale, 'again'))->toThrow(OrderNotCancellable::class);
    Queue::assertPushed(SendOrderCancelledEmail::class, 1);
});
```
