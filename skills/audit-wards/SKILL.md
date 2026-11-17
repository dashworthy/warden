---
name: audit-wards
description: "Audit this repository's ward registry, .warden/: self-test every ward, then find overlaps, conflicts, ambiguity, overreach, weak examples, dead paths and duplicated tooling, and propose merges that name the IDs retained and retired. Report-only until a human approves. Use when asked to review, clean up, consolidate or sanity-check the wards."
---

# Audit wards

Fewer, sharper wards beat many overlapping ones. Read
`${CLAUDE_PLUGIN_ROOT}/shared/registry-format.md` first.

## 1. Self-test

Read the index and every `ward.md`, leaving examples to the testers. With no wards, say so and
stop. Dispatch one `warden:ward-tester` per ward in one message; above 10 wards, say how many and
ask first.

## 2. Review

Check the format's consistency rules, then every ward against every other for:

- the same concern, or overlap that could merge into one verifiable ward;
- contradictions;
- ambiguity: quote the phrase and give both readings;
- overreach, ceremony, or a ward longer than the format's example;
- weak examples or verification, or applicability too vague to decide N/A;
- a linter, test or framework default that already covers it (check the config);
- `human-review` questions an agent could answer, or a judgment call without one;
- paths: every glob through `git ls-files -- ':(glob)<path>'`, flagging dead or too-broad globs;
- a missing `source`, an `until` that may have passed, or an `enforced-by` file that's gone.

Preserve intent: never drop a constraint just to shrink the count.

## 3. Report

Number each recommendation (A1, A2, …) with its problem, proposed change and impact, grouped under
headings. A merge names the retained ID and every retired one. End with each file's text
before → after. A healthy registry is a valid result: say "No changes recommended" and don't invent
problems.

## 4. Apply what's approved

Ask which to apply, with `AskUserQuestion` when available; with no human to ask, change nothing.
Make exactly the approved changes, retiring IDs as the format says, and re-run the self-test for
each ward you changed.
