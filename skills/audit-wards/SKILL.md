---
name: audit-wards
description: "Audit this repository's ward registry, .warden/, for wards that overlap, contradict each other, are ambiguous, too broad or too restrictive, lack good examples or verification, duplicate automated tooling, or have the wrong human-review setting, then propose consolidations that name the ward IDs retained and retired. Report-only until a human approves specific changes. Use when asked to review, clean up, consolidate, dedupe, simplify or sanity-check the wards or engineering standards, or periodically as the registry grows."
---

# Audit wards

Keeps the registry concise, consistent and enforceable: fewer, sharper wards beat many overlapping
ones. Reports first, and changes the registry only for the recommendations a human approves.

Read `${CLAUDE_PLUGIN_ROOT}/shared/registry-format.md` before anything else.

## 1. Load the registry

Locate `.warden/` as the format describes and read the index and every ward file, Retired
included. If there are no ward files, say so and stop: there's nothing to audit.

## 2. Check consistency

Apply the format's consistency rules. Each break becomes a recommendation.

## 3. Review every ward against every other

1. **Same concern**: wards addressing one underlying problem.
2. **Overlap**: wards that usually fire together and could merge into one that stays independently verifiable.
3. **Contradiction**: code that satisfies one ward would violate another.
4. **Ambiguity**: wording or verification two reviewers could apply differently. Quote the phrase and give both readings.
5. **Overreach**: too broad to verify, too restrictive for real code, or pushing toward ceremony and abstraction with no concrete benefit.
6. **Weak evidence**: unrealistic or mismatched examples, verification without clear PASS and FAIL conditions, or applicability too vague to decide N/A.
7. **Duplicated tooling**: a linter, formatter, type checker or test in this repository already enforces the ward. Check the tool configuration before claiming it.
8. **Human-review setting**: `Required` where an agent could decide, or `Not required` where the call needs a person.

Preserve intent. Don't drop a meaningful constraint to shrink the count, and never change what a
ward means except through a recommendation that says so.

## 4. Report

Number every recommendation (A1, A2, …) so approval can be selective. Use this layout, leaving out
empty sections:

~~~markdown
## Ward audit: <n> wards, <m> recommendations

### Merges
**A1. Merge WARD-003 into WARD-001**
- Problem: <what's wrong today>
- Proposal: <the change>; retain WARD-001, retire WARD-003 ("Merged into WARD-001")
- Impact: <what passes or fails differently afterwards>

### Conflicts
### Ambiguities
### Examples and verification
### Redundant wards
### Human-review settings
### Consistency

### Proposed registry changes
<for each recommendation: each ward file's text before → after, and the Summary and Retired rows touched>
~~~

Every recommendation states the problem, the proposed change and its impact. Merges name the
retained ID and every retired ID.

A healthy registry is a valid result: say "No changes recommended" with one line on what you
checked. Don't invent recommendations.

## 5. Ask which to apply

Ask with `AskUserQuestion` when it's available (multi-select over the recommendations, plus None);
otherwise ask in plain text and stop. Approval is a human's explicit choice in this conversation.
With no human to ask, end with the report and change nothing.

## 6. Apply only what was approved

Make exactly the approved changes: edit ward files and Summary rows; for each retired ID, delete
its file, remove its Summary row and add a Retired row with the outcome. Keep every other file and
line as it was. Reply with the recommendations applied and the IDs retained and retired.
