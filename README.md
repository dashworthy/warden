![warden — Enforce your standards and prove every change in the app.](art/banner.svg)

# warden

A Claude Code plugin that keeps your repository's own engineering standards, enforces them on
every implementation slice, and proves each change works in the running app. Each standard is a
**ward**: one enforceable rule with examples and a verification procedure, kept in a registry your
repository owns. Each proof runs through a **verify skill**: a project-local recipe for launching
and driving your app, with a map of its features.

| Skill | Does |
|---|---|
| `/record-ward` | Turns an instruction, PR comment or review finding into a ward. Checks for overlap, drafts examples and a verification procedure, self-tests the draft, and writes only after you approve. |
| `/audit-wards` | Self-tests every ward and reviews the registry for overlap, conflicts, ambiguity, overreach and length, then proposes merges that name the IDs retained and retired. Writes only what you approve. |
| `/check-wards` | Verifies a slice against every ward through an independent, read-only checker: PASS, FAIL, N/A or UNVERIFIED for each ward, actionable findings, and the items that need your review. |
| `/create-verify-skill` | Reads the repo and writes `.claude/skills/verify-<app>/`: exact Launch, Doctor, Drive, Evidence and Cleanup sections, plus a feature map. Proves the generated skill once end to end before handing it over. |
| `/verify-change` | States a falsifiable finish condition, drives every mapped feature the change reaches in the running app, and reports pass, fail or inconclusive with commands and evidence paths. Claude also loads it on its own before calling a change done. |
| `/maintain-verify-skill` | Keeps the verify skill honest: one read-only source reader per feature, one live pass driving every feature, then `clean`, `changed` (one PR of proven map fixes) or `blocked`. Never edits product code. |

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
- `--per-ward` gives each ward its own checker, run in parallel, and merges their rows into one
  report. Each ward gets a checker's full attention, at one checker run per ward; wards whose
  `paths` match nothing are N/A without one.

## How verification works

Wards check the code. Verification checks the app: "it compiles" is not evidence.

```
/create-verify-skill ──▶ .claude/skills/verify-<app>/       (commit it)
                           SKILL.md   Launch · Doctor · Drive · Evidence · Cleanup · Helpers
                           features/  README.md + one file per user-facing feature
                                │
       every change ──────▶ /verify-change ─────────▶ pass | fail | inconclusive + evidence
                                │
       app drifts ────────▶ /maintain-verify-skill ─▶ clean | changed (1 PR) | blocked
```

- Each feature file lists every way a user reaches the feature, how to drive it, and the
  observable end state that proves it works. A proof through one convenient entry point doesn't
  cover the others.
- Evidence (screenshots, ARIA snapshots, transcripts, read-back values, side effects) lands in a
  location the verify skill names and survives cleanup.
- A check that can't run is **inconclusive**, never a pass, and a journey is never weakened to
  make it pass.

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
/check-wards --per-ward
/create-verify-skill
/verify-change the bulk-archive action; show screenshots as proof
/maintain-verify-skill
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

## Verification
- Before calling a change done, run `/verify-change` and show the evidence. Inconclusive is not done.
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
│   ├── check-wards/           /check-wards: scope, dispatch, fix loop, human review
│   ├── create-verify-skill/   /create-verify-skill, with a worked feature-map example
│   ├── verify-change/         /verify-change
│   └── maintain-verify-skill/ /maintain-verify-skill
├── agents/
│   ├── ward-checker.md        the independent, read-only checker
│   └── ward-tester.md         the before/after self-test, isolated from your conversation
├── shared/registry-format.md  registry location, templates, ward and example formats, IDs
└── evals/                     claude plugin eval cases for the ward skills
```

## Credits

The verification skills are adapted from [pstack](https://github.com/cursor/plugins/tree/main/pstack)
by Lauren Tan (MIT): `create-verification-skill`, `maintain-verification-skill`, the prove-it-works
principle and the verify-and-ship guide, rewritten for Claude Code.

Banner helmet: [Warlord helmet](https://game-icons.net/1x1/caro-asercion/warlord-helmet.html) by
caro-asercion, from [game-icons.net](https://game-icons.net), licensed
[CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).

## License

[MIT](LICENSE)
