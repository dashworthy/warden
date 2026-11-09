# Ward registry format

The contract shared by `/record-ward`, `/audit-wards`, `/check-wards` and the `ward-checker`
agent. Wards never live in the plugin: each repository owns its own registry.

## Location

Each repository keeps its registry in a `.warden/` directory at the repository root:

```
.warden/
├── wards.md          the index: one row per ward, plus the retired IDs
└── wards/
    ├── WARD-001.md   one file per ward, named by its ID
    └── WARD-002.md
```

- Root: `git rev-parse --show-toplevel`; outside a git repository, the current working directory.
- No other path is searched, and there is no configuration file.
- The ward files are the source of truth for which wards exist; the index summarizes them.
- Wards never cross repositories. Don't read, copy or suggest another repository's wards unless
  the user asks.

## Creating the registry

Create the registry only as part of a change a human has approved (normally the first
`/record-ward`), or when a human explicitly asks for it. Write `.warden/wards.md` with exactly this
template, then add the approved ward's file. A new registry holds no other wards: never add
example, placeholder or speculative ones.

~~~markdown
# Wards

Engineering standards for this repository. Each ward is one enforceable standard, kept as its own
file in `wards/` and checked against every implementation slice by an independent reviewer.
Managed with the warden plugin: `/record-ward` adds a ward, `/audit-wards` consolidates them,
`/check-wards` verifies a slice.

<!-- One Summary row per file in wards/, in ID order. IDs are permanent: never renumber or
     reuse one. Retired IDs stay listed under Retired. -->

## Summary

| ID | Name | Human review |
|----|------|--------------|

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
~~~

## The index

- **Summary**: one row per ward file, in ID order, linking to it:
  `| [WARD-001](wards/WARD-001.md) | <name> | No |`. Human review is `Yes` or `No`.
- **Retired**: one row per retired ID, saying what happened to it.

## Ward files

Each ward is `.warden/wards/WARD-NNN.md`: a heading with its ID and name, then seven fields.

~~~markdown
# WARD-NNN: <imperative name, e.g. "Bound every query that can return many rows">

**Description:** <one or two sentences: the problem this ward prevents>

**Rationale:** <why it matters: what goes wrong, and what it costs, when it's violated>

**Violations:**

```php
// realistic code that violates the ward
```

<one line: why it violates>

**Compliant examples:**

```php
// realistic code that satisfies the ward, in its simplest form
```

**Verification:**

1. <a step a reviewer performs; the exact command when a command can decide it>
2. <…>

- PASS when <observable condition>.
- FAIL when <observable condition>.

**Applicability:** <the code and kinds of change this ward applies to, and explicit exceptions>

**Human review:** Not required
~~~

| Field | What makes it good |
|---|---|
| Name (in the heading) | Imperative, under ten words, naming the principle rather than one instance. |
| Description | The problem the ward prevents, in plain words. |
| Rationale | The concrete cost of a violation: bugs, outages, coupling, review time. |
| Violations | One to three realistic examples in this repository's languages and frameworks, each with a line on why it violates. Prefer a trimmed version of the real code that prompted the ward. |
| Compliant examples | The matching acceptable solutions, in their simplest form: never more elaborate than the problem needs. |
| Verification | Steps that lead two reviewers to the same verdict, ending in explicit PASS and FAIL conditions. Give the exact command for anything a command can decide; for judgment calls, say what to inspect and what evidence settles it. |
| Applicability | Enough to mark the ward N/A with confidence: which files, layers or kinds of change, and the exceptions. |
| Human review | `Not required`, or `Required:` followed by the question a person must answer, when an agent can't settle the ward from the code alone (product or UX judgment, security or data-risk trade-offs, domain facts the code doesn't contain). |

## What makes a good ward

- **One concern**, judged on its own. A verdict never depends on another ward.
- **Decidable.** Two reviewers given the same code reach the same result.
- **The principle, not the instance.** "Bound queries that can return unbounded rows", not "add a
  limit to `UserController::index`", and not "write efficient code".
- **Not already automated.** If a linter, formatter, type checker or test in this repository
  already enforces it, configure that tool instead. A ward earns its place when it needs judgment
  a tool can't make.
- **No ceremony.** A ward that pushes people toward extra layers, abstractions or boilerplate
  without a concrete benefit is a bad ward.

## IDs

- Format `WARD-NNN`, zero-padded to three digits (`WARD-1000` follows `WARD-999`).
- The next ID is one more than the highest ID ever used: in a ward file, the Summary or Retired.
- An ID is never renumbered or reused, and keeps its meaning. Clarifying or tightening a ward
  keeps its ID; changing what it's about retires the ID and starts a new one.

## Retiring a ward

When a ward is merged into another, replaced or removed: delete its file, remove its Summary row,
and add a Retired row: `| WARD-004 | Former name | Merged into WARD-002 |`, or
`Replaced by WARD-009`, or `Removed: enforced by eslint no-console`.

## Consistency

A registry is consistent when:

1. Every Summary row links to an existing ward file, and every ward file has a Summary row with
   the same name and Human review value.
2. Each ward file's name matches the ID in its heading.
3. No ID appears twice, and no active ID is also listed as retired.
4. Every ward file has its heading and all seven fields.
5. Summary rows are in ID order.

When you change the registry, touch only the files and rows the change needs, and leave the rest
exactly as it was.
