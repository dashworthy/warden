---
tags: [warden, record-ward]
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Bash, Skill, Agent, Write, Edit]
---

From last week's incident review, make this a ward. Our webhook handlers in src/webhooks/ trust whatever the payload says. A payment event with no amount crashed the handler with a TypeError. Another one had a negative quantity and created a refund nobody asked for. The shipping webhook accepted a country code of "XX" and the tax lookup threw. Someone sent a 10,000-character note and the insert into audit_log (note is varchar(500)) failed with a 500. And one partner sends quantity as a string like "3" sometimes. So every handler needs to check that required fields are there, types are right, numbers are in range, strings fit their columns, enum-like values are from the allowed set, and so on, before it uses anything from the payload.
