---
version: 1
phases:
  - 'code'
---

# BP-002: Translate user-facing text

**Description:** Text that code shows to a user is written as a key in `<<translation_files>>` and resolved with
`<<translate_fn>>`, never as a string literal, so the application can be offered in another language without hunting
through code for the source language. Validation messages are the exception: they use the validation library's own
translated messages (`<<validation_defaults>>`), and are customized only where a user would otherwise see wording that
fails them.

**Rationale:** Every literal is text a translator can't reach: a second locale would mean finding and rewriting each
one in code, and any one that's missed shows the source language to a user who chose another. Text built by
concatenation (`'Product not found: ' + sku`) can't be translated even once found, because word order differs
between languages. A validation library that ships a translated message for every built-in rule needs no code to make
those messages translatable; per-request message and attribute overrides only add copies of labels the translation
files already hold, and an override written for one field leaves its sibling fields with different wording. A
translator called from inside a translation file resolves in whatever locale is active when that file first loads.

**Violations:**

```php
// Laravel: app/Rules/CountryCode.php (excerpt)
if (! in_array($value, ['US', 'CA'], true)) {
    $fail('The :attribute must be US or CA.');
}
```

A custom validation rule's message is a literal instead of a key the validator translates.

```ts
// Node: src/imports/order-import.ts (excerpt), the error is written to the file the user downloads
if (!product) {
  throw new ImportRowError('Product not found: ' + row.sku);
}
```

A user-facing error is a literal, and concatenation fixes its word order.

```php
// Laravel: lang/en/validation.php (excerpt)
return [
    'attributes' => ['lines.*.product_id' => __('products.product')],
    'custom'     => ['lines.*.product_id' => ['required' => 'Choose a product for the line.']],
];
```

A translation file that calls the translator while it loads, to relabel a field no user was shown to need, with a
custom message for one field of the request only.

**Compliant examples:**

```php
// Laravel: the rule fails with a key, and lang/en/validation.php holds the plain sentence
$fail('validation.country_us_or_ca')->translate();
// lang/en/validation.php: 'country_us_or_ca' => 'The :attribute must be US or CA.',
```

```ts
// Node: the sentence lives under imports.productNotFound, with a named sku placeholder
throw new ImportRowError(t('imports.productNotFound', { sku: row.sku }));
```

```php
// Laravel: the request declares rules only, so a missing product gets the default translated "required" message
'lines.*.product_id' => ['required', 'integer', Rule::exists('products', 'id')],
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Code that shows text to users, and the translation files | The folders holding server code, templates and UI components that already call `<<translate_fn>>` (`git grep -l '<translate_fn>('`), plus `<<translation_files>>`. A part of the codebase with no translation mechanism (for example a UI that has never been internationalized) is left out. No translation mechanism anywhere: the ward is not applicable unless the person decides to adopt one first. | `app/**`, `lang/**`, `resources/views/**` | `src/**`, `public/locales/**` |
| `<<translate_fn>>` | The calls user-facing text must go through | Search for the translator: Laravel `git grep -nE '\b(__\|trans\|trans_choice)\('`; Node `git grep -nE "useTranslation\|i18next\|\bt\("` and read the i18n setup. When the project wraps the framework's translator in its own helper and uses it consistently, bind only the wrapper, so calling the framework's translator directly fails. | `__()`, and `trans_choice()` for counts | `t()` from i18next (`useTranslation()` in React) |
| `<<translation_files>>` | Where the source-language text is kept | The translator's configured load path: Laravel `lang/<fallback_locale>/` (`config/app.php`); i18next `backend.loadPath` or the `resources` passed to `init()`. | `lang/en/*.php`, `lang/en.json` | `public/locales/en/*.json` |
| `<<user_text_signals>>` | An extended regex matching added lines that put text in a user-facing position | Start from this table's value for the stack, then add the project's own notification, flash, toast and export-label calls (look at how existing user-facing messages are produced). | `\$fail\(\|withMessages\(\|Exception\(\|->(subject\|line\|greeting\|action)\(\|->with\('(status\|success\|error\|message)'\|function (messages\|attributes)\(\|\b(__\|trans\|trans_choice)\(` | `(Error\|Exception)\(\|message:\|toast\.\|\b(title\|label\|placeholder\|alt\|aria-label)=\|>[^<>{}]*[A-Za-z]{2,}[^<>{}]*<\|\bt\(` |
| `<<validation_defaults>>` | Optional. The validation library's translated default messages | Check whether the validator's built-in messages come from `<<translation_files>>` or another translated catalog. Without it, the validator's messages aren't translated, step 3's override rule doesn't apply, and every validation message the slice writes follows step 5. | `lang/<locale>/validation.php` (`php artisan lang:publish`) | zod messages translated through `zod-i18n-map`, or nestjs-i18n's validation messages; often not bound |
| `<<validation_overrides>>` | Optional, and required when `<<validation_defaults>>` is bound. The places a request or field replaces the default validation message or attribute name | Read how existing validators set a custom message. | A FormRequest's `messages()` or `attributes()`, and `custom` or `attributes` entries in `lang/en/validation.php` | A `message` option on a zod or class-validator rule, or a custom `errorMap` |
| `<<design_record>>` | Where a change records why it was made | The project's design documents, ADRs, or the PR description. When the project keeps none, the PR description. | The PR description or the change's design document | The PR description or the change's design document |
| `<<resolve_key_cmd>>` | Optional. A command that prints a key's text in the source language | Look for a console or script that can call the translator. Without it, find the key in `<<translation_files>>` by reading the file. | `php artisan tinker --execute="echo __('<key>');"` (prints the text, not the key) | `jq -e '.<key path>' public/locales/en/<namespace>.json` |
| `<<key_convention>>` | Optional. How keys are grouped and named | Read two or three translation files for a pattern (one file or namespace per area, separate groups for labels and sentences). Without it, any existing key named for its meaning passes. | One file per domain area, nested keys such as `invoices.overdue.subject` | One namespace per feature, nested camelCase keys, plural forms as `_one` and `_other` |

**Verification:**

1. List the files the slice changes under the ward's paths. If none, the ward is N/A.
   `git diff --name-only <base>...HEAD -- <<paths>>` and `git ls-files --others --exclude-standard -- <<paths>>`
2. List the added lines that put text in a user-facing position (for an untracked file, grep the whole file):
   `git diff -U0 <base>...HEAD -- <<paths>> | grep -E '^\+' | grep -E -- '<<user_text_signals>>'`
   Each hit is a candidate; steps 3 to 5 decide it. Also read every template, view or UI component the slice adds or
   changes for text written directly in markup.
3. Validation text, when `<<validation_defaults>>` is bound:
   - Built-in rules use the default messages. The slice adds no `<<validation_overrides>>` entry unless
     `<<design_record>>` names the user who sees that message and why the default wording fails them. A justified
     override is a plain string in `<<translation_files>>` and covers every field of that request the same user can
     hit, not one.
   - A custom rule fails with a key that exists in `<<translation_files>>` as a plain string with named placeholders,
     resolved by `<<translate_fn>>` or by the validator's own translation of rule messages, not a literal and not
     concatenation.
4. No translation file calls a translator while it loads (possible only where translation files are code). A helper
   that builds a file's entries without resolving another key is not a translator call.
5. Other user-facing text: notification and mail subjects, titles, greetings, bodies and lines; mail, PDF and page
   templates; UI text, button labels, placeholders, titles and accessible labels; flash and toast messages;
   exception and error messages that reach a user (rendered in a response or page, or written to a file the user
   downloads); and labels, column names and headers in imports, exports and charts. Each one the slice adds is
   `<<translate_fn>>` with a key that exists (`<<resolve_key_cmd>>` prints the text, not the key) and follows
   `<<key_convention>>`, with every dynamic part passed as a named placeholder. Not user-facing: log and
   error-tracker messages, exceptions only a developer sees, CLI output, identifiers, enum values, config, and data a
   user typed.

- PASS when validation text follows step 3, no translation file breaks step 4, and every other user-facing text the
  slice adds follows step 5.
- FAIL when the slice adds a `<<validation_overrides>>` entry with no recorded user and reason in
  `<<design_record>>`, or one that covers only some of the request's fields; a custom rule fails with a literal; a
  translation file calls a translator; or other user-facing text is a literal, is built by concatenating or
  interpolating around a literal or a translation, uses a translation call that isn't `<<translate_fn>>`, or uses a
  key that doesn't exist. Literals that were already there before the slice aren't this slice's violation; the
  checker notes them as follow-ups.

**Applicability:** Code, templates and translation files under `<<paths>>` that the slice adds or changes. Code with
no translation mechanism is out of scope until it has one. Tests, migrations, seed data, fixtures and factories are out
of scope.
