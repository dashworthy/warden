---
version: 1
phases:
  - 'code'
---

# BP-013: Write the failing test before the code it proves

**Description:** Every behavior a slice adds or changes, every bug it fixes and every review finding it applies
starts with a test that fails against the code without it, and the failure is recorded in <<test_first_record>>
before the code that makes it pass. A change a user can see or click also has a browser test. An existing test's
assertions change only when <<behavior_spec>> changes the behavior they cover.

**Rationale:** A test written after its code is shaped by the code, so it passes whether or not the behavior is
right, and nobody learns that it would never have failed. A review finding fixed without a failing test is a guess:
the fix may change nothing, or hide a different bug. UI code that no test renders has no automated check at all, so
a page that throws in the browser ships unnoticed. Loosening an existing assertion to get a slice green silently
removes behavior the project still promises, and the next reader trusts a test that no longer checks it.

**Violations:**

```markdown
<!-- task list (excerpt) -->
- [x] 2.1 Add the hold-order endpoint, then verify with tests.
  - Added `it holds an order` to the order endpoint tests. 3 of 3 pass.
```

The code came first and the test was written to pass: no failure is recorded, so nothing shows it ever failed.

```text
// pseudocode: an existing test, changed by the slice
 test "cancelling an order releases all its reserved stock":
     ...
-    expect(reservedStock(order)).toBe(0)
+    expect(reservedStock(order)).toBeLessThanOrEqual(2)
```

An existing assertion loosened so the slice goes green, with no change in <<behavior_spec>> behind it.

**Compliant examples:**

```markdown
<!-- task list (excerpt); here <<test_first_record>> is a RED line under each task -->
- [x] 2.1 RED: add `a held order is hidden from the picking list` to the picking list tests. Run it and confirm it
  fails because orders can't be held.
  - RED: "expected status 200, received 404" (no hold route yet).
- [x] 2.2 GREEN: add the hold action and route. Run the touched test files green.
- [x] 2.3 RED, browser: add `holding an order asks for confirmation` to the browser tests, ending with
  <<page_error_check>>. Confirm it fails: "Hold" isn't in the Actions menu.
```

```markdown
<!-- review record -->
| 1 | Code review | holding a held order clears its hold date | **Confirmed**: `holding a held order keeps its first hold date` failed first | **Fixed** in `4f1c2ad` |
| 2 | Security review | hold skips the account scope | **Not reproduced**: `an order from another account can't be held` passed before any change | **Not applied** |
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Production and test code a slice can change | Read the source roots from the build or autoload config (`composer.json` autoload, `tsconfig.json` include, `package.json` workspaces) and the test roots from the test runner's config; list the narrowest globs that cover them | `app/**`, `routes/**`, `resources/js/**`, `resources/views/**`, `tests/**` | `src/**`, `test/**` |
| `<<test_paths>>` | Where tests live, as globs | The test runner's config (`phpunit.xml` testsuites, `vitest.config.*` or `jest.config.*` include) | `tests/**` | `**/*.test.ts`, `test/**` |
| `<<test_command>>` | The command that runs one test by name | Scripts in `composer.json` or `package.json`, the CI workflow, the README; run it once on a known test to confirm | `php artisan test --filter '<test name>'` | `npx vitest run -t '<test name>'` |
| `<<exempt_paths>>` | Files proven by the command that makes or runs them, not by a test: generated code, config and schema migrations | Files marked generated (a header comment, `linguist-generated` in `.gitattributes`), the output folders of codegen scripts, the config folder, the migrations folder. Optional: with none, nothing is exempt | `database/migrations/**`, `config/**`, `resources/js/types/generated.d.ts` | `prisma/migrations/**`, `src/generated/**`, `*.config.ts` |
| `<<task_list>>` | Where a slice's planned behaviors and applied review findings are listed | Look for per-change task or plan files, a PR template with a Tasks or Review section, or an issue checklist. When the repository has none, the PR description and commit messages are the list, and every change in the diff whose result a caller can observe is a behavior | The PR description's Tasks checklist and Review table | The PR description's Tasks checklist and Review table |
| `<<test_first_record>>` | Where the evidence that each test failed first is recorded | Look for a convention in the task list, plan files or PR template (a RED line, a "fails first" note with the failure message). When there is none, use the fallback: the commit history, where the commit that adds a test comes before the commit that makes it pass, and the test fails when run on the base (step 8) | A `RED:` line under each task, quoting the failure message | Commit history: a `test:` commit before the `feat:` or `fix:` commit that makes it pass |
| `<<behavior_spec>>` | Where an intended change to existing behavior is written down | A specs or requirements folder, ADRs, the issue tracker's acceptance criteria. When there is none, the linked issue or the PR description, which must then state the behavior change | The linked issue's acceptance criteria | The linked issue's acceptance criteria |
| `<<assertion_pattern>>` | A regex matching assertion lines in tests | The test framework's assertion API, from existing tests | `expect\(\|->assert\|toBe\|toEqual` | `expect\(\|assert\.\|toBe\|toEqual\|toMatch` |
| `<<mock_assertion_pattern>>` | A regex matching assertions on test doubles | The mocking API the tests use (search the test folders for mock, spy and stub calls) | `shouldReceive\|Mockery::\|->expects\(` | `toHaveBeenCalled\|vi\.fn\|jest\.fn\|mockResolvedValue` |
| `<<ui_paths>>` | Optional: code that renders what a user sees or clicks | Front-end folders (components, pages, templates). With none (an API-only service), step 5 is N/A | `resources/js/**`, `resources/views/**` | `web/src/**` |
| `<<ui_test_paths>>` | Optional: where tests that drive the UI in a real browser live | The browser test runner's config (Playwright, Cypress, Dusk, Pest browser). When the repository has UI code but no browser tests, the person decides: bind a runner the adopting slice adds, or drop step 5 from the adopted ward | `tests/Browser/**` | `e2e/**` |
| `<<page_error_check>>` | Optional: the assertion that fails a browser test when the page throws or logs an error | Look for it in existing browser tests or their shared fixture. When there is none, step 5 checks only that a browser test exists | `->assertNoJavaScriptErrors()` at the end of the test | A Playwright fixture that collects `page.on('pageerror')` and fails the test when any were thrown |

**Verification:**

`<base>` is the commit the slice branched from. In commands, each glob of a binding is written `':(glob)<glob>'`,
and an excluded one `':(exclude,glob)<glob>'`.

1. List the production files the slice changes, leaving out tests and <<exempt_paths>>:
   `git diff --name-only <base>...HEAD -- <<paths>> ':(exclude,glob)<<test_paths>>' ':(exclude,glob)<<exempt_paths>>'`
   If there are none, the ward is N/A.
2. List what needs a test: every behavior the slice adds or changes, every bug it fixes and every review finding it
   applies, from <<task_list>>. A production change from step 1 that none of them covers is a behavior too.
3. For each one, find its record in <<test_first_record>>. It names the test, quotes the failure, and comes before
   the code that makes it pass; the failure is the behavior being missing (an assertion, a not-found or rejected
   response, the function or class under test not existing), not a typo, a setup error or an unrelated exception. A
   test that passes from the start because it guards today's behavior is allowed only when the task list says so
   before the code changes.
4. Check that each named test exists at the head (`git grep -n "<test name>" HEAD -- <<test_paths>>`) and proves the
   behavior through the real code that implements it: a test whose only assertions are on test doubles
   (`<<mock_assertion_pattern>>`) doesn't prove it.
5. If the slice changes what a user can see or click (<<ui_paths>>, or the data the server sends a page to render),
   check that it adds or changes a test under <<ui_test_paths>> for that behavior, and that each browser test it
   adds ends with <<page_error_check>>: `git diff --name-only <base>...HEAD -- <<ui_test_paths>>`
6. List the existing tests whose assertions the slice changes:
   `git diff -U0 --diff-filter=M <base>...HEAD -- <<test_paths>> | grep -E '^-.*(<<assertion_pattern>>)'`
   Each one must name, in <<task_list>>, the change in <<behavior_spec>> that changes the behavior it covers.
7. Check each review finding the slice applied: it names the test that proved it, and that test failed first (step
   3). A finding no test could reproduce is reported as not reproduced and left unapplied.
8. When a record is missing, doubtful, or <<test_first_record>> is the commit history, run the test on the base with
   only the slice's test files applied; it must fail there, for the reason step 3 requires:

   ```bash
   head=$(git rev-parse HEAD)
   git worktree add --detach /tmp/ward-base <base>
   git -C /tmp/ward-base checkout "$head" -- <the slice's test files>
   (cd /tmp/ward-base && <install dependencies> && <<test_command>>)
   git worktree remove --force /tmp/ward-base
   ```

   If the test can't be run, report the ward UNVERIFIED for that test rather than PASS.

- PASS when every behavior, bug fix and applied finding has a named test that exists, proves the behavior through
  real code, and is shown failing before its code (a record in <<test_first_record>>, or a failing base run); every
  UI change has a browser test, ending with <<page_error_check>> when that is bound; and every changed existing
  assertion names the <<behavior_spec>> change behind it.
- FAIL when a behavior or applied finding has no test; a test has no evidence it failed first (no record, a record
  after its code, or a record of it passing without the task saying why up front); a test passes on the base; the
  recorded failure is not the behavior being missing; a test proves only test doubles; a UI change has no browser
  test, or a browser test the slice adds doesn't end with <<page_error_check>>; or an existing assertion is loosened
  or rewritten with no <<behavior_spec>> change behind it.

**Applicability:** Every slice that changes production code under <<paths>>. Files under <<exempt_paths>> are exempt:
the command that generates or runs them proves them. Moving or renaming code without changing what it does adds no
behavior, but step 6 still applies to it. Slices that change only tooling (CI, editor or agent configuration, docs,
the task list itself) are N/A.
