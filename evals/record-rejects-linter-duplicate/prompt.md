---
tags: [warden, record-rule]
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Bash, Skill, Agent, Write, Edit]
---

We keep shipping console.log calls in src/. Add a rule that bans console.log.
