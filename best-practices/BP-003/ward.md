---
version: 1
phases:
  - 'code'
---

# BP-003: Change only what the request needs

**Description:** A change edits only the files and lines that the behavior it was asked for needs. Anything else,
however wrong or ugly the code around it, is recorded in <<follow_up_list>> instead of being done in the change.

**Rationale:** Every extra line is review time spent on something nobody asked for, and a place for a regression to
hide in a diff the reviewer is reading for something else. Drive-by renames, reformatting and moved code bury the
real change and conflict with other branches built on or alongside it. Speculative options and abstractions add code
that has to be kept working with no user to justify it. Unrequested fixes ship without the test, review and approval
their own change would give them.

**Violations:**

```diff
// Pseudocode. Task: "the order page receives the order's refund limit"
// the handler that renders the order page
   render('orders/show', {
-    order_total: total,
-    customer_name: name,
+    orderTotal: total,
+    customerName: name,
+    refundLimit: config('orders.refund_limit'),
   })
```

The task needed one added line; the change also renamed two existing fields, which changes what the page receives.

```diff
// Pseudocode. Same task, the orders config
   max_lines: 500,
+  refund_limit: env('ORDERS_REFUND_LIMIT', 1000),
+  // Lets an operator turn refunds off; defaults to on
+  refunds_enabled: env('ORDERS_REFUNDS_ENABLED', true),
```

Nobody asked for an environment override or an on/off switch: two speculative options with no user.

**Compliant examples:**

```diff
// Pseudocode. The handler
     customer_name: name,
+    refund_limit: config('orders.refund_limit'),
```

```diff
// Pseudocode. The config
   max_lines: 500,
+  refund_limit: 1000,
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<scope_document>>` | The change's statement of scope: the plan, spec, issue or ticket that says which behavior the change delivers | Look for a folder of plans or specs that recent changes add to (`git log --name-only --format= -30 \| grep -iE 'plan\|spec\|design\|rfc\|adr' \| sort -u`), a PR template that asks for one (`.github/pull_request_template.md`), and the issue reference convention in commit subjects (`git log -30 --format=%s`). If the repository keeps none, bind it to the PR description and the issue it links. | `docs/plans/<change>.md` | the PR description and its linked issue |
| `<<planned_files>>` | Optional. Where the scope document lists the existing files the change will edit | Read the plan template and two or three recent scope documents for a files table or list. Without it, step 2 is skipped and each edited file is judged by step 3 alone. | the plan's "Files this change edits" table | the PR template's "Files touched" list |
| `<<follow_up_list>>` | Where out-of-scope work the change found is recorded for a later decision | Look for a "Follow-ups" or "Out of scope" section in recent scope documents, a tracker label (`gh label list \| grep -iE 'follow\|debt\|later'`), or a documented TODO convention in `CONTRIBUTING.md`. If there is none, ask the person; the usual answer is a new issue in the project's tracker. | the plan's `## Follow-ups` section | an issue labelled `follow-up` |
| `<<project_conventions>>` | Optional. The structural patterns the project requires for every feature, which never count as needless abstraction | Read the agent and contributor docs (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`), any architecture tests (`git grep -liE 'arch(itecture)?' -- tests test spec`), and the set of files most features repeat (one feature folder compared with another). Without it, only the exemptions written in step 3 apply. | an Action, a FormRequest, an API Resource and a Policy per use case | a module, controller, service and DTO per resource; database access only in services |
| `<<static_checks>>` | Optional. The type checks and architecture tests a simpler replacement must still pass | Read the CI workflow (`.github/workflows/*.yml`) and the scripts in `composer.json` or `package.json` for type-check, static-analysis and architecture-test steps. Without it, a replacement need only keep the test suite passing. | `vendor/bin/phpstan analyse` and `php artisan test --testsuite=Arch` | `npx tsc --noEmit` and `npx eslint .` |
| `<<generated_outputs>>` | Optional. Files a required tool regenerates for the change, which are in scope when the change's own edits make the tool rewrite them | Look for generator scripts (`grep -nE 'generate\|codegen\|transform' composer.json package.json`), paths marked `linguist-generated` in `.gitattributes`, and CI steps that fail when a generated file is stale. Lock files for an added or changed dependency always count. Without it, only lock files count. | `composer.lock`, and `resources/js/types/generated.d.ts` from `php artisan typescript:transform` | `package-lock.json`, and `prisma/migrations/**` from `prisma migrate dev` |
| `<<formatter>>` | Optional. The formatter whose changes to lines the change already touches are in scope | Read `composer.json` or `package.json` scripts and look for `pint.json`, `.php-cs-fixer.php`, `.prettierrc*` or `biome.json`. Without it, formatting changes count like any other line. | `vendor/bin/pint --dirty` | `npx prettier --write` |

**Verification:**

1. Find the change's scope: its <<scope_document>>, or, for work without one, the request the checker was given. If
   neither can be found, the ward is UNVERIFIED.
2. List the existing files the change edits, renames or deletes, and compare them with <<planned_files>> (and its list
   of new files, for added ones):
   `git diff --name-status --diff-filter=MRD <base>...HEAD`
   An existing file that isn't listed is a candidate for FAIL; step 3 decides it.
3. Read every hunk and match each changed line to a task, requirement or test in the scope. A line is in scope when
   the behavior it serves needs it. These are out of scope:
   - renames, reformatting, reordered imports, moved code, or reworded comments on lines the behavior doesn't need;
   - fixes to existing code the scope doesn't ask for, even real bugs;
   - options, parameters, config keys, environment overrides or flags nobody asked for;
   - abstractions with one user: an interface with one implementation, a base class with one child, a mixin or trait
     used by one class, a private function called once whose name says no more than its body, a function that only
     forwards its arguments;
   - reuse for its own sake: a public or static function, or a dependency, added only so a second place can share a
     short block, especially when callers bend what it returns (prepend an item, override a key, pass a flag);
   - handling for states that can't occur: a guard for what validation or the types already rule out, the same
     validation in two layers, a `try`/`catch` that only rethrows, or that swallows an error nothing in it throws;
   - collection ceremony: nested collection calls a reader unpacks inside-out, a list built only to compare with
     empty or loop over once, a re-index or copy that nothing reads;
   - verbosity: comments and docblocks that restate the code or walk through it step by step, a single-use variable
     whose name adds nothing, `else` after `return`;
   - a change already listed in <<follow_up_list>>, folded into this change.

   A line of the five kinds from abstractions to verbosity is out of scope only when its simpler replacement can be
   written, behaves the same (keys, order, null and empty input) and still passes <<static_checks>>.
   These are never out of scope: <<project_conventions>>; one source of truth for a rule that must agree everywhere
   (an authorization check, validation shared by a request and the object it builds, a money rule, a rule matching a
   database constraint); a helper with three or more real callers; a check at a trust boundary (user input, external
   APIs, config); and a type annotation <<static_checks>> need.
4. These count as in scope and never fail the ward: the tests that prove the behavior; the change's own
   <<scope_document>> and <<follow_up_list>> entries; <<generated_outputs>> the change's own edits regenerate; and
   <<formatter>> changes to lines the change already touches.

- PASS when every changed line serves the scope, and every existing file the change edits is listed in
  <<planned_files>> or needed by a behavior in the scope.
- FAIL when any changed line or edited file falls in the out-of-scope list in step 3. The fix reverts it, or writes
  the simpler replacement, and, if the reverted change is worth doing, records it in <<follow_up_list>> with
  file:line, the proposed change and why. A follow-up is done only after a person approves it, as its own change.

**Applicability:** Every change, in every language and directory. Work the person explicitly asks for is in scope
even if it isn't in the <<scope_document>> yet; the <<scope_document>> should then be updated to list it.
