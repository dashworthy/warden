# A compared-only API client secret, encrypted, compared with !== and returned

## Bindings

- `<<paths>>`: `src/**`, `prisma/**`, `test/**`, `.env.example`
- `<<schema_paths>>`: `prisma/schema.prisma`, `prisma/migrations`
- `<<config_module>>`: `src/config.ts`, imported as `config`
- `<<env_read>>`: `process\.env`
- `<<env_example>>`: `.env.example`
- `<<secret_store>>`: AWS Secrets Manager, read at startup by `src/config.ts` with `@aws-sdk/client-secrets-manager`
- `<<secret_listing>>`: `infra/secrets.tf`, one `aws_secretsmanager_secret` per secret
- `<<encrypted_field>>`: `/// @encrypted` on a `String` field, applied by the `prisma-field-encryption` client extension
- `<<output_exclusion>>`: Prisma's global `omit` in the client constructor, or a per-query `omit`
- `<<token_hash>>`: `createHash('sha256')` with `timingSafeEqual()` from `node:crypto`
- `<<response_layer>>`: controller return values and response DTOs
- `<<log_calls>>`: the Nest `Logger`, pino's `logger`, `console.*`, Sentry's `captureException` context
- `<<env_guard>>`: ESLint's `n/no-process-env`, with an override for `src/config.ts`
- `<<human_review>>`: Has each new secret this change lists been added to the secret store for every environment
  that runs it?

## Sample

```prisma
// prisma/schema.prisma (added)
model ApiClient {
  id     String @id @default(cuid())
  name   String
  secret String /// @encrypted
}
```

```ts
// src/api-clients/api-clients.controller.ts (new)
@Post()
create(@Body() dto: CreateApiClientDto) {
  const secret = randomBytes(32).toString('base64url');
  return this.prisma.apiClient.create({ data: { name: dto.name, secret } });
}

@Get(':id')
show(@Param('id') id: string) {
  return this.prisma.apiClient.findUniqueOrThrow({ where: { id } });
}

// src/auth/api-client.guard.ts (new), in canActivate()
const req = context.switchToHttp().getRequest<Request>();
const client = await this.prisma.apiClient.findUnique({ where: { id: req.header('x-client-id') ?? '' } });
if (!client || client.secret !== req.header('x-client-secret')) {
  throw new UnauthorizedException();
}
return true;
```

## Expected fix shape

- The secret is stored only as a hash in a `secretHash` column; the plain secret exists only in the response to
  `create`, once.
- The guard hashes the presented secret and compares the hashes with `timingSafeEqual()`.
- `show` no longer returns the secret or its hash.
- The routes, the header names and how a client is looked up are unchanged.

```prisma
// prisma/schema.prisma
model ApiClient {
  id         String @id @default(cuid())
  name       String
  secretHash String
}
```

```ts
// src/auth/hash-secret.ts (new)
export const hashSecret = (secret: string): Buffer => createHash('sha256').update(secret).digest();

// src/api-clients/api-clients.controller.ts
@Post()
async create(@Body() dto: CreateApiClientDto) {
  const secret = randomBytes(32).toString('base64url');
  const client = await this.prisma.apiClient.create({
    data: { name: dto.name, secretHash: hashSecret(secret).toString('hex') },
  });
  return { id: client.id, name: client.name, secret }; // shown once, never stored
}

@Get(':id')
show(@Param('id') id: string) {
  return this.prisma.apiClient.findUniqueOrThrow({ where: { id }, omit: { secretHash: true } });
}

// src/auth/api-client.guard.ts, in canActivate()
const presented = hashSecret(req.header('x-client-secret') ?? '');
if (!client || !timingSafeEqual(Buffer.from(client.secretHash, 'hex'), presented)) {
  throw new UnauthorizedException();
}
return true;
```
