---
name: check-wards
description: "Check an implementation slice against this repository's wards (.warden/) through an independent, read-only checker subagent, then drive the fix loop. Use after finishing a slice, when re-verifying fixes, or when asked to check changes against the project's wards or standards. Not for running linters."
argument-hint: "[--fix] [--per-ward] [scope: commit range, paths, or slice description]"
---

# Check wards

The verdict comes from `warden:ward-checker`, a fresh read-only subagent, never from this context:
you may have written the code. If you can't dispatch a subagent, stop and return "Independent ward
check required for <scope>".

## 1. Scope

Use the caller's scope, else uncommitted changes plus untracked files, else the branch against its
base. Leave `.warden/` out. If nothing is in scope, say so and stop.

Write a scope brief: the command that reproduces the diff, the changed files (untracked ones listed
separately), and one factual sentence on what the slice is meant to do. No claims that it's correct
or fixed.

## 2. Dispatch

Dispatch a new `warden:ward-checker` with the brief, the registry path, and on a re-check the
previous report verbatim, never the implementer's claims about fixes.

With `--per-ward`, give each ward its own checker:

1. Settle `paths` with git, as the registry format's Paths section says. A ward that matches
   nothing is N/A and gets no checker.
2. Dispatch one checker per remaining ward in one message, each told "Check only WARD-NNN". Above
   10, say how many and ask first.
3. Merge into one report in the checker's format: rows copied unchanged in ID order, an N/A row for
   each path-settled ward, totals recounted. Don't re-judge. A checker with no usable report makes
   its ward UNVERIFIED.

## 3. Report and fix

Relay the report unchanged. If it found no wards, stop and point to `/record-ward`.

The implementer fixes every FAIL and clears every UNVERIFIED blocker, then re-checks with fresh
checkers across all wards. With `--fix`, apply each FAIL's Recommended correction yourself and
re-check, for up to three rounds. Never auto-fix a ward with `human-review` questions, an UNVERIFIED
result, or a finding you dispute: take those to the human, quoting the finding and the ward. A
finding that survives two attempts also goes to the human.

## 4. Human review

When the loop ends, present each Human review item (ward, location, question, the checker's
assessment), with `AskUserQuestion` when available. A rejected item becomes a fix and a re-check.

The slice is ready for human approval only when the latest report is PASS and every human-review
item has an answer. A check isn't approval: don't start the next slice until a human approves.
