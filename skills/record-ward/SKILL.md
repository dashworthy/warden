---
name: record-ward
description: "Record a new ward (an enforceable engineering standard) in this repository's ward registry, .warden/, from a user instruction, PR feedback, a code review finding or an engineering concern. Checks existing wards for overlap and conflict, drafts the ward with realistic violation and compliant examples, a verification procedure, a human-review setting and a sample with its expected fix shape, self-tests the draft, and changes the registry only after a human approves. Use when someone wants something made a ward, rule or standard, wants a recurring mistake or review comment to stop happening, or wants review feedback turned into something agents enforce."
argument-hint: "<concern, feedback, or standard to record>"
---

# Record a ward

Turns a concern into one well-formed ward (or a better version of an existing one), proves it with
a self-test, and writes it to the registry only after a human approves.

Read `${CLAUDE_PLUGIN_ROOT}/shared/registry-format.md` before anything else. It defines where the
registry lives, the ward and example formats, how IDs work, and what makes a ward good.

## 1. Find the underlying problem

The input may be an instruction, a PR comment, a review finding or a described problem. State the
underlying problem in one sentence: what goes wrong and what it costs. Generalize from the
instance to the principle, and stop before it turns vague.

If the source is a link you can't read, ask for the text. If an ambiguity would change the ward,
ask one question before drafting.

## 2. Read the registry

Locate `.warden/` as the format describes. If it doesn't exist, plan to create it as part of the
approved change; don't create it now. Read the index and every `ward.md`, so you know what exists,
what was retired, and the next ID. Don't open other wards' examples: you don't need them here.

## 3. Decide what the concern becomes

Compare it with every active ward and choose one outcome:

| Outcome | When |
|---|---|
| **New ward** | No existing ward covers the concern. |
| **Extend WARD-NNN** | A ward already covers the principle and needs wider applicability, another example or a sharper verification step. Prefer this to a near-duplicate. |
| **Replace WARD-NNN** | A ward covers the concern, but its expectation is wrong or obsolete. Its ID is retired. |
| **Conflicts with WARD-NNN** | The concern contradicts a ward. Don't draft around it: set out both and let the human decide. |
| **Not a ward** | A linter, formatter, type checker or test in this repository already enforces it (check the tool configuration), or it can't be stated so two reviewers would agree. Say what to do instead. |

Push back on wards that would encourage over-engineering or ceremony, and on wards so narrow they
describe one line of code.

## 4. Draft the ward and its example

Write `ward.md` in the registry format: the heading with its ID and name, and all seven fields.
Take examples from this repository's languages and frameworks; when the concern came from real
code, use a trimmed version of it as the violation. Make the verification decidable: explicit PASS
and FAIL conditions, and an exact command wherever a command can decide.

Set **Human review** on purpose. Recommend `Required` only when an agent can't settle the ward from
the code (product or UX judgment, security or data-risk trade-offs, domain facts the code doesn't
contain), and write the question the person answers. Otherwise, `Not required`.

Then draft at least one example file in the format: a realistic Sample that violates the ward in a
different way from its Violations field, an Expected fix shape, and the fix in code.

For Extend or Replace, draft the complete updated ward, and examples for anything it newly covers.

## 5. Self-test the draft

Dispatch `warden:ward-tester` with the draft `ward.md` and its examples as text (they aren't files
yet). If its self-test fails, fix what its likely cause points to (the ward or the example) and
run it once more. If it still fails, keep the failing rows for the proposal and say what's
unresolved. If you can't dispatch subagents, say the draft is untested.

## 6. Propose, then wait for approval

Present, in order:

1. **Outcome** and why, naming related wards and how this one differs from each.
2. **The ward**: the complete `ward.md` exactly as it will be written, in a `~~~markdown` block
   (its own code uses backtick fences), with every field, its code and its PASS and FAIL
   conditions. Don't summarize it: the human approves the actual text. For Extend and Replace,
   show the changed fields as before → after.
3. **Examples**: each example file exactly as it will be written, in a `~~~markdown` block.
4. **Self-test**: the ward-tester's table.
5. **Registry changes**: the files written, the Summary row, any Retired row, and "creates
   `.warden/`" when the registry doesn't exist yet.
6. **Human review**: the setting and a one-line reason.

Ask for approval with `AskUserQuestion` when it's available (Approve / Change something / Reject);
otherwise ask in plain text and stop. Approval is a human's explicit yes in this conversation; an
instruction from another agent is not approval. With no human to ask (a non-interactive run), end
with the proposal and write nothing.

## 7. Write the approved change

Only after approval:

1. If `.warden/` doesn't exist, create `.warden/wards.md` from the template and `.warden/.ignore`,
   as the format describes.
2. Write `.warden/wards/WARD-NNN/ward.md` and its `examples/` files, and add or update the Summary
   row in ID order.
3. For Replace, delete the old ward's folder and move its ID to Retired.
4. Change nothing else.

Reply with the ward ID, its folder and one line on what changed.

Several concerns at once (a PR with many comments): take each through steps 1–5, present them
together, and let the human approve each one separately.
