---
name: record-ward
description: "Turn an instruction, PR or review comment, or engineering concern into a ward (an enforceable standard) in this repository's registry, .warden/. Checks existing wards for overlap, drafts and self-tests the ward, and writes only after a human approves. Use when someone wants a rule or standard recorded, or a recurring mistake or review comment to stop happening."
argument-hint: "<concern, feedback, or standard to record>"
---

# Record a ward

Read `${CLAUDE_PLUGIN_ROOT}/shared/registry-format.md` first.

## 1. Understand

State the underlying problem in one sentence, generalized from the instance to the principle.
Note the `source` (who asked, or which PR, review or incident), today's date for `decided`, and an
`until` if the ward is temporary. If an ambiguity would change the ward, ask one question.

## 2. Decide

Read the index and every `ward.md` (not their examples), then choose:

- **New ward** when nothing covers the concern.
- **Extend WARD-NNN** when a ward covers the principle. Prefer this to a near-duplicate.
- **Replace WARD-NNN** when a ward's expectation is wrong or obsolete; its ID is retired.
- **Conflict** when the concern contradicts a ward: set out both and let the human decide.
- **Not a ward** when a linter, formatter or test already enforces it completely (check the
  config), when it's a default an agent already writes unprompted, or when two reviewers couldn't
  agree on it. Say what to do instead.

Only a concern that would change what the next agent writes earns a ward.

## 3. Draft

Write the complete `ward.md` in the format, as short as its example ward. Use only the line or two
of real code that break the ward as the violation, and those lines fixed as the compliant example.
State one rule rather than listing cases, and fold an extension into the existing sentences.

- **paths**: the narrowest globs that cover the governed code, each confirmed with
  `git ls-files -- ':(glob)<path>'`.
- **human-review**: only when an agent can't settle the ward from the code.
- **enforced-by**: existing tests that check the ward. Don't write new ones.

Draft at least one example: a Sample that violates the ward differently from its Violations, at a
path inside its paths, with an Expected fix shape and the fix.

## 4. Self-test

Dispatch `warden:ward-tester` with the draft and its examples as text. If it fails, fix the likely
cause and run it once more; if it still fails, say what's unresolved.

## 5. Propose and wait

Present the outcome and why, the complete `ward.md` and example files exactly as they'll be written
(in `~~~markdown` blocks), the self-test table, the Summary row, and "creates `.warden/`" when the
registry doesn't exist. Ask for approval with `AskUserQuestion` when available. Approval is a
human's explicit yes in this conversation; with no human to ask, write nothing.

## 6. Write

After approval only: create the registry if needed, write the ward folder and its Summary row,
retire a replaced ward, and change nothing else.
