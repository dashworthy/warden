---
name: create-verify-skill
description: "Generate a project-local verification skill (.claude/skills/verify-<app>/) that drives this repo's app the way a user does, with Launch, Doctor, Drive, Evidence and Cleanup sections and a feature map, then prove it end to end before handing it over. Any language, framework or platform. Use for /create-verify-skill, \"make a verify skill for this repo\", \"make a control skill\", or when a project has no scripted way to prove UI, CLI or service behavior."
disable-model-invocation: true
---

# Create a verification skill

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, and capture evidence. This skill generates that as a project-local skill at `.claude/skills/verify-<app>/`, tailored to the repo. Write its output for the next agent, not for a human: it will be read cold, mid-task, by an agent that has never seen the app.

If `.claude/skills/verify-*/` already exists, stop and point the user at `/maintain-verify-skill` instead of generating a second one.

## 1. Interview the repo, not the user

Answer these from the codebase. Ask the user (with `AskUserQuestion`) only what you cannot observe:

- **Surface:** what does a user actually touch? A web UI, a CLI/TUI, a desktop app, an API, a mobile app, a library? A repo can have several. Pick the primary one and note the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev command (package scripts, Makefile, compose file, README quickstart). Note ports, env vars, seed data and auth.
- **Drive:** how can an agent interact with it programmatically? Existing harnesses first: Playwright/Cypress specs, expect scripts, PTY helpers, curl-able endpoints, a debug port. Only then pick a generic recipe: Playwright or CDP for web and Electron (Claude in Chrome works for interactive runs, but a script is repeatable and cheaper), a tmux/PTY harness for CLI/TUI, plain HTTP for services.
- **Observe:** what evidence can be captured? Screenshots, ARIA snapshots, terminal transcripts, response bodies, logs, exit codes, database state.
- **Isolate:** can two instances run side by side (ports, data dirs, profiles, databases)? If not, say so in the generated skill: refusing to double-drive a shared instance beats corrupting the user's session.

If the checkout doesn't build or start as-is, fix that first (or report it precisely) before generating. A skill written against a broken base teaches wrong steps. When an irrelevant missing asset blocks startup (a static dir the API never serves, a sample config), the generated skill may create it, clearly marked as verification scaffolding, and remove it in cleanup.

For a big repo, send read-only `Explore` subagents in parallel (one per question above) and keep only their conclusions.

## 2. Generate the skill

Write `.claude/skills/verify-<app>/SKILL.md` with YAML frontmatter: `name: verify-<app>` and a `description` that names the app, the surface, and when to reach for it. Without frontmatter the skill never registers. Then these sections, each grounded in what the interview actually found, with no placeholders left:

- **Launch:** the exact command that starts the app for verification, and how to tell it's ready (a log line, a prompt, a page that renders). Launch must reach a usable state from an empty data dir, including migrations and seed data. Ready means usable, not just that a process answers: a database health check can pass while its init scripts are still running. Include teardown. For a short-lived CLI or TUI there is no server to keep alive: launch means build the binary (or install deps) once, then start each drive in its own isolated PTY or tmux session.
- **Doctor:** one read-only check that answers "is this instance worth driving?": process up, right version or build, port owned by us, auth valid. An agent runs this first whenever anything looks off.
- **Drive:** the harness recipe with real selectors and commands from this repo, not examples. Prefer stable handles (ARIA roles and names, data attributes, prompt strings, route paths) over coordinates and tab order.
- **Evidence:** what to capture for a proof and where it goes (a gitignored directory the skill names, one subfolder per run). State the proof standards:
  - Exercise the real user path, not internal setters or test-only endpoints.
  - Capture the action and the resulting state, not just the final screen.
  - Verify side effects (files written, rows inserted, messages sent) alongside what's visible.
  - Mock only where a production boundary already isolates the external system.
  - When the safe path is a dry-run or test mode, verify what it actually skips by observing (files, network, git refs) rather than trusting its name. Some dry-runs still touch the network or open a browser.
- **Cleanup:** how to tear down what the run created. Never kill by process name; kill what you started. Cleanup removes instances and scratch state, never the evidence: proof artifacts survive the teardown, at the location the skill names.
- **Helpers:** any script the skill ships lives in the skill's `scripts/` folder, is executable, and has its invocation shown in the skill body. A helper the reader has to reverse-engineer is not a helper.

## 3. Seed the feature map

Create `.claude/skills/verify-<app>/features/README.md` plus one file per user-facing feature you can identify. Aim for the top 3–5 to start, from routes, commands, menus or docs. Follow the shape in [`references/feature-map-example/`](references/feature-map-example/): a README index (baseline preconditions, driving conventions, proof and skip reporting, the entry contract, the feature list) and one file per feature.

Each feature file answers, from the user's point of view: what the feature is, how to reach it, how to drive it with the harness, and what observable end state proves it works. Its four H2s, in order, are `Sub-features`, `How to get to it (user POV)`, `Driving it with <harness>`, and `Gotchas`.

If the seed data lacks a precondition a journey needs, the journey reports a failure and the reason goes in that feature's `Gotchas`. Never weaken the journey to make it pass. The map is the repo's maintained verification source: a proof that drives one convenient entry point is incomplete when the map lists others.

## 4. Prove the generated skill before handing it over

Run its own instructions end to end once: launch, doctor, drive ONE mapped feature (one is enough; the map exists so later runs cover the rest), capture evidence, clean up. After cleanup, confirm the evidence still exists at the named location. A cleanup that eats the proof fails this step.

Fix what fails, and run the generated cleanup after every failed iteration too, so broken attempts don't strand processes and ports. A generated skill that was never executed is a draft, not a deliverable.

If you proved it in a stand-in for the real target (a container in place of a fresh VM, a local stack in place of a remote one), list every setup step the stand-in did that the target will not. Those steps stay unverified until a run on the real target covers them.

## 5. Hand over

Report, in this order:

1. The skill path and how to call it: `/verify-<app>`.
2. The proof run: the commands, the feature driven, and where its evidence is.
3. Anything unverified, and why.
4. The next steps: commit the skill so every person and agent drives the app the same way; use `/verify-change` to prove a change; run `/maintain-verify-skill` to keep the map honest as the app changes. Suggest a cadence only if asked.

When agents will keep writing throwaway scripts to click through the app, suggest building a small control CLI the skill calls instead: a few composable commands, `--dry-run` on anything destructive, errors that say what to do, rich `--help`, JSON output.
