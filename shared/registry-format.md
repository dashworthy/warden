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

| ID | Name | Phases | Applies to | Human review |
|----|------|--------|------------|--------------|

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
~~~

## The index

- **Summary**: one row per ward folder, in ID order, linking to its ward file:
  `` | [WARD-001](wards/WARD-001/ward.md) | <name> | code | `src/handlers/**` | No | ``. Phases
  lists the ward's phases, separated by commas (`code` when it has none). Applies to lists its
  paths, each in backticks and separated by commas, or `All` when the ward has none. Human review
  is `Yes` when the ward lists `human-review` questions, otherwise `No`.
- **Retired**: one row per retired ID, saying what happened to it.

The Summary doubles as a lookup: an agent about to edit a file opens every ward whose Applies to
matches the file's path, so it knows the standards before it writes code, not only when the slice
is checked.

## Ward file

Each ward is `.warden/wards/WARD-NNN/ward.md`: YAML frontmatter, a heading with its ID and name,
then six fields. The frontmatter holds what tools act on directly; the body holds what a reviewer
reads and judges. `source` and `decided` are required; leave out any optional key that doesn't
apply. Quote string values (`'PR #142'`: an unquoted `#` starts a YAML comment).

~~~markdown
---
source: '<who decided or what prompted the ward, e.g. "PR #142 review by Priya">'
decided: <YYYY-MM-DD>
until: '<optional: when a temporary ward stops holding, e.g. "the public launch">'
phases:
  - '<optional: design, code or pr; absent means code>'
paths:
  - '<optional: where the ward applies, e.g. "src/handlers/**">'
human-review:
  - '<optional: a question a person must answer, e.g. "Is the error message clear to a customer?">'
enforced-by:
  - '<optional: a test file that checks the ward, e.g. "tests/arch/handlers.test.ts">'
---

# WARD-NNN: <imperative name, e.g. "Bound every query that can return many rows">

**Description:** <one sentence: what holds when the ward is followed>

**Rationale:** <one sentence: what a violation costs>

**Violations:**

```php
// the shortest realistic code that violates the ward
```

<one line: why it violates>

**Compliant examples:**

```php
// the same code, fixed in its simplest form
```

**Verification:**

1. <the step that settles it; the exact command when a command can decide it>

- PASS when <observable condition>.
- FAIL when <observable condition>.

**Applicability:** <one sentence: the code and kinds of change it applies to, and any exception>
~~~

**Keep it short.** Write each field as one short sentence where you can (under about 25 words),
and each example in as few lines as show the problem (one line with a comment is often enough).
State the principle and the evidence that settles it, and trust the reader to work out the cases:
don't pack them into the sentence as a list, and don't retell the incident. A ward a person takes
in at a glance is one an agent applies consistently. Add a sentence, a step or an example only when
it carries something the others can't, such as a command that decides the ward or a different way
to violate it.

| Field | What makes it good |
|---|---|
| `source`, `decided` | Who decided or what prompted the ward (a person's instruction, a PR or review comment, an incident) and the ISO date, so an audit can tell a human decision from an inference and see how old the ward is. |
| `until` | Only for a ward that holds for a while: the event or date that ends it, e.g. "the public launch". An audit asks the human whether it has passed. |
| `phases` | When in the workflow the ward is checked (see Phases). Leave it out for a code-review ward. |
| `paths` | The narrowest globs that cover where the code the ward governs lives (see Paths). Leave `paths` out only for a ward that genuinely applies anywhere in the repository. |
| `human-review` | One question per entry that a person must answer, listed only when an agent can't settle the ward from the code alone (product or UX judgment, security or data-risk trade-offs, domain facts the code doesn't contain). Leave `human-review` out when an agent can decide. |
| Name (in the heading) | Imperative, under ten words, naming the principle rather than one instance. |
| Description | The rule in one sentence, stated as what holds: "Every query that can return many rows has a limit." |
| Rationale | The concrete cost of a violation in one sentence, naming the incident that prompted the ward (when there was one) in a few words. |
| Violations | Usually one realistic example in this repository's languages and frameworks, as short as shows the problem, with a line on why it violates. Prefer a trimmed version of the real code that prompted the ward; add a second only for a different way to violate it. |
| Compliant examples | The same code fixed, in its simplest form: never more elaborate than the problem needs. |
| Verification | As few steps as settle it, often one, ending in one PASS and one FAIL condition that lead two reviewers to the same verdict. Give the exact command for anything a command can decide; for judgment calls, say what to inspect and what evidence settles it. |
| Applicability | One sentence that's enough to mark the ward N/A with confidence among the files its paths match: which kinds of code or change, and the exceptions. Paths say where; Applicability says what. |
| `enforced-by` | Test files in this repository that check all or part of the ward, such as an architecture test. The checker runs them; the body still says what the ward requires and why, so an agent can comply before a test fails. A ward that a test or tool enforces completely, with nothing for an agent to learn from it, is not a ward. |

## Phases

A ward belongs to one or more phases, and `/check-wards --phase <phase>` checks only that phase's
wards against that phase's input. The phases are fixed:

| Phase | Checked | Input the checker reads | Example ward |
|---|---|---|---|
| `design` | Before implementation, on a plan or design document | The document the caller names | "Every plan states how the change is rolled back" |
| `code` | After each implementation slice (the default) | The diff and untracked files | "Bound every query that can return many rows" |
| `pr` | Before opening or merging a pull request | The PR's title, body, labels and commits (or the branch's commits and a draft title and body when there's no PR yet), and its diff stats | "Every PR body links its issue" |

- A ward without `phases` is a `code` ward.
- Write a ward's Violations, Compliant examples and example Samples in its phase's medium: plan
  excerpts for `design`, code for `code`, PR titles, bodies or commit messages for `pr`.
- `paths` narrows `code` and `pr` wards by the files the change touches. `design` checks skip the
  paths step, because the files a plan describes may not exist yet; Applicability decides there.

## Paths

A ward's `paths` frontmatter lists the files it governs, as globs relative to the repository root.
It's the same frontmatter that Claude Code's `.claude/rules/` and Laravel Boost's `.ai/rules/` use.

- `*` matches within one folder level; `**` matches any number of levels (`src/**` is everything
  under `src/`, `app/**/Requests/*.php` is the PHP files directly in any `Requests` folder).
- Write one entry per glob. No braces (`{a,b}`) and no negation (`!`): git doesn't expand them, so
  they would match nothing. Put exceptions in Applicability.
- Pick the narrowest globs that cover where the code actually lives (`app/Http/Controllers/**`,
  not `app/**`). A ward without `paths` applies to every file; that should be rare.
- Matching is decided by git, never by eye. A path set matches a slice when either command prints
  a file:

  ```bash
  git diff --name-only <slice range> -- ':(glob)<path 1>' ':(glob)<path 2>'
  git ls-files --others --exclude-standard -- ':(glob)<path 1>' ':(glob)<path 2>'
  ```

  and a glob is live when `git ls-files -- ':(glob)<path>'` prints at least one file.
- A ward whose paths match no file in the slice is N/A without further judgment. When they match,
  its Applicability decides.

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
- **Keep it in scope**: for a `code` ward, the path in the Sample's first-line comment matches the
  ward's paths. For `design` and `pr` wards, the first line names what the sample is (a plan
  file, a PR title and body, a commit message).
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
   the same name, Phases, Applies to and Human review value.
2. Each folder's name matches the ID in its `ward.md` heading.
3. No ID appears twice, and no active ID is also listed as retired.
4. Every `ward.md` has `source`, a `decided` date, its heading and all six fields; its `paths`, if
   any, use only `*` and `**` and each match at least one tracked file; its `human-review`, if any,
   lists at least one question; its `phases`, if any, name only `design`, `code` or `pr`; and every
   `enforced-by` file is tracked.
5. Every ward has at least one example with a Sample, an Expected fix shape and fix code, and each
   Sample's path matches the ward's paths.
6. Summary rows are in ID order, and `.warden/.ignore` lists `wards/*/examples/`.

When you change the registry, touch only the files and rows the change needs, and leave the rest
exactly as it was.
