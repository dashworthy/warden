# Rule registry format

The contract shared by `/record-rule`, `/audit-rules`, `/check-rules` and the warden agents. Rules
never live in the plugin: each repository owns its own registry.

## Location

Each repository keeps its registry in a `.warden/` directory at the repository root:

```
.warden/
├── .ignore                        hides examples/ folders from ripgrep-based searches
├── rules.md                       the index: one row per rule, plus the retired IDs
└── rules/
    ├── RULE-001/
    │   ├── rule.md                the rule
    │   └── examples/
    │       └── unbounded-list.md  a violating sample and the shape of its fix
    └── RULE-002/
        └── …
```

Root: `git rev-parse --show-toplevel`, else the current directory. The rule folders are the
source of truth; the index summarizes them. Never read or copy another repository's rules.

## Creating the registry

Create it only as part of a change a human approved. Write `.warden/rules.md` from this template
and `.warden/.ignore` with the line `rules/*/examples/`. Never add example or placeholder rules.

~~~markdown
# Rules

Engineering standards for this repository. Each rule is one enforceable standard with its own
folder in `rules/`, checked against every implementation slice by an independent reviewer.
Managed with the warden plugin: `/record-rule` adds a rule, `/audit-rules` consolidates them,
`/check-rules` verifies a slice.

<!-- One Summary row per folder in rules/, in ID order. IDs are permanent: never renumber or
     reuse one. Retired IDs stay listed under Retired. -->

## Summary

| ID | Name | Applies to | Human review |
|----|------|------------|--------------|

## Retired

| ID | Former name | Outcome |
|----|-------------|---------|
~~~

## The index

Summary rows, in ID order: `` | [RULE-001](rules/RULE-001/rule.md) | <name> | `src/handlers/**` | No | ``.
Applies to lists the paths in backticks, or `All` without any; Human review is `Yes` when the rule
has `human-review` questions. An agent about to edit a file reads every rule whose Applies to
matches it.

## Rule file

`.warden/rules/RULE-NNN/rule.md`: frontmatter, a heading, six fields. `source` and `decided` are
required; leave out optional keys that don't apply. Quote strings (an unquoted `#` starts a YAML
comment).

~~~markdown
---
source: '<who decided or what prompted the rule, e.g. "PR #142 review by Priya">'
decided: <YYYY-MM-DD>
until: '<optional: when a temporary rule stops holding, e.g. "the public launch">'
paths:
  - '<optional: where the rule applies, e.g. "src/handlers/**">'
human-review:
  - '<optional: a question a person must answer, e.g. "Is the error message clear to a customer?">'
enforced-by:
  - '<optional: a test file that checks the rule, e.g. "tests/arch/handlers.test.ts">'
---

# RULE-NNN: <imperative name, e.g. "Bound every query that can return many rows">

**Description:** <one sentence: what holds when the rule is followed>

**Rationale:** <one sentence: what a violation costs>

**Violations:**

```php
// the shortest realistic code that violates the rule
```

<one line: why it violates>

**Compliant examples:**

```php
// the same lines, fixed in their simplest form
```

**Verification:**

1. <the step that settles it; the exact command when a command can decide it>

- PASS when <observable condition>.
- FAIL when <observable condition>.

**Applicability:** <one sentence: the code and kinds of change it applies to, and any exception>
~~~

**Keep it short.** Aim for the length of the rule below: each field and Verification step one
short sentence (under about 25 words), the violation as few lines as show the problem, and the
compliant example those lines fixed. State the rule that covers the cases instead of listing them,
and name the kind of incident rather than each one; the reader can work them out.

An illustration of the length to aim for, not a rule to add:

~~~markdown
---
source: 'Review of PR #87 by the platform team'
decided: 2026-10-14
paths:
  - 'src/**'
---

# RULE-001: Avoid unnecessary abstractions

**Description:** Every interface, factory or service layer the code adds serves a real need for a second implementation.

**Rationale:** Each layer is more code to read, test and keep in step, and one with a single implementation buys nothing for it.

**Violations:**

```ts
class InvoiceNumberFactory { create() { return new DefaultInvoiceNumber() } } // its only implementation
```

A factory for one implementation that nothing else needs.

**Compliant examples:**

```ts
export const nextInvoiceNumber = () => `INV-${Date.now()}`
```

**Verification:**

1. For each abstraction the slice adds, find a second implementation, a test seam a test uses, or a documented extension point.

- PASS when every one has such a need.
- FAIL when one does not.

**Applicability:** Slices that add interfaces, abstract classes, factories or service wrappers, except contracts the framework requires.
~~~

| Key | Use |
|---|---|
| `source`, `decided` | Who decided or what prompted the rule, and when, so an audit can tell a decision from an inference. |
| `until` | The event or date that ends a temporary rule. |
| `paths` | The narrowest globs that cover the governed code. Leave out only for a rule that applies everywhere. |
| `human-review` | One question per entry, only when an agent can't settle the rule from the code. |
| `enforced-by` | Tests that check the rule; the checker runs them. A rule a tool enforces completely isn't a rule. |

The name is imperative and under ten words. Verification ends in PASS and FAIL conditions two
reviewers would agree on, with the exact command where a command can decide. Applicability says
what kinds of code the rule covers among the files its paths match, and the exceptions.

## Paths

Globs relative to the repository root, the same format as Claude Code's `.claude/rules/`. `*`
matches within one folder, `**` across any depth. No braces or `!`: git doesn't expand them, so put
exceptions in Applicability.

Git decides matching, never the eye. Paths match a slice when either command prints a file:

```bash
git diff --name-only <slice range> -- ':(glob)<path 1>' ':(glob)<path 2>'
git ls-files --others --exclude-standard -- ':(glob)<path 1>' ':(glob)<path 2>'
```

A rule whose paths match nothing is N/A. A glob is live when `git ls-files -- ':(glob)<path>'`
prints a file.

## Examples

One to three per rule in `examples/`, one Markdown file each, named for what it shows. The
rule-tester uses them as a blind before/after self-test; nothing else opens them.

~~~markdown
# <what the example shows, e.g. "Unbounded invoice list">

## Sample

```ts
// src/handlers/invoices.ts (excerpt)
<realistic code that violates the rule>
```

## Expected fix shape

- <what every correct fix must do>
- <what a correct fix leaves unchanged>

```ts
<one correct fix of the sample>
```
~~~

Vary the Sample from the rule's own Violations, keep it under about 40 lines, and put a path
inside the rule's paths on its first line.

## IDs

`RULE-NNN`, zero-padded to three digits. The next ID is one more than the highest ever used,
including retired ones. IDs are never reused: tightening a rule keeps its ID, changing its subject
retires it.

## Retiring a rule

Delete its folder and Summary row, and add a Retired row: `| RULE-004 | Former name | Merged into
RULE-002 |` (or `Replaced by RULE-009`, `Removed: <why>`).

## Consistency

1. Summary rows and rule folders match one to one, with the same name, Applies to and Human
   review, in ID order; each folder's name matches its heading's ID.
2. No ID appears twice or is both active and retired.
3. Every `rule.md` has `source`, `decided`, its heading and all six fields; every glob is live and
   uses only `*` and `**`; every `enforced-by` file is tracked.
4. Every rule has an example with a Sample, an Expected fix shape and fix code.
5. `.warden/.ignore` lists `rules/*/examples/`.

When you change the registry, touch only the files and rows the change needs, and leave the rest
exactly as it was.
