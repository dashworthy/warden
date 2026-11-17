# warden evals

Behavioral eval suite for the warden plugin, run with the native `claude plugin eval` harness. Each case
builds a small git repository with `scaffold.sh`, runs one prompt, and is scored by the files in `graders/`
against a no-plugin baseline, so every number says what warden adds over plain Claude.

## The cases

**`/record-rule`**

| Case | Measures |
|---|---|
| `record-new-rule-creates-registry` | Drafts RULE-001 in full with an example, self-tests it with the rule-tester, says `.warden/` will be created, and writes nothing before approval. |
| `record-extends-existing-rule` | Extends the existing RULE-001 instead of adding a near-duplicate rule. |
| `record-writes-concise-rule` | Turns a long, case-by-case request into a rule with one short sentence each for Description, Rationale and Applicability (no incident-by-incident retelling), at most two Verification steps and short code, whose rule still covers every listed case. Tracked, not a merge gate: it scores about 0.9, as drafts sometimes run a few words or lines over. |
| `record-rejects-linter-duplicate` | Declines a rule that ESLint's `no-console` rule already enforces. |

**`/audit-rules`**

| Case | Measures |
|---|---|
| `audit-finds-merge-and-conflict` | Self-tests every rule; recommends a merge naming the retained and retired IDs, and flags a real conflict with a resolution. |
| `audit-healthy-registry-no-churn` | Recommends no merges, removals or conflicts for a clean registry. |
| `audit-selftest-catches-bad-example` | The self-test catches an example whose expected fix violates its own rule. |
| `audit-flags-dead-paths` | Checks every glob with git and flags a rule whose paths match no file, proposing paths that cover the code. |

**`/check-rules`**

| Case | Measures |
|---|---|
| `check-reports-every-rule` | Dispatches the rule-checker; one table row per rule (FAIL / PASS / N/A, the N/A rule's paths matching no changed file), totals, overall FAIL, a file:line finding; edits nothing and never opens examples. |
| `check-runs-enforced-by-tests` | Runs each rule's `enforced-by` test: a failing test makes RULE-001 FAIL with a finding that cites it; a missing test file makes RULE-002 UNVERIFIED, not PASS. |
| `check-per-rule-dispatch` | `--per-rule` settles the path-N/A rule with git, gives each other rule its own checker naming only that rule, and merges one report with every row, totals and overall FAIL. |
| `check-empty-registry-unverified` | An empty registry reports UNVERIFIED, never PASS. |
| `check-fix-holds-human-review` | `--fix` corrects the finding that doesn't need human review, re-checks, and hands the human-review rule to the human untouched. |

## How scoring is wired

- **`fired-*`**: on the plain-language prompts only, a `with-only` indicator that the model chose the skill (so it also tests triggering). Prompts that start with a slash command expand the skill directly, record no Skill call, and carry no `fired-*` grader.
- **`no-write` / `no-edit` / `no-example-reads`**: `tool_used` with `max: 0`: nothing is written before approval, checks stay report-only without `--fix`, and a check never opens rule examples.
- **`dispatches-checker` / `checks-and-rechecks` / `self-tests-*`**: scored on both arms. Verdicts come from the `rule-checker` subagent, self-tests from the `rule-tester`, and `--fix` re-checks with a fresh checker.
- **`row-*` / `totals` / `overall-*` / `never-pass` / `full-rule-draft`**: deterministic `regex` checks on the final message: the report's summary, and every field of a drafted rule.
- **LLM graders**: judge the proposal, report or final message against the case's expected outcome.

## Running

```
claude plugin eval . --scaffold --allow-tools Write,Edit,Bash --runs 1 -j 4
```

`--scaffold` runs each case's `scaffold.sh`. Results land in `evals/results/` (git-ignored).
