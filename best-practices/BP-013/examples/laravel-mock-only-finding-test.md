# A review finding "proven" by a test that only checks a mock

## Bindings

- `<<paths>>`: `app/**`, `routes/**`, `resources/js/**`, `resources/views/**`, `tests/**`
- `<<test_paths>>`: `tests/**`
- `<<test_command>>`: `php artisan test --filter '<test name>'`
- `<<exempt_paths>>`: `database/migrations/**`, `config/**`, `resources/js/types/generated.d.ts`
- `<<task_list>>`: the PR description's Tasks checklist and Review table
- `<<test_first_record>>`: a `RED:` line under each task, quoting the failure message
- `<<behavior_spec>>`: the linked issue's acceptance criteria
- `<<assertion_pattern>>`: `expect\(|->assert|toBe|toEqual`
- `<<mock_assertion_pattern>>`: `shouldReceive|Mockery::|->expects\(`
- `<<ui_paths>>`: `resources/js/**`, `resources/views/**`
- `<<ui_test_paths>>`: `tests/Browser/**`
- `<<page_error_check>>`: `->assertNoJavaScriptErrors()` at the end of the test

## Sample

```php
// tests/Feature/Invoices/SendInvoiceRemindersTest.php (excerpt)
it('skips paid invoices', function () {
    Invoice::factory()->paid()->overdue()->create();

    $invoices = Mockery::mock(InvoiceRepository::class);
    $invoices->shouldReceive('overdueUnpaid')->once()->andReturn(collect());
    $this->app->instance(InvoiceRepository::class, $invoices);

    $this->artisan('invoices:send-reminders');
});
```

```markdown
<!-- PR description, Tasks (excerpt). The slice adds the invoices:send-reminders command. -->
- [x] 1. RED: add `it reminds the customer of an overdue invoice` to tests/Feature/Invoices/SendInvoiceRemindersTest.php.
  - RED: "Command "invoices:send-reminders" is not defined."
- [x] 2. GREEN: add the command and InvoiceRepository::overdueUnpaid().
- [x] 3. Review finding: paid invoices still get reminders. Fixed: overdueUnpaid() filters on status = open.
  - RED: `it skips paid invoices` failed: "Method overdueUnpaid() should be called exactly 1 times but called 0 times"
```

## Expected fix shape

- The finding's test runs the real command and the real `overdueUnpaid()` query against a paid and an open overdue
  invoice, and asserts what happens to each (the open one is reminded, the paid one isn't); no mock replaces the code
  that holds the behavior.
- Its RED line quotes a failure that shows the paid invoice being reminded, recorded before the fix to the query.
- Tasks 1 and 2 and the command itself stay as they are.

```markdown
- [x] 3. Review finding: paid invoices still get reminders.
  - RED: `it skips paid invoices` failed: "Failed asserting that 2026-11-10 09:00:00 is null."
  - GREEN: overdueUnpaid() filters on status = open. Fixed.
```

```php
it('skips paid invoices', function () {
    Notification::fake();
    $paid = Invoice::factory()->paid()->overdue()->create();
    $open = Invoice::factory()->overdue()->create();

    $this->artisan('invoices:send-reminders')->assertSuccessful();

    expect($paid->fresh()->last_reminded_at)->toBeNull()
        ->and($open->fresh()->last_reminded_at)->not->toBeNull();
    Notification::assertNotSentTo($paid->customer, InvoiceOverdueReminder::class);
});
```
