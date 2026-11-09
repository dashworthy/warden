---
tags: [warden, record-ward]
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Bash, Skill, Agent, Write, Edit]
---

Priya left this review on PR #142: "listOrders loads every order for the account into memory. This will fall over for our big customers. Please always paginate anything that lists records." Turn it into a ward so it stops happening.
