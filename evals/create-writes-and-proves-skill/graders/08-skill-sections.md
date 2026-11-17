---
type: llm
focus: trace
weight: 1
arm: both
---
The SKILL.md the run wrote starts with YAML frontmatter holding name: verify-<app> and a
description, and has Launch, Doctor, Drive, Evidence and Cleanup sections whose commands come from
this repo (node server.js or npm start, the port from config.json, DATA_DIR, node cli.js), with no
placeholders like <command> or TODO. Launch says how to tell the app is ready. Cleanup kills only
what the run started and keeps the evidence. FAIL if any of the five sections is missing or generic.
