---
version: 1
phases:
  - code
---

# BP-012: Keep secrets in a secret store or encrypted columns, never in plain text

**Description:** A secret the application stores per record (a tenant's database password, a key or password a user
or an integration provides) is an encrypted field, <<encrypted_field>>, kept out of serialization with
<<output_exclusion>>; a token the application issues and only ever compares is stored as a hash. A secret the whole
deployment shares comes from <<secret_store>> and is read only through <<config_module>>; the repository never holds
its value. No secret is returned, logged or committed.

**Rationale:** A plain-text column puts the secret in every database dump, backup, replica and query log, and a model
or record that serializes it hands it to every response built from it. A real value committed in code, a config
default, <<env_example>>, a seeder or a test stays in git history for good, so it has to be rotated the moment it
lands, and a config default is silently used wherever an environment forgets to set the variable. Encrypting a token
that is only ever compared keeps a way to recover it that nothing needs; a hash can't be leaked back. Reading the
environment all over the code hides which secrets a deployment needs, so a new one is missed in the secret store and
the first environment without it fails at run time.

**Violations:**

```php
// Laravel: a migration and its model (new)
$table->string('webhook_secret')->nullable();
// CompanySetting: no cast, not hidden
```

A per-tenant secret stored as plain text, and serialized wherever the model is.

```ts
// Node: src/config.ts
export const config = {
  mapsApiKey: process.env.MAPS_API_KEY ?? 'mk_live_7f3a9c1e2b4d40a6',
};
```

A real key committed as a config fallback: it ships in git, and it is used wherever the environment forgets to set
the variable.

**Compliant examples:**

```php
// Laravel: ciphertext is longer than the value, so the column is text
$table->text('webhook_secret')->nullable();
// CompanySetting
protected $casts  = ['webhook_secret' => 'encrypted'];
protected $hidden = ['webhook_secret'];
```

```ts
// Node: src/config.ts, the only reader of process.env; .env.example gets MAPS_API_KEY= with no value
export const config = {
  mapsApiKey: required('MAPS_API_KEY'), // throws at startup when unset
};
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where secrets are declared, stored, read and committed: application code, config, schema and migrations, fixtures and tests, and the example environment file | Take the application, config, schema, seed and test folders from `git ls-files \| cut -d/ -f1 \| sort -u`, plus `<<env_example>>` | `app/**`, `config/**`, `database/**`, `tests/**`, `.env.example` | `src/**`, `prisma/**`, `test/**`, `.env.example` |
| `<<schema_paths>>` | Where columns are declared: migrations or the ORM schema | Find the migrations folder or schema file (`git ls-files \| grep -iE 'migration\|schema\.prisma\|entities'`) | `database/migrations` | `prisma/schema.prisma`, `prisma/migrations` |
| `<<config_module>>` | The only place allowed to read the environment or the secret store; the rest of the code reads its values from there | Search for environment reads (`git grep -n -E '<<env_read>>' \| cut -d: -f1 \| sort \| uniq -c`) and find the config folder or module most of them sit in. When reads are scattered with no config module, the person decides where it goes before the ward applies | `config/*.php`, read elsewhere with `config()` | `src/config.ts`, imported as `config` |
| `<<env_read>>` | A `grep -E` pattern for reading an environment variable | The call the language uses, as found for `<<config_module>>` | `env\(` | `process\.env` |
| `<<env_example>>` | The committed file that lists environment variable names | `git ls-files \| grep -E '\.env\.(example\|sample\|dist\|template)$'`. When there is none, the change's PR body lists the names instead | `.env.example` | `.env.example` |
| `<<secret_store>>` | Where the deployment's shared secrets live, outside the repository | Read the deploy config, infrastructure code and runbooks (`git ls-files \| grep -iE 'deploy\|infra\|terraform\|helm\|\.github/workflows'`) for a secrets manager, vault or the host's secret settings. When nothing says, the person names it | AWS Secrets Manager, loaded into the environment at deploy | AWS Secrets Manager, read at startup by `src/config.ts` with `@aws-sdk/client-secrets-manager` |
| `<<secret_listing>>` | Where a change lists a new shared secret so it is added to `<<secret_store>>` | Look for infrastructure code that declares secrets (e.g. a secrets file under `infra/`), which the diff shows; otherwise use the design document or the PR template's section for environment changes, or add such a section to the PR body | A "New environment variables" section in the change's design document or PR body | `infra/secrets.tf`, one `aws_secretsmanager_secret` per secret |
| `<<encrypted_field>>` | How a per-record field is encrypted at rest, and the column type it needs | Search for existing encrypted fields (`git grep -n -iE 'encrypt'` in models and schema) and the ORM's field-encryption support. When the repository has none, the person picks one before the ward applies | the `encrypted` cast (or `encrypted:array`, `encrypted:collection`, `AsEncryptedArrayObject`) on a `text` column | `/// @encrypted` on a `String` field, applied by the `prisma-field-encryption` client extension |
| `<<output_exclusion>>` | How a field is kept out of the record's serialization and query results | Find how existing password or token fields are hidden (`git grep -n -iE 'hidden\|omit\|exclude' -- <<paths>>`) | `$hidden` on the model | Prisma's global `omit` in the client constructor, or a per-query `omit` |
| `<<token_hash>>` | How an issued token is hashed, and compared in constant time | Search for existing password or token checks (`git grep -n -iE 'hash_equals\|timingSafeEqual\|bcrypt\|argon\|sha256'`) | `hash('sha256', $token)` with `hash_equals()`, or `Hash::make()` with `Hash::check()` | `createHash('sha256')` with `timingSafeEqual()` from `node:crypto` |
| `<<response_layer>>` | What turns records into responses a client receives | Read how controllers return data: resource or serializer classes, view props, DTOs | API Resources, Inertia props, `response()->json()` | Controller return values and response DTOs |
| `<<log_calls>>` | The calls that write logs or report errors | Search for the logger and error reporter in use (`git grep -n -E 'Log::\|logger\|console\.\|captureException\|report\('`) | `Log::`, `logger()`, `report()`, activity log properties | the Nest `Logger`, pino's `logger`, `console.*`, Sentry's `captureException` context |
| `<<env_guard>>` | Optional. A test or lint rule that already fails an environment read outside `<<config_module>>` | Search the static-analysis and lint config and the architecture tests for a rule on environment reads. Without it, step 3 checks the reads by grep alone; with it, adoption lists it under `enforced-by` | Larastan's `noEnvCallsOutsideOfConfig`, or a Pest arch test on `env` | ESLint's `n/no-process-env`, with an override for `src/config.ts` |
| `<<human_review>>` | The question a person answers, because the secret store is outside the code | Use it as written | Has each new secret this change lists been added to the secret store for every environment that runs it? | Has each new secret this change lists been added to the secret store for every environment that runs it? |

**Verification:**

1. List the secrets the change adds or changes. These commands find candidates; read each to decide, since public
   keys, key URLs, ids, bucket names and lookup keys (a cache key, a translation key) are not secrets:
   `git diff -U0 <base>...HEAD -- <<schema_paths>> <<paths>> | grep -E '^\+' | grep -iE "secret|token|password|passphrase|api_?key|private_?key|credential|signing"`
   `git diff -U0 <base>...HEAD -- <<config_module>> <<env_example>> | grep -E '^\+'`
   `git diff -U0 <base>...HEAD -- <<paths>> | grep -E '^\+' | grep -E "<<env_read>>|['\"][A-Za-z0-9+/=_-]{24,}['\"]"`
   If the change adds no secret, no environment read and no long literal, the ward is N/A.
2. A secret stored per record: its field is encrypted with <<encrypted_field>>, in the column type that binding
   names, and kept out of serialization with <<output_exclusion>>. A token the application issues and only compares
   is stored as a hash and checked in constant time with <<token_hash>>, never stored plain or encrypted; the stored
   hash, like an encrypted field, is kept out of serialization with <<output_exclusion>> and out of <<response_layer>>.
   Encrypting a column that already has rows also needs a data migration that encrypts them.
3. A secret the deployment shares: only <<config_module>> reads it, from the environment or <<secret_store>>, with no
   literal default or fallback, and no other file the change touches reads it with <<env_read>> (<<env_guard>>, when
   bound, already fails such a read); <<env_example>> gets the name with an empty value; and the change lists the
   new secret in <<secret_listing>> so it is added to <<secret_store>>.
4. Leaks: the change doesn't put a secret in <<response_layer>> (except the one response that shows a newly issued
   token, once); doesn't pass it to <<log_calls>>, an exception message or an audit log; and commits no real value in
   code, a config default, <<env_example>>, a factory, a seeder or a test (tests use obvious fakes such as
   `'test-secret'`).

- PASS when every secret from step 1 is stored as step 2 or 3 says and none leaks by a path in step 4.
- FAIL when a secret is stored in plain text, an encrypted secret field or the stored hash of a compared-only secret
  isn't excluded from serialization or is returned in a response, a compared-only token is stored plain or encrypted
  instead of hashed or compared with a plain equality check, code outside <<config_module>> reads a secret from the
  environment, a secret's read has a literal default, a new shared secret isn't in <<env_example>> or
  <<secret_listing>>, or a secret is returned, logged or committed.

**Applicability:** Schema and migrations, models, config, <<env_example>>, and code, fixtures and tests under
<<paths>> that the change adds or changes. Secrets already in the repository before the change are follow-ups, not
this change's violation, and a committed real value is reported for rotation. How the deployment loads
<<secret_store>> is outside the code; step 3 only checks that each new secret is listed in <<secret_listing>>, and the
`<<human_review>>` question asks a person whether it reached the store.
