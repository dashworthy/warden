![warden — Record, audit and enforce your engineering standards.](art/banner.svg)

# warden

A Claude Code plugin that keeps your repository's own engineering standards and enforces them at
each phase of the work: on plans, on every implementation slice, and on pull requests. Each standard is a **ward**: one enforceable rule with examples and a
verification procedure, kept in a registry your repository owns.

| Skill | Does |
|---|---|
| `/record-ward` | Turns an instruction, PR comment or review finding into a ward. Checks for overlap, drafts examples and a verification procedure, self-tests the draft, and writes only after you approve. |
| `/audit-wards` | Self-tests every ward and reviews the registry for overlap, conflicts, ambiguity, overreach and length, then proposes merges that name the IDs retained and retired. Writes only what you approve. |
| `/check-wards` | Verifies a plan, a slice or a PR against that phase's wards through an independent, read-only checker: PASS, FAIL, N/A or UNVERIFIED for each ward, actionable findings, and the items that need your review. |

Linters check syntax and style. Wards cover what they can't: architecture, engineering standards,
implementation quality, and how plans and pull requests are written.

## Phases

Each ward belongs to a phase, set with `phases:` in its frontmatter (`code` when left out):

| Phase | Check with | Reads | Example ward |
|---|---|---|---|
| `design` | `/check-wards --phase design docs/plans/x.md` | a plan or design document | Every plan states how the change is rolled back |
| `code` | `/check-wards` | the diff | Bound every query that can return many rows |
| `pr` | `/check-wards --phase pr` | the PR's title, body, labels, commits and diff stats | Every PR body links its issue |

A check reports only its phase's wards. In the `pr` phase, `--fix` never edits the PR or rewrites
commits: it brings those corrections to you.

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
- `--per-ward` gives each ward its own checker, run in parallel, and merges their rows into one
  report. Each ward gets a checker's full attention, at one checker run per ward; wards whose
  `paths` match nothing are N/A without one.

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
/check-wards --phase design docs/plans/invoices.md
/check-wards --phase pr
/check-wards --per-ward
```

## Add it to your workflow

Paste into the project's `CLAUDE.md` or `AGENTS.md`:

```markdown
## Wards
- Before planning or editing a file, open `.warden/wards.md` and read every ward whose Applies to
  matches the file's path (`All` matches every path). Then grep `.warden/wards` for the feature's
  key terms to catch wards a path match misses. Follow them as you write the code.
- Before implementing a plan, run `/check-wards --phase design <plan file>` and revise the plan
  until it passes.
- After each implementation slice, run `/check-wards` (`--fix` applies fixes that don't need human review).
- Fix every FAIL and UNVERIFIED finding, then run `/check-wards` again until it reports PASS.
- Bring me any human-review items, then stop for my approval before starting the next slice.
- Before opening a pull request, run `/check-wards --phase pr` with the draft title and body.
```

## The registry

Each repository keeps its wards in `.warden/`, which you commit with your code:

```
.warden/
├── .ignore                        keeps examples out of code searches
├── wards.md                       index: every ward (linked), its phases, the paths it
│                                  applies to, human-review flag, retired IDs
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

**Description:** Every interface, factory or service layer the code adds serves a real need for a
second implementation.

**Rationale:** Each layer is more code to read, test and keep in step, and one with a single
implementation buys nothing for it.

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

1. For each abstraction the slice adds, find a second implementation, a test seam a test uses, or
   a documented extension point.

- PASS when every one has such a need.
- FAIL when one does not.

**Applicability:** Slices that add interfaces, abstract classes, factories or service wrappers,
except contracts the framework requires.
````

Each field is one sentence where it can be. A ward a person takes in at a glance is one an agent
applies consistently, so warden states the rule and trusts the reader with the cases.

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
