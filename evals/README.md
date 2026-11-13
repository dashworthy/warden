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
| `record-picks-pr-phase` | Drafts a "link the issue in every PR" ward with `phases: [pr]` and PR-description examples, not code. |
| `record-writes-concise-ward` | Turns a long, case-by-case request into a ward with one short sentence each for Description, Rationale and Applicability (no incident-by-incident retelling), at most two Verification steps and short code, whose rule still covers every listed case. |
| `record-rejects-linter-duplicate` | Declines a ward that ESLint's `no-console` rule already enforces. |

**`/audit-wards`**

| Case | Measures |
|---|---|
| `audit-finds-merge-and-conflict` | Self-tests every ward; recommends a merge naming the retained and retired IDs, and flags a real conflict with a resolution. |
| `audit-healthy-registry-no-churn` | Recommends no merges, removals or conflicts for a clean registry. |
| `audit-selftest-catches-bad-example` | The self-test catches an example whose expected fix violates its own ward. |
| `audit-flags-wrong-phase` | Flags a ward that governs PR descriptions but has no `phases` (so runs as a code ward), and recommends the `pr` phase. |
| `audit-flags-dead-paths` | Checks every glob with git and flags a ward whose paths match no file, proposing paths that cover the code. |

**`/check-wards`**

| Case | Measures |
|---|---|
| `check-reports-every-ward` | Dispatches the ward-checker; one table row per ward (FAIL / PASS / N/A, the N/A ward's paths matching no changed file), totals, overall FAIL, a file:line finding; edits nothing and never opens examples. |
| `check-runs-enforced-by-tests` | Runs each ward's `enforced-by` test: a failing test makes WARD-001 FAIL with a finding that cites it; a missing test file makes WARD-002 UNVERIFIED, not PASS. |
| `check-pr-phase` | `--phase pr` checks only pr wards against the branch's commits and a draft body: a bad commit subject fails, the issue link passes, the code ward is left out, and nothing is rewritten. |
| `check-pr-phase-fix-hands-over` | With `--fix`, a pr-phase check hands the commit-subject correction to the human: no amend, rebase, push or file edit. |
| `check-empty-phase-unverified` | A design check with no design wards reports UNVERIFIED, never PASS, and doesn't apply the code ward. |
| `check-design-phase` | `--phase design` checks a plan against the design ward: a missing rollback section fails with an actionable finding, and the code ward is left out. |
| `check-per-ward-dispatch` | `--per-ward` settles the path-N/A ward with git, gives each other ward its own checker naming only that ward, and merges one report with every row, totals and overall FAIL. |
| `check-empty-registry-unverified` | An empty registry reports UNVERIFIED, never PASS. |
| `check-fix-holds-human-review` | `--fix` corrects the finding that doesn't need human review, re-checks, and hands the human-review ward to the human untouched. |

## How scoring is wired

- **`fired-*`**: on the plain-language prompts only, a `with-only` indicator that the model chose the skill (so it also tests triggering). Prompts that start with a slash command expand the skill directly, record no Skill call, and carry no `fired-*` grader.
- **`no-write` / `no-edit` / `no-example-reads`**: `tool_used` with `max: 0`: nothing is written before approval, checks stay report-only without `--fix`, and a check never opens ward examples.
- **`dispatches-checker` / `checks-and-rechecks` / `self-tests-*`**: scored on both arms. Verdicts come from the `ward-checker` subagent, self-tests from the `ward-tester`, and `--fix` re-checks with a fresh checker.
- **`row-*` / `totals` / `overall-*` / `never-pass` / `full-ward-draft`**: deterministic `regex` checks on the final message: the report's summary, and every field of a drafted ward.
- **LLM graders**: judge the proposal, report or final message against the case's expected outcome.

## Running

```
claude plugin eval . --scaffold --allow-tools Write,Edit,Bash --runs 1 -j 4
```

`--scaffold` runs each case's `scaffold.sh`. Results land in `evals/results/` (git-ignored).
