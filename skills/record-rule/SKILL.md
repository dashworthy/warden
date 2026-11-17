---
name: record-rule
description: "Turn an instruction, PR or review comment, or engineering concern into a rule (an enforceable standard) in this repository's registry, .warden/. Checks existing rules for overlap, drafts and self-tests the rule, and writes only after a human approves. Use when someone wants a rule or standard recorded, or a recurring mistake or review comment to stop happening."
argument-hint: "<concern, feedback, or standard to record>"
---

# Record a rule

Read `${CLAUDE_PLUGIN_ROOT}/shared/registry-format.md` first.

## 1. Understand

State the underlying problem in one sentence, generalized from the instance to the principle.
Note the `source` (who asked, or which PR, review or incident), today's date for `decided`, and an
`until` if the rule is temporary. If an ambiguity would change the rule, ask one question.

## 2. Decide

Read the index and every `rule.md` (not their examples), then choose:

- **New rule** when nothing covers the concern.
- **Extend RULE-NNN** when a rule covers the principle. Prefer this to a near-duplicate.
- **Replace RULE-NNN** when a rule's expectation is wrong or obsolete; its ID is retired.
- **Conflict** when the concern contradicts a rule: set out both and let the human decide.
- **Not a rule** when a linter, formatter or test already enforces it completely (check the
  config), when it's a default an agent already writes unprompted, or when two reviewers couldn't
  agree on it. Say what to do instead.

Only a concern that would change what the next agent writes earns a rule.

## 3. Draft

Write the complete `rule.md` in the format, as short as its example rule. Use only the line or two
of real code that break the rule as the violation, and those lines fixed as the compliant example.
State one general requirement rather than listing cases, and fold an extension into the existing sentences.

- **paths**: the narrowest globs that cover the governed code, each confirmed with
  `git ls-files -- ':(glob)<path>'`.
- **human-review**: only when an agent can't settle the rule from the code.
- **enforced-by**: existing tests that check the rule. Don't write new ones.

Draft at least one example: a Sample that violates the rule differently from its Violations, at a
path inside its paths, with an Expected fix shape and the fix.

## 4. Self-test

Dispatch `warden:rule-tester` with the draft and its examples as text. If it fails, fix the likely
cause and run it once more; if it still fails, say what's unresolved.

## 5. Propose and wait

Present the outcome and why, the complete `rule.md` and example files exactly as they'll be written
(in `~~~markdown` blocks), the self-test table, the Summary row, and "creates `.warden/`" when the
registry doesn't exist. Ask for approval with `AskUserQuestion` when available. Approval is a
human's explicit yes in this conversation; with no human to ask, write nothing.

## 6. Write

After approval only: create the registry if needed, write the rule folder and its Summary row,
retire a replaced rule, and change nothing else.
