# Overdue-invoice mail written in English literals

## Bindings

- `<<paths>>`: `app/**`, `lang/**`, `resources/views/**`
- `<<translate_fn>>`: `__()`, and `trans_choice()` for counts
- `<<translation_files>>`: `lang/en/*.php`
- `<<user_text_signals>>`: `\$fail\(|withMessages\(|Exception\(|->(subject|line|greeting|action)\(|->with\('(status|success|error|message)'|function (messages|attributes)\(|\b(__|trans|trans_choice)\(`
- `<<validation_defaults>>`: `lang/<locale>/validation.php`
- `<<validation_overrides>>`: a FormRequest's `messages()` or `attributes()`, and `custom` or `attributes` entries in `lang/en/validation.php`
- `<<design_record>>`: the PR description
- `<<resolve_key_cmd>>`: `php artisan tinker --execute="echo __('<key>');"`
- `<<key_convention>>`: one file per domain area, with a nested group per message, such as `invoices.overdue.subject`

## Sample

```php
// app/Notifications/InvoiceOverdueNotification.php (excerpt)
public function toMail(object $notifiable): MailMessage
{
    $days = (int) $this->invoice->due_on->diffInDays(now());

    return (new MailMessage)
        ->subject('Invoice ' . $this->invoice->number . ' is overdue')
        ->greeting("Hello {$notifiable->name},")
        ->line("Your invoice is {$days} days past due.")
        ->action('Pay now', route('invoices.pay', $this->invoice));
}
```

## Expected fix shape

- The subject, greeting, line and action label each come from `__()` or `trans_choice()` with a key in
  `lang/en/invoices.php`.
- The invoice number, the customer's name and the day count are passed as named placeholders, not concatenated or
  interpolated; the day count uses plural forms.
- The route, the channels and the date calculation are unchanged.

```php
// lang/en/invoices.php (excerpt)
'overdue' => [
    'subject'  => 'Invoice :number is overdue',
    'greeting' => 'Hello :name,',
    'line'     => 'Your invoice is :count day past due.|Your invoice is :count days past due.',
    'action'   => 'Pay now',
],

// app/Notifications/InvoiceOverdueNotification.php (excerpt)
public function toMail(object $notifiable): MailMessage
{
    $days = (int) $this->invoice->due_on->diffInDays(now());

    return (new MailMessage)
        ->subject(__('invoices.overdue.subject', ['number' => $this->invoice->number]))
        ->greeting(__('invoices.overdue.greeting', ['name' => $notifiable->name]))
        ->line(trans_choice('invoices.overdue.line', $days))
        ->action(__('invoices.overdue.action'), route('invoices.pay', $this->invoice));
}
```
