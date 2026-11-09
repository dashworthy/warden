---
tags: [warden, record-ward]
max_turns: 30
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Bash, Skill, Agent, Write, Edit]
---

/record-ward Code review on the export PR: "exportCustomers() calls Customer.findAll() for the whole tenant and builds the CSV in memory. It'll OOM on our largest tenants." Make a ward so this stops happening.
