---
name: check-wards
description: "Verify an implementation slice against every ward (enforceable engineering standard) in this repository's ward registry, .warden/, through an independent read-only checker subagent. Returns a PASS / FAIL / N/A / UNVERIFIED summary covering every ward, actionable findings, and the items that need human review. Use after finishing an implementation slice and before asking for human approval, when re-verifying fixes to earlier findings, or whenever asked to check changes against the project's wards or standards. Pass --fix to apply corrections that don't need human review and re-check automatically. Not for running tool linters such as ESLint, PHPStan or Ruff."
argument-hint: "[--fix] [scope: commit range, paths, or slice description]"
---

# Check wards

Verifies one implementation slice against every ward in the registry. The verdict comes from the
`warden:ward-checker` subagent: a fresh, read-only reviewer that didn't write the code. In this
context you scope the slice, dispatch the checker, hand its report back unchanged, and drive the
fix loop.

**Arguments:** `--fix` turns on automatic fixes (step 5). Anything else is the scope: a commit
range (`main..HEAD`), paths, or a description of the slice.

## 1. Scope the slice

Use the first that applies:

1. The scope the caller gave.
2. Uncommitted changes: `git diff HEAD`, plus untracked files from
   `git ls-files --others --exclude-standard`.
3. The branch against its base: `git diff "$(git merge-base HEAD origin/HEAD)"...HEAD`, falling
   back to `main` or `master`.

Leave `.warden/` out of the slice: the registry isn't implementation code. If nothing is left in
scope, say so and stop.

Write a **scope brief**: the command that reproduces the diff; the changed files, with untracked
files listed separately because `git diff` doesn't show them; and one or two factual sentences on
what the slice is meant to do (from the task or plan). Keep it to facts: no claims that the code
is correct or that anything was fixed.

## 2. Dispatch the checker

Dispatch `warden:ward-checker`, a new instance for every check, with:

- the scope brief;
- the registry location, `<repo root>/.warden/`;
- on a re-check, the previous report verbatim, and nothing the implementer said about fixing it.

If the `warden:ward-checker` agent type isn't available, dispatch a general-purpose agent instead:
give it the instructions in `${CLAUDE_PLUGIN_ROOT}/agents/ward-checker.md` (everything below the
frontmatter) with the items above, and tell it never to edit files.

Don't evaluate wards in this context: you may have written the code, and the point is an
independent verdict. If you can't dispatch a subagent here (for example, you're a subagent at the
nesting limit), stop and return "Independent ward check required for <scope>" to your caller.

## 3. Hand back the report

Relay the checker's report exactly as returned: don't trim, soften, re-rank or re-judge it. When an
implementation subagent built the slice, give it the report verbatim (continue it, or re-dispatch
it with the report) so it can resolve the findings.

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

After each report, apply the **Recommended correction** of every FAIL finding on a ward whose Human
review is `Not required`, then re-check with a fresh checker and the previous report. Stop when no
such FAIL remains, when a finding survives two attempts, or after three rounds. Never auto-fix:

- findings on wards that require human review;
- UNVERIFIED results, which need a blocker cleared rather than an edit;
- findings you disagree with: raise those with the human.

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
