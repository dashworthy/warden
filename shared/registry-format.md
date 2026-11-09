# Ward registry format

The contract shared by `/record-ward`, `/audit-wards`, `/check-wards` and the warden agents. Wards
never live in the plugin: each repository owns its own registry.

## Location

Each repository keeps its registry in a `.warden/` directory at the repository root:

```
.warden/
├── .ignore                        hides examples/ folders from ripgrep-based searches
├── wards.md                       the index: one row per ward, plus the retired IDs
└── wards/
    ├── WARD-001/
    │   ├── ward.md                the ward
    │   └── examples/
    │       └── unbounded-list.md  a violating sample and the shape of its fix
    └── WARD-002/
        └── …
```

- Root: `git rev-parse --show-toplevel`; outside a git repository, the current working directory.
- No other path is searched, and there is no configuration file.
- The ward folders are the source of truth for which wards exist; the index summarizes them.
- Wards never cross repositories. Don't read, copy or suggest another repository's wards unless
  the user asks.

## Creating the registry

Create the registry only as part of a change a human has approved (normally the first
`/record-ward`), or when a human explicitly asks for it. Write `.warden/wards.md` with exactly this
template and `.warden/.ignore` with the single line `wards/*/examples/`, then add the approved
ward's folder. A new registry holds no other wards: never add example, placeholder or speculative
ones.

~~~markdown
# Wards

Engineering standards for this repository. Each ward is one enforceable standard with its own
folder in `wards/`, checked against every implementation slice by an independent reviewer.
Managed with the warden plugin: `/record-ward` adds a ward, `/audit-wards` consolidates them,
`/check-wards` verifies a slice.

<!-- One Summary row per folder in wards/, in ID order. IDs are permanent: never renumber or
     reuse one. Retired IDs stay listed under Retired. -->

## Summary

| ID | Name | Human review |
|----|------|--------------|

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
~~~

## The index

- **Summary**: one row per ward folder, in ID order, linking to its ward file:
  `| [WARD-001](wards/WARD-001/ward.md) | <name> | No |`. Human review is `Yes` or `No`.
- **Retired**: one row per retired ID, saying what happened to it.

## Ward file

Each ward is `.warden/wards/WARD-NNN/ward.md`: a heading with its ID and name, then seven fields.

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

## Examples

Every ward has one to three examples in `.warden/wards/WARD-NNN/examples/`, one Markdown file each,
named for what it shows (`unbounded-list.md`). An example is a realistic violation plus the shape a
correct fix takes; the self-test uses it as a before/after check of the ward.

~~~markdown
# <what the example shows, e.g. "Unbounded invoice list">

## Sample

```ts
// src/handlers/invoices.ts (excerpt)
<realistic code that violates the ward>
```

## Expected fix shape

- <what every correct fix must do>
- <what a correct fix leaves unchanged>

```ts
<one correct fix of the sample>
```
~~~

- **Vary it.** Don't copy the ward's Violations and Compliant examples: write the code the way a
  real slice would, so the self-test shows the ward generalizes.
- **Keep it short**: an excerpt under about 40 lines, with only the context the ward needs.
- **Keep it out of checks.** Examples are deliberately bad code. `/check-wards` and the checker
  never read them, `.warden/.ignore` keeps them out of code searches, and only the ward-tester
  opens them.

## Self-test

The ward-tester (`agents/ward-tester.md`) runs a blind before/after check of one ward from its
examples: the sample should FAIL, the expected fix should PASS, and the sample with the checker's
recommended correction applied should PASS and match the expected fix shape. Fresh checkers judge
the code without seeing which case is meant to pass. It costs two checker runs per ward.

## IDs

- Format `WARD-NNN`, zero-padded to three digits (`WARD-1000` follows `WARD-999`).
- The next ID is one more than the highest ID ever used: as a ward folder, in the Summary or in
  Retired.
- An ID is never renumbered or reused, and keeps its meaning. Clarifying or tightening a ward
  keeps its ID; changing what it's about retires the ID and starts a new one.

## Retiring a ward

When a ward is merged into another, replaced or removed: delete its folder, remove its Summary row,
and add a Retired row: `| WARD-004 | Former name | Merged into WARD-002 |`, or
`Replaced by WARD-009`, or `Removed: enforced by eslint no-console`.

## Consistency

A registry is consistent when:

1. Every Summary row links to an existing ward folder, and every ward folder has a Summary row with
   the same name and Human review value.
2. Each folder's name matches the ID in its `ward.md` heading.
3. No ID appears twice, and no active ID is also listed as retired.
4. Every `ward.md` has its heading and all seven fields.
5. Every ward has at least one example with a Sample, an Expected fix shape and fix code.
6. Summary rows are in ID order, and `.warden/.ignore` lists `wards/*/examples/`.

When you change the registry, touch only the files and rows the change needs, and leave the rest
exactly as it was.
