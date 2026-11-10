---
version: 1
phases:
  - 'code'
---

# BP-010: Fit new code to the architecture tests instead of exempting it

**Description:** A change makes the architecture tests and static analysis pass by changing its own code to follow
their rules, not by adding its code to a rule's exemptions, adding it to a baseline, putting an ignore comment on it,
or loosening the rule. An exemption is allowed only when `<<design_doc>>` records which rule it exempts, why the code
can't follow it, and that `<<exemption_approver>>` approved it.

**Rationale:** Each architecture rule encodes a convention the team agreed on, and its exemptions record the few
places that were allowed to break it, each with its reason. An entry added to turn a red check green silently changes
the convention for everyone after: the next change copies the exemption, and the rule stops meaning anything. It also
hides the question the reviewer should have been asked: the reviewer sees new entries in a rule's exemption list with
no word on why the rule didn't fit, so either the review stalls on it or the exemption merges unexamined. A baseline
that only grows never gets paid down, because nobody can tell its old debt from what was added last week.

**Violations:**

```diff
// Laravel (Pest architecture test): the rule's ignore list gains the new controller
 arch('controllers query through query classes, not the DB facade')
     ->expect('App\Http\Controllers')
     ->not->toUse('Illuminate\Support\Facades\DB')
     ->ignoring([
         'App\Http\Controllers\HealthCheckController', // pings the connection itself; approved in ADR 0007
+        'App\Http\Controllers\InvoiceReportController',
     ]);
```

```diff
// Node (dependency-cruiser): the new route is cut out of the rule's subject
 {
   name: 'routes-go-through-services',
   severity: 'error',
-  from: { path: '^src/routes', pathNot: '^src/routes/health\\.ts$' },
+  from: { path: '^src/routes', pathNot: ['^src/routes/health\\.ts$', '^src/routes/invoiceReport\\.ts$'] },
   to: { path: '^src/db' },
 },
```

Both exempt new code with no recorded reason, where moving its query into the layer the rule names would satisfy the
rule.

**Compliant examples:**

```text
// Any stack: the new code follows the rule, and no rule, baseline or ignore comment changes
InvoiceReportController / invoiceReport route  ->  calls the invoice report query or service
                                                    (which is allowed to use the database)
```

```markdown
<!-- <<design_doc>>: an exemption recorded with its rule, its reason and its approval -->
- **Exemption (approved by <approver>):** `HealthCheckController` joins the "controllers query through query
  classes" rule's ignore list: it checks the connection itself with a raw `select 1`, which a query class would only
  wrap. The ignore entry carries this reason as a comment.
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | The rule files, baseline files and source folders the rules govern | Combine the values of `<<architecture_rules>>` and `<<baseline_files>>` with the source roots the rules check (read each rule's subject paths or namespaces) | `tests/Arch/**`, `phpstan.neon`, `phpstan-baseline.neon`, `deptrac.yaml`, `app/**` | `eslint.config.js`, `.dependency-cruiser.cjs`, `eslint-suppressions.json`, `tsconfig.json`, `src/**` |
| `<<architecture_rules>>` | The files that define architecture tests, dependency and layer rules, and static analysis configuration, as git pathspecs | `git ls-files \| grep -iE 'arch\|deptrac\|depcruise\|dependency-cruiser\|boundaries\|phpstan\|psalm\|eslint\|tsconfig'`, then read the test runner and lint configs for rules about layers, naming, allowed dependencies or types. If the repository has no architecture test and no static analysis, the best practice doesn't apply | `tests/Arch` (Pest `arch()` tests), `phpstan.neon`, `deptrac.yaml` | `eslint.config.js` (eslint-plugin-boundaries rules), `.dependency-cruiser.cjs`, `tsconfig.json` |
| `<<exemption_mechanisms>>` | Every way a rule in `<<architecture_rules>>` lets named code off | Read each rule file for ignore or allow lists, one-off or override maps, approved-caller lists, `exclude` or `pathNot` patterns, and per-file overrides that turn a rule off or down; list each with its file and key | Pest `->ignoring([...])`; `ignoreErrors` and `excludePaths` in `phpstan.neon`; `skip_violations` in `deptrac.yaml` | `ignores` and per-`files` config objects setting a rule to `'off'` or `'warn'` in `eslint.config.js`; the `boundaries/ignore` setting; `pathNot` and `options.exclude` in `.dependency-cruiser.cjs`; `exclude` and lowered strictness flags in `tsconfig.json` |
| `<<baseline_files>>` | Optional: files listing known violations the checks tolerate, each marked shrink-only when its header, the docs or a CI check says it may only shrink. Without it, step 2 has no baseline to check | `git ls-files \| grep -iE 'baseline\|known-violations\|suppressions'`; read each file's header and the CI workflow for a rule that it only shrinks | `phpstan-baseline.neon`, `deptrac.baseline.yaml` | `eslint-suppressions.json` (ESLint bulk suppressions), `.dependency-cruiser-known-violations.json` |
| `<<ignore_comment_pattern>>` | An extended regex matching the inline comments that silence a check in source | For each tool in `<<architecture_rules>>`, take the inline suppression comments it honours, and check the pattern finds the existing ones with `git grep -nE '<pattern>'` | `@phpstan-ignore\|@pest-arch-ignore\|@psalm-suppress` | `eslint-disable\|@ts-ignore\|@ts-expect-error\|@ts-nocheck` |
| `<<design_doc>>` | Where a change records its decisions before it merges | Look for a design, plan, ADR or RFC folder (`git ls-files \| grep -iE 'adr\|decisions\|design\|rfc\|plans?/'`) and how recent changes used it; else the pull request template's sections; else the pull request description | The change's ADR under `docs/decisions/`, or the pull request description | The change's ADR under `docs/adr/`, or the pull request description |
| `<<exemption_approver>>` | Who may approve an exemption from a rule | The owners of the rule files in `CODEOWNERS` (`grep -nE 'arch\|phpstan\|eslint\|cruiser' .github/CODEOWNERS CODEOWNERS docs/CODEOWNERS 2>/dev/null`); else the person who asked for the change. If neither names anyone, the person adopting decides | The code owners of `tests/Arch/` and `phpstan.neon` | The code owners of `eslint.config.js` and `.dependency-cruiser.cjs` |

**Verification:**

1. List the rule and baseline files the change touches. If there are none, and step 3 finds nothing, the change adds
   no exemption and the ward PASSes.
   `git diff --name-only <base>...HEAD -- <<architecture_rules>> <<baseline_files>>`
2. In each, list the added, changed and removed lines:
   `git diff -U0 <base>...HEAD -- <<architecture_rules>> <<baseline_files>> | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)'`
   Each of these is an exemption or a loosening:
   - an entry added to any of `<<exemption_mechanisms>>`;
   - an entry added to any of `<<baseline_files>>`, including by regenerating the file;
   - a rule changed so that it checks less or no longer fails the build: its expectation, pattern, type list, subject
     or strictness narrowed, its severity lowered (error to warning or off), or the rule removed.
3. List the ignore comments the change adds to source:
   `git diff -U0 <base>...HEAD | grep -E '^\+' | grep -E '<<ignore_comment_pattern>>'`
4. For each exemption from steps 2 and 3, look in `<<design_doc>>` for the rule it exempts, why the new code can't
   follow it, and approval from `<<exemption_approver>>`. Removing an entry, because the code now follows the rule, is
   always allowed.

- PASS when the change adds no exemption or loosening, or each one it adds is recorded in `<<design_doc>>` with its
  rule, its reason and approval from `<<exemption_approver>>`, and carries a comment at the entry (or the ignore
  comment's own text) naming that reason.
- FAIL when the change adds an exemption, a baseline entry, an ignore comment or a loosened rule with no recorded
  reason and approval, or adds any entry to a baseline marked shrink-only, recorded or not.

**Applicability:** The files in `<<architecture_rules>>` and `<<baseline_files>>`, and ignore comments in source under
`<<paths>>`. A change whose purpose is the rule itself, such as one that introduces or deliberately revises an
architecture test, is in scope only for exemptions it adds beyond what its `<<design_doc>>` describes. An ignore
comment in a test whose purpose is to assert that a check fails (a type test that expects a type error) is not an
exemption.
