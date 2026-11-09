---
tags: [warden, record-ward]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill, Agent, Write, Edit]
---

/record-ward We keep shipping console.log calls in src/. Add a ward that bans console.log.
