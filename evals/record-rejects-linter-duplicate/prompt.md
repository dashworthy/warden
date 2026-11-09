---
tags: [warden, record-ward]
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Bash, Skill, Agent, Write, Edit]
---

We keep shipping console.log calls in src/. Add a ward that bans console.log.
