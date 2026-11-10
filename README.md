![warden — Record, audit and enforce your engineering standards.](art/banner.svg)

# warden

A Claude Code plugin that keeps your repository's own engineering standards and enforces them on
every implementation slice. Each standard is a **ward**: one enforceable rule with examples and a
verification procedure, kept in a registry your repository owns.

| Skill | Does |
|---|---|
| `/record-ward` | Turns an instruction, PR comment or review finding into a ward. Checks for overlap, drafts examples and a verification procedure, self-tests the draft, and writes only after you approve. |
| `/audit-wards` | Self-tests every ward and reviews the registry for overlap, conflicts, ambiguity and overreach, then proposes merges that name the IDs retained and retired. Writes only what you approve. |
| `/check-wards` | Verifies a slice against every ward through an independent, read-only checker: PASS, FAIL, N/A or UNVERIFIED for each ward, actionable findings, and the items that need your review. |

Linters check syntax and style. Wards cover what they can't: architecture, engineering standards
and implementation quality.

## How a check works

```
/check-wards                            warden:ward-checker (new each run, read-only)
  scope the slice  ───────────────────▶   read .warden/, list every ward
  attach the previous report               paths match no changed file → N/A (git decides)
                                           PASS / FAIL / N/A / UNVERIFIED, with evidence
                                           re-verify each earlier finding itself
  hand the report to the implementer ◀──   summary table, findings, human-review items
  fix → /check-wards again
  PASS → human-review items → your approval
```

- The checker has no edit tools, so it can't change the code it judges.
- It never receives "I fixed it" claims, only the previous report, and confirms each fix in the code.
- An empty registry reports **UNVERIFIED**, never PASS.
- `--fix` applies the corrections that don't need human review and re-checks, up to three rounds.

## Install

```
/plugin marketplace add dashworthy/warden
/plugin install warden@warden
```

## Usage

```
/record-ward PR feedback: list endpoints keep loading every row; always paginate
/audit-wards
/check-wards
/check-wards --fix main..HEAD
```

## Add it to your workflow

Paste into the project's `CLAUDE.md` or `AGENTS.md`:

```markdown
## Wards
- Before planning or editing a file, open `.warden/wards.md` and read every ward whose Applies to
  matches the file's path (`All` matches every path). Then grep `.warden/wards` for the feature's
  key terms to catch wards a path match misses. Follow them as you write the code.
- After each implementation slice, run `/check-wards` (`--fix` applies fixes that don't need human review).
- Fix every FAIL and UNVERIFIED finding, then run `/check-wards` again until it reports PASS.
- Bring me any human-review items, then stop for my approval before starting the next slice.
```

## The registry

Each repository keeps its wards in `.warden/`, which you commit with your code:

```
.warden/
├── .ignore                        keeps examples out of code searches
├── wards.md                       index: every ward (linked), the paths it applies to,
│                                  human-review flag, retired IDs
└── wards/
    └── WARD-001/                  one folder per ward, named by its permanent ID
        ├── ward.md                the ward
        └── examples/
            └── unbounded-list.md  a violating sample and the expected fix shape
```

The first approved `/record-ward` creates the directory and adds that ward; warden never invents
wards or copies them between repositories. IDs are permanent: merged or removed wards move to the
index's Retired table, and their numbers are never reused. A `ward.md` looks like this (an
illustration, not something warden adds for you):

````markdown
---
source: 'Review of PR #87 by the platform team'
decided: 2026-10-14
paths:
  - 'src/**'
---

# WARD-001: Avoid unnecessary abstractions

**Description:** Interfaces, factories and service layers added for single-use functionality add
complexity without providing reuse.

**Rationale:** Every layer is more code to read, test and keep in step. An abstraction with one
implementation and no demonstrated need for another costs that and buys nothing.

**Violations:**

```ts
interface InvoiceNumberGenerator { next(): string }
class DefaultInvoiceNumberGenerator implements InvoiceNumberGenerator {
  next() { return `INV-${Date.now()}` }
}
class InvoiceNumberGeneratorFactory {
  create(): InvoiceNumberGenerator { return new DefaultInvoiceNumberGenerator() }
}
```

An interface and a factory for one implementation that nothing else needs.

**Compliant examples:**

```ts
export function nextInvoiceNumber(): string {
  return `INV-${Date.now()}`
}
```

**Verification:**

1. List the interfaces, abstract classes, factories and wrapper services the slice adds.
2. For each, count implementations and look for the requirement it serves: a second
   implementation, a test seam a test actually uses, or a documented extension point.

- PASS when every new abstraction serves such a requirement.
- FAIL when one has a single implementation and no such requirement.

**Applicability:** Slices that add interfaces, abstract classes, factories or service wrappers.
Exception: contracts the framework requires.
````

The `paths` frontmatter, the same format as Claude Code's `.claude/rules/` and Laravel Boost's
`.ai/rules/`, scopes the ward to the files it governs. The checker matches it against the slice
with `git diff -- ':(glob)…'`, so a ward whose paths match no changed file is N/A without anyone
interpreting its text, and the index's Applies to column lets an agent find the wards for a file
before it edits it. Leave `paths` out for a ward that applies everywhere. `source` and `decided`
record who decided the ward and when, so an audit can tell a decision from an inference; add
`until` for a temporary ward, and an audit will ask whether its time is up.

When a test already checks a ward (an architecture test, say), list it under `enforced-by` and the
checker runs it:

```yaml
enforced-by:
  - 'tests/Unit/Architecture/FormRequestsMustNotAbortTest.php'
```

Add a `human-review` list to the frontmatter, one question per entry, for wards an agent can't
settle from code alone, such as product, UX or data-risk trade-offs:

```yaml
human-review:
  - 'Is the confirmation wording clear to a customer about exactly what will be lost?'
```

Leave it out, like `paths`, when it doesn't apply. `/check-wards` still checks them, then lists them for you to
decide once it reports.

### Examples and self-tests

Each ward keeps one to three examples: a realistic violating **sample** and the **expected fix
shape**, the requirements any correct fix meets plus one fix in code. They power a before/after
self-test that `/record-ward` runs on every draft and `/audit-wards` runs on every ward:

| Example | Before (sample) | Expected fix | After (applied fix) | Matches fix shape |
|---|---|---|---|---|
| unbounded-list | FAIL ✓ | PASS ✓ | PASS ✓ | ✓ |

The sample must fail, the expected fix must pass, and the sample with the checker's recommended
correction applied must pass and match the fix shape. A ✗ points at a loose or ambiguous ward, or
a wrong example, before it gives flaky verdicts on real slices.

Examples are deliberately bad code, so warden keeps them away from everything else:

- `/check-wards` and the checker read only `ward.md`, never the examples.
- Self-tests run in a separate `ward-tester` subagent, so example code never enters your
  conversation, and an audit runs one tester per ward.
- Fresh checkers judge the code cases blind: shuffled, unlabeled, without the expected fix shape.
- `.warden/.ignore` hides the `examples/` folders from ripgrep-based searches (including Claude
  Code's Grep), so agents searching your code don't trip over the samples.

The full format is in [`shared/registry-format.md`](shared/registry-format.md).

## Structure

```
warden/
├── .claude-plugin/            plugin manifest and single-plugin marketplace
├── skills/
│   ├── record-ward/           /record-ward
│   ├── audit-wards/           /audit-wards
│   └── check-wards/           /check-wards: scope, dispatch, fix loop, human review
├── agents/
│   ├── ward-checker.md        the independent, read-only checker
│   └── ward-tester.md         the before/after self-test, isolated from your conversation
├── shared/registry-format.md  registry location, templates, ward and example formats, IDs
└── evals/                     claude plugin eval cases for all three skills
```

## Credits

Banner helmet: [Warlord helmet](https://game-icons.net/1x1/caro-asercion/warlord-helmet.html) by
caro-asercion, from [game-icons.net](https://game-icons.net), licensed
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).

## License

[MIT](LICENSE)
