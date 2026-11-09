---
tags: [warden, record-ward]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill, Agent, Write, Edit]
---

/record-ward PR #142 review from Priya: "listOrders loads every order for the account into memory. This will fall over for our big customers. Please always paginate anything that lists records." Turn this into a ward.
