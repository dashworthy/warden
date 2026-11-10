---
tags: [warden, check-wards]
max_turns: 40
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Bash, Skill, Agent, Write, Edit]
---

/check-wards --phase pr --fix Draft title: "Invoice CSV export". Draft body: "Adds a CSV export endpoint for an account's invoices. Closes #88."
