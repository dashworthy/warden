---
name: check-wards
description: "Verify an implementation slice, a design or plan document, or a pull request against the matching phase's wards (enforceable engineering standards) in this repository's ward registry, .warden/, through an independent read-only checker subagent. Returns a PASS / FAIL / N/A / UNVERIFIED summary covering every ward in that phase, actionable findings, and the items that need human review. Use after finishing an implementation slice and before asking for human approval, on a plan before implementing it (--phase design), before opening or merging a PR (--phase pr), when re-verifying fixes to earlier findings, or whenever asked to check changes against the project's wards or standards. Pass --fix to apply corrections that don't need human review and re-check automatically. Pass --per-ward to give each ward its own checker subagent, run in parallel, for large registries or when each ward needs a checker's full attention. Not for running tool linters such as ESLint, PHPStan or Ruff."
argument-hint: "[--phase design|code|pr] [--fix] [--per-ward] [scope: commit range, paths, plan file, or PR]"
---

# Check wards

Verifies one input against every ward in one phase: a plan or design document (`design`), an
implementation slice (`code`, the default), or a pull request (`pr`). The verdict comes from the
`warden:ward-checker` subagent: a fresh, read-only reviewer that didn't write the code. In this
context you scope the input, dispatch the checker, hand its report back unchanged, and drive the
fix loop.

**Arguments:** `--phase design|code|pr` picks the phase, `code` by default. `--fix` turns on
automatic fixes (step 5). `--per-ward` gives each ward its own checker (step 2). Anything else is
the scope: a commit range (`main..HEAD`), paths or a
slice description for `code`; the document for `design`; a PR number or branch for `pr`.

## 1. Scope the input

Phases are defined in `${CLAUDE_PLUGIN_ROOT}/shared/registry-format.md`.

**`design`:** the plan or design documents the caller names; otherwise the plan the task names, or
the one this conversation just produced, passed to the checker as text. With no plan, say a design
check needs one and stop.

**`pr`:** the PR the caller names, else the current branch's. When
`gh pr view [<number>] --json number,title,body,labels,commits,additions,deletions,changedFiles,baseRefName`
finds one, that's the input. Otherwise take the branch against its base (item 3 below): its
commits from `git log --format='%h %s%n%n%b' <base>..HEAD`, `git diff --stat <base>...HEAD`, and
any draft title and body the caller gives.

**`code`:** use the first that applies:

1. The scope the caller gave.
2. Uncommitted changes: `git diff HEAD`, plus untracked files from
   `git ls-files --others --exclude-standard`.
3. The branch against its base: `git diff "$(git merge-base HEAD origin/HEAD)"...HEAD`, falling
   back to `main` or `master`.

Leave `.warden/` out of the input: the registry isn't implementation code. If nothing is left in
scope, say so and stop.

Write a **scope brief**: the phase; the input (for `design`, the document paths or text; for `pr`,
the commands that reproduce the PR data and any draft title and body; for `code`, the command that
reproduces the diff and the changed files, with untracked files listed separately because
`git diff` doesn't show them); and one or two factual sentences on what the change is meant to do
(from the task or plan). Keep it to facts: no claims that the code is correct or that anything was
fixed.

## 2. Dispatch the checker

Dispatch `warden:ward-checker`, a new instance for every check, with:

- the scope brief, which names the phase;
- the registry location, `<repo root>/.warden/`;
- on a re-check, the previous report verbatim, and nothing the implementer said about fixing it.

If the `warden:ward-checker` agent type isn't available, dispatch a general-purpose agent instead:
give it the instructions in `${CLAUDE_PLUGIN_ROOT}/agents/ward-checker.md` (everything below the
frontmatter) with the items above, and tell it never to edit files.

### With `--per-ward`

Each ward gets its own fresh checker, so it has the checker's whole context and attention, and one
ward's reasoning can't bleed into another's. It costs one checker run per dispatched ward instead
of one in total.

1. **List the phase's wards.** Read only the frontmatter of each `wards/WARD-NNN/ward.md`, and keep
   the wards in the scope brief's phase (a ward without `phases` is a `code` ward). With none, run
   the single checker as above: it returns the no-wards report.
2. **Settle paths with git.** For `code` and `pr`, run the paths step from the registry format for
   each ward with `paths`. A ward whose paths match no file in the input is **N/A**: git decided
   that, so it needs no checker. Don't judge anything else here.
3. **Confirm the cost.** With more than 10 wards left to dispatch, say how many checker runs the
   check needs and ask before starting (with no human to ask, run them).
4. **Dispatch one checker per remaining ward**, all in one message so they run in parallel. Give
   each the items above plus "Check only WARD-NNN", naming that ward and no other, and on a
   re-check only that ward's rows and findings from the previous report.
5. **Merge the reports** into one report in the checker's format, in ID order:
   - one summary row per ward: each checker's row exactly as returned, and an N/A row for each
     ward settled by paths;
   - totals counted from those rows, and **Overall: PASS** only when every row is PASS or N/A and
     every earlier finding is Resolved;
   - each checker's Earlier findings, Findings and Human review entries copied unchanged, and its
     Registry issues listed once each.

   Merging is assembly, not judgment: don't reword, re-rank or overrule a checker's result. A
   checker that returns no usable report makes its ward UNVERIFIED.

Re-checks in the fix loop (steps 4 and 5) use `--per-ward` again, across every ward in the phase:
a fix for one ward can break another.

Don't evaluate wards in this context: you may have written the code, and the point is an
independent verdict. If you can't dispatch a subagent here (for example, you're a subagent at the
nesting limit), stop and return "Independent ward check required for <scope>" to your caller.

## 3. Hand back the report

Relay the checker's report exactly as returned: don't trim, soften, re-rank or re-judge it. When an
implementation subagent built the slice, give it the report verbatim (continue it, or re-dispatch
it with the report) so it can resolve the findings.

When the report finds no wards to check (none in the registry, or none in this phase), relay it and
stop. Don't judge the input yourself against other phases' wards, and don't suggest adding a phase
to a ward whose Verification can't inspect that phase's input; point to `/record-ward` instead.

## 4. Resolve and re-check

The implementer owns the fixes:

1. Fix every FAIL and clear every UNVERIFIED blocker, except FAILs on wards that require human
   review: those wait for the human (step 6).
2. If a finding looks wrong or a ward is ambiguous, don't skip it: raise the disagreement with the
   human, quoting the finding and the ward.
3. Run `/check-wards` again with the previous report. The new checker confirms every earlier
   finding from the code itself.

Repeat until the overall result is PASS. A finding that survives two fix attempts, or that's
disputed, goes to the human instead of another loop.

## 5. With `--fix`

After each report, apply the **Recommended correction** of every FAIL finding on a ward without
`human-review` questions, then re-check with a fresh checker and the previous report. Stop when no
such FAIL remains, when a finding survives two attempts, or after three rounds. Never auto-fix:

- findings on wards that require human review;
- UNVERIFIED results, which need a blocker cleared rather than an edit;
- findings you disagree with: raise those with the human;
- in `pr`, anything outside the working tree: never edit a PR's title, body or labels, or rewrite
  commits. Present those corrections to the human. In `design`, corrections edit the document.

Finish with the final report and a list of the corrections you applied.

## 6. Take human-review items to the human

The report's **Human review** section lists the applicable wards that need a person's judgment,
whatever their result. Present them when the fix loop ends: the result is PASS, or every remaining
FAIL is on a ward that requires human review. For each item, show the ward, the location, the
question and the checker's assessment. Ask with `AskUserQuestion` when it's available; otherwise
list the items in your reply and stop.

An item the human rejects, or a failing one they decide how to fix, becomes a fix followed by a
re-check. Ask once per item, and again only if the code under it changed after the answer.

## When the slice is done

The slice is ready for human approval only when the latest report says **PASS**, a fresh checker
confirmed every earlier finding resolved, and every human-review item has the human's answer. A
registry with no wards reports **UNVERIFIED**, never PASS.

A passing check doesn't replace tests or static analysis, and it isn't approval: don't start the
next slice until a human approves this one.
