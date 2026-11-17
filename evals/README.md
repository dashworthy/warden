# warden evals

Behavioral eval suite for the warden plugin, run with the native `claude plugin eval` harness. Each case
builds a small git repository with `scaffold.sh`, runs one prompt, and is scored by the files in `graders/`
against a no-plugin baseline, so every number says what warden adds over plain Claude.

## The cases

**`/record-ward`**

| Case | Measures |
|---|---|
| `record-new-ward-creates-registry` | Drafts WARD-001 in full with an example, self-tests it with the ward-tester, says `.warden/` will be created, and writes nothing before approval. |
| `record-extends-existing-ward` | Extends the existing WARD-001 instead of adding a near-duplicate ward. |
| `record-writes-concise-ward` | Turns a long, case-by-case request into a ward with one short sentence each for Description, Rationale and Applicability (no incident-by-incident retelling), at most two Verification steps and short code, whose rule still covers every listed case. Tracked, not a merge gate: it scores about 0.9, as drafts sometimes run a few words or lines over. |
| `record-rejects-linter-duplicate` | Declines a ward that ESLint's `no-console` rule already enforces. |

**`/audit-wards`**

| Case | Measures |
|---|---|
| `audit-finds-merge-and-conflict` | Self-tests every ward; recommends a merge naming the retained and retired IDs, and flags a real conflict with a resolution. |
| `audit-healthy-registry-no-churn` | Recommends no merges, removals or conflicts for a clean registry. |
| `audit-selftest-catches-bad-example` | The self-test catches an example whose expected fix violates its own ward. |
| `audit-flags-dead-paths` | Checks every glob with git and flags a ward whose paths match no file, proposing paths that cover the code. |

**`/check-wards`**

| Case | Measures |
|---|---|
| `check-reports-every-ward` | Dispatches the ward-checker; one table row per ward (FAIL / PASS / N/A, the N/A ward's paths matching no changed file), totals, overall FAIL, a file:line finding; edits nothing and never opens examples. |
| `check-runs-enforced-by-tests` | Runs each ward's `enforced-by` test: a failing test makes WARD-001 FAIL with a finding that cites it; a missing test file makes WARD-002 UNVERIFIED, not PASS. |
| `check-per-ward-dispatch` | `--per-ward` settles the path-N/A ward with git, gives each other ward its own checker naming only that ward, and merges one report with every row, totals and overall FAIL. |
| `check-empty-registry-unverified` | An empty registry reports UNVERIFIED, never PASS. |
| `check-fix-holds-human-review` | `--fix` corrects the finding that doesn't need human review, re-checks, and hands the human-review ward to the human untouched. |

**`/create-verify-skill`**

The verification cases scaffold `tally`, a dependency-free Node todo CLI with two ways to add todos
(`add` and `import <file>`) sharing one store. These cases really run it. It has no server because the
eval sandbox doesn't allow binding local ports, and the sandbox also write-protects `.claude/`, so
`create-writes-and-proves-skill` accepts a skill built and proved in a scratch copy with a copy command
handed over.

| Case | Measures |
|---|---|
| `create-writes-and-proves-skill` | Writes a verify skill (frontmatter; Launch, Doctor, Drive, Evidence, Cleanup from the repo's real commands), `features/README.md` and feature files with the four headings, then drives the CLI once against an isolated store, cleans up, and confirms the evidence survived. Never edits the app. |
| `create-defers-to-maintain` | A verify skill already exists: writes and edits nothing, and points to `/maintain-verify-skill`. |

**`/verify-change`**

| Case | Measures |
|---|---|
| `verify-without-skill-checks-by-hand` | With no verify skill, a plain-language request still fires the skill, runs the real `count` command against data it added, reports the commands and output, and mentions `/create-verify-skill` without creating one. |
| `verify-unmet-precondition-is-inconclusive` | The new `sync` command needs a token that isn't available: the verdict is inconclusive with the missing token named, never a pass, and product code is untouched. |
| `verify-drives-every-entry-point` | A change in shared code reaches both mapped entry points: drives `add` and `import` against an isolated store, reads each back, and reports both with evidence. Plain Claude also passes it today, so it guards against regressions rather than measuring lift. |

**`/maintain-verify-skill`**

| Case | Measures |
|---|---|
| `maintain-reports-product-bug-not-map` | A recent commit broke adding a todo. Reads every feature from source and drives every feature live, reports the failure as a product bug, and edits neither the product code nor the (correct) map entry. |
| `maintain-no-target-stops` | No verify skill: no subagents, no writes, and a pointer to `/create-verify-skill`. |

## How scoring is wired

- **`fired-*`**: on the plain-language prompts only, a `with-only` indicator that the model chose the skill (so it also tests triggering). Prompts that start with a slash command expand the skill directly, record no Skill call, and carry no `fired-*` grader.
- **`no-write` / `no-edit` / `no-example-reads` / `no-product-*`**: `tool_used` with `max: 0`: nothing is written before approval, checks stay report-only without `--fix`, verification never edits product code, and a check never opens ward examples.
- **`dispatches-checker` / `checks-and-rechecks` / `self-tests-*`**: scored on both arms. Verdicts come from the `ward-checker` subagent, self-tests from the `ward-tester`, and `--fix` re-checks with a fresh checker.
- **`row-*` / `totals` / `overall-*` / `never-pass` / `full-ward-draft`**: deterministic `regex` checks on the final message: the report's summary, and every field of a drafted ward.
- **LLM graders**: judge the proposal, report or final message against the case's expected outcome.

## Running

```
claude plugin eval . --scaffold --allow-tools Write,Edit,Bash --runs 1 -j 4
```

`--scaffold` runs each case's `scaffold.sh`; without it every case starts in an empty directory and fails. The verification cases need `node` on `PATH`. Results land in `evals/results/` (git-ignored).
