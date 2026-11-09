![warden — Record, audit and enforce your engineering standards.](art/banner.svg)

# warden

A Claude Code plugin that keeps your repository's own engineering standards and enforces them on
every implementation slice. Each standard is a **ward**: one enforceable rule with examples and a
verification procedure, kept in a registry your repository owns.

| Skill | Does |
|---|---|
| `/record-ward` | Turns an instruction, PR comment or review finding into a ward. Checks for overlap, drafts examples and a verification procedure, and writes only after you approve. |
| `/audit-wards` | Reviews the whole registry for overlap, conflicts, ambiguity and overreach, and proposes merges that name the IDs retained and retired. Writes only what you approve. |
| `/check-wards` | Verifies a slice against every ward through an independent, read-only checker: PASS, FAIL, N/A or UNVERIFIED for each ward, actionable findings, and the items that need your review. |

Linters check syntax and style. Wards cover what they can't: architecture, engineering standards
and implementation quality.

## How a check works

```
/check-wards                            warden:ward-checker (new each run, read-only)
  scope the slice  ───────────────────▶   read .warden/, list every ward
  attach the previous report               PASS / FAIL / N/A / UNVERIFIED, with evidence
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
## Ward checks
- After each implementation slice, run `/check-wards` (`--fix` applies fixes that don't need human review).
- Fix every FAIL and UNVERIFIED finding, then run `/check-wards` again until it reports PASS.
- Bring me any human-review items, then stop for my approval before starting the next slice.
```

## The registry

Each repository keeps its wards in `.warden/`, which you commit with your code:

```
.warden/
├── wards.md          index: every ward (linked), whether it needs human review, retired IDs
└── wards/
    ├── WARD-001.md   one file per ward, named by its permanent ID
    └── WARD-002.md
```

The first approved `/record-ward` creates the directory and adds that ward; warden never invents
wards or copies them between repositories. IDs are permanent: merged or removed wards move to the
index's Retired table, and their numbers are never reused. A ward file looks like this (an
illustration, not something warden adds for you):

````markdown
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

**Human review:** Not required
````

Set **Human review** to `Required` for wards an agent can't settle from code alone, such as
product, UX or data-risk trade-offs. `/check-wards` still checks them, then lists them for you to
decide once it reports.

The full format is in [`shared/registry-format.md`](shared/registry-format.md).

## Structure

```
warden/
├── .claude-plugin/            plugin manifest and single-plugin marketplace
├── skills/
│   ├── record-ward/           /record-ward
│   ├── audit-wards/           /audit-wards
│   └── check-wards/           /check-wards: scope, dispatch, fix loop, human review
├── agents/ward-checker.md     the independent, read-only checker
├── shared/registry-format.md  registry location, template, ward format, IDs
└── evals/                     claude plugin eval cases for all three skills
```

## Credits

Banner helmet: [Warlord helmet](https://game-icons.net/1x1/caro-asercion/warlord-helmet.html) by
caro-asercion, from [game-icons.net](https://game-icons.net), licensed
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).

## License

[MIT](LICENSE)
