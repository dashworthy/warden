---
version: 1
phases:
  - 'design'
  - 'code'
---

# BP-014: Account for every state and path a transition can start from

**Description:** A slice that adds or changes a transition (a write that moves a record from one state to another:
a status column, or a column whose value decides what may happen next, such as a closing reference, a pause-until
timestamp, a soft delete or an assignment) accounts for every state the record can be in when the transition runs
and every path that reaches it. Each from-state is allowed or rejected on purpose, the rejection holds under a
retried or concurrent call, and the rejected states and the race are proven by tests.

**Rationale:** A transition written for the state its author pictured runs from every other state too: a hold
applied to a cancelled subscription, a resume that reactivates a schedule the user switched off a moment earlier. A
from-state check on a record loaded before the transaction starts is a race: support cancelling an order while the
customer's own cancel arrives from the app both see Pending, so the order gets two refunds and two webhooks, and
reports count it twice. A request-level idempotency key stops one client replaying its own request, not two writers
on one row. Invalid states found months later in production data are repaired by hand, or by data migrations that
have to handle every variant.

**Violations:**

```text
// pseudocode: cancelOrder(order), where the request layer loaded order before the transaction began
transaction:
    if order.status != PENDING: throw OrderNotCancellable
    insert refund for order
    order.status = CANCELLED; save(order)
```

Two cancels arriving together both read PENDING from their own copy, both pass the check, and each inserts a refund.

```text
// pseudocode: holdSubscription(subscription)
if subscription.status == ON_HOLD: throw AlreadyOnHold
subscription.status = ON_HOLD; save(subscription)
```

The guard names only the target state. A CANCELLED subscription can be held, and resuming it later makes it ACTIVE,
a state nobody chose for it.

**Compliant examples:**

```text
// cancelOrder: re-read the row under a lock inside the transaction, then check
transaction:
    order = select order where id = :id for update
    if order.status != PENDING: throw OrderNotCancellable
    ...
```

```text
// holdSubscription: a conditional update on the one allowed from-state; its row count is the guard
affected = update subscriptions set status = ON_HOLD where id = :id and status = ACTIVE
if affected == 0: throw SubscriptionNotActive
```

```text
test "a cancelled subscription cannot be held":
    s = create subscription (status CANCELLED)
    expect holdSubscription(s) throws SubscriptionNotActive; expect reload(s).status == CANCELLED

test "a hold from a stale copy of a subscription already held is rejected":
    s = create subscription (status ACTIVE); stale = load(s.id)
    holdSubscription(s)
    expect holdSubscription(stale) throws SubscriptionNotActive
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where states are declared and transitions are written | Find the state definitions (next row), then every folder holding code that writes those columns: services or actions, models, jobs, scheduled commands, controllers and request validators. List the narrowest globs that cover them. With no stateful records, the ward doesn't apply | `app/Enums/**`, `app/Models/**`, `app/Actions/**`, `app/Jobs/**`, `app/Console/Commands/**`, `app/Http/Controllers/**`, `app/Http/Requests/**` | `prisma/schema.prisma`, `src/**/*.service.ts`, `src/**/*.controller.ts`, `src/jobs/**` |
| `<<state_definitions>>` | Where a record's states are declared | Search for enums or union types named `*Status` or `*State`, database enum or check-constrained columns, and the casts that map a column to them | Backed enums in `app/Enums/*Status.php`, cast on the model in `casts()` | `enum` blocks in `prisma/schema.prisma` |
| `<<state_write_pattern>>` | A regex matching added lines that write a state | Build it from the state definitions: the status column names and enum names, plus the soft-delete calls and the timestamp or reference columns whose value gates what happens next | `status.? =>\|Status::[A-Za-z]+\|_at.? =>\|_until.? =>\|->(delete\|restore\|forceDelete\|associate)\(` | `status:\|Status\.[A-Z_]+\|At:\|Until:\|\.delete(Many)?\(` |
| `<<transition_map>>` | Optional: where allowed transitions are declared in code | Search for `transitions`, `canTransitionTo`, `allowedTransitions`, or a state-machine library in the dependencies. Without one, the steps that mention it are skipped | An enum method `canTransitionTo()`, or a model-states package's transition config | A `TRANSITIONS` map beside the enum, or an XState machine |
| `<<concurrency_guard>>` | How a write checks its from-state so the check holds against a concurrent writer | Look at existing transactional writes: search for row locks (`lockForUpdate`, `FOR UPDATE`, `forUpdate()`) and conditional updates whose where clause names the status. A database without row locks allows only the conditional update | `DB::transaction()` re-reading the row with `lockForUpdate()`, or `->where('status', $from)->update([...])` checking the returned count | `SELECT ... FOR UPDATE` (via `$queryRaw` in `prisma.$transaction()`, or Knex `.forUpdate()` in `knex.transaction()`), or `updateMany({ where: { id, status: from } })` checking `count` |
| `<<early_checks>>` | Checks that run before the transaction, so are not guards | Find where requests are validated and authorized, where records are loaded from route parameters, and how queued work receives records | Form request `authorize()` and `after()` hooks, route model binding, a job's serialized model | Validation middleware or pipes (zod, class-validator), NestJS guards, a record loaded by a param handler, a payload a job received |
| `<<side_effect_calls>>` | A regex matching calls that reach outside the transaction | Search for the queue, mail, notification, event-bus, webhook and HTTP client calls the code uses | `dispatch\(\|::dispatch\|Notification::\|->notify\(\|Mail::\|event\(\|Http::` | `\.add\(\|\.publish\(\|\.emit\(\|fetch\(\|axios\.\|sendMail\(` |
| `<<after_commit>>` | How a side effect is held until the transaction commits | Search for `afterCommit`, an outbox table and its relay, or post-commit hooks; read the queue config for a global after-commit setting. When the repository has none, the person decides how side effects wait for commit | `->afterCommit()` on jobs, notifications and events, or the queue connection's `after_commit` option | An outbox row written in the transaction and relayed after commit, or the call made after `$transaction()` resolves |

**Verification:**

`<base>` is the commit the slice branched from. In commands, each glob of `<<paths>>` is written `':(glob)<glob>'`.

1. List the state writes the slice adds or changes: new states in <<state_definitions>> or <<transition_map>>, and
   added lines that write a state column, soft-delete or restore, or set a gating reference:
   `git diff -U0 <base>...HEAD -- <<paths>> | grep -E '^\+.*(<<state_write_pattern>>)'`
   Read each hit: it is a transition when the column's value decides which actions are allowed next. If none is,
   the ward is N/A.
2. For each transition, list every state the record can be in when it runs: each value of the column's state type,
   plus each implicit state that changes what the transition should do (soft-deleted, a set pause-until or closing
   reference, a child record, a parent in another state). Child rows the transition itself writes or deletes count
   too: each state they can be in, and anything else working on them at the time, is accounted for. Read the state
   definition, the model's casts and traits, and the columns the transition and its siblings read.
3. List every path that reaches the transition: each caller of the function that performs it, and each other writer
   of the same column, including model methods, queued jobs, commands and scheduled sweeps:
   `git grep -n -E '<function or class name>|<column>'`
   A target the slice adds to <<transition_map>> also reaches every writer that reads the map (a "can transition"
   check, a list of selectable states, an edit form's save), so each of those is a path too. A state the slice adds
   brings its exits with it: every existing writer of the column can now run from the new state, so each is a path
   out of it that the slice allows on purpose or rejects, and <<transition_map>> gets an entry for it.
4. For each from-state from step 2 and path from step 3, the code either allows the transition, leaving the record
   in a valid state (every column that goes with the new state written in the same transaction), or rejects it with
   a guard. A from-state the code neither allows on purpose nor rejects is unaccounted for.
5. Each guard holds under a concurrent call, using <<concurrency_guard>>: the transition re-reads the row under a
   lock inside its transaction before checking, or writes with a conditional update on the from-state and checks
   the affected-row count. A check only in <<early_checks>>, or only on a record loaded before the transaction (a
   route-bound record, a job's payload, a batch a sweep loaded earlier), is not a guard; it may stay for its error
   message. The same holds for a rule on which target states a path may write (an edit form's allowed states): the
   code that writes enforces it too. When <<transition_map>> exists, the guard allows nothing it forbids, and may be
   narrower for a given path.
6. A retried call has one effect: calling the transition twice on the same row throws a rejection (or the "already"
   error) or returns the first result, and creates no second record, webhook, notification or job. Each side effect the
   transition starts (`git diff -U0 <base>...HEAD -- <<paths>> | grep -E '^\+.*(<<side_effect_calls>>)'`) waits for
   the commit through <<after_commit>>.
7. The slice's tests include, for each transition it adds or changes, a test per rejected from-state (when several
   states are rejected by one guard branch, a test for that branch is enough), and a test that a second call on the
   same row (passing a copy of the record loaded before the first call, when the transition takes a record) is
   rejected or replayed, asserting the count of what it creates. Look for these in the repository's test files, not
   only under <<paths>>, which may not cover them.
8. In the `design` phase, check the plan instead of a diff: for each transition it adds or changes, it names every
   from-state from step 2 as allowed or rejected, every path from step 3, and how the guard holds under a retried
   and a concurrent call.

- PASS when every from-state and path of every transition the slice adds or changes is allowed on purpose or
  rejected, every guard holds under a concurrent call, a retry has one effect, every side effect waits for commit,
  and the tests from step 7 exist. In the `design` phase, PASS when the plan names all of that.
- FAIL when a from-state or path is unaccounted for; a transition's only from-state check is in <<early_checks>> or
  on a record read before the transaction; a path opened through <<transition_map>> is unguarded; a repeat creates a
  second record, webhook, notification or job; a side effect is started before commit; or a test from step 7 is
  missing. In the `design` phase, FAIL when the plan leaves out a from-state, a path, or how the guard holds under a
  retried or concurrent call.

**Applicability:** Records with a state (a status column, or an implicit state such as a closing reference, a
pause-until or closed-at timestamp, a soft delete or an assignment) under <<paths>>, when a slice adds or changes a
transition for them. Plain fields with no rule on which values may follow which are N/A. Existing transitions the
slice doesn't change are out of scope: an unguarded one found while listing paths is reported as a follow-up, not a
failure of this slice. An existing writer that can now run from a state the slice adds is not one of those: it is a
path step 3 covers. Data migrations that rewrite states in bulk are out of scope.
