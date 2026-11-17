---
type: llm
focus: trace
weight: 1
arm: both
---
The SKILL.md the run wrote (in the repo or a scratch copy) starts with YAML frontmatter holding
name: verify-<app> and a description, and has Launch, Doctor, Drive, Evidence and Cleanup sections
whose commands come from this repo (node cli.js and its commands, DATA_DIR), with no unfilled
template text (such as TODO, <command> or <describe here>); argument names in usage lines, such as
<run-id> or <feature-id>, are fine. Launch sets up an isolated store (tally is a short-lived CLI, so
there is no server). Cleanup removes only what the run created and keeps the evidence. The sections
may point to a helper script the skill ships, as long as its invocation is shown. FAIL if any of the
five sections is missing or generic.
