---
name: verify-change
description: "Prove a change works against the real artifact before declaring it done: state a falsifiable finish condition, pick the check that matches the change, drive the real app through the project's verify-<app> skill and feature map, and report the exact commands, outputs and evidence paths (or say inconclusive). Use after completing any change to app behavior, before saying it's done or opening a PR, and for /verify-change, \"verify it in the app\", \"prove it works\", \"show me proof\", \"repro this\"."
argument-hint: "[what changed or what to prove]"
---

# Verify

"It compiles" is not evidence. Verify every output by checking the real thing directly: run the feature, read the actual value, inspect the diff. Proxies do not count: file mtimes, self-reports, cached output, a green build, a passing unit test for behavior the user reaches through a UI. When a check fails, suspect the observation method before the system.

## 1. State the finish condition

Write what done means as checks that can fail, before running anything. Use the user's words when they gave a condition. Otherwise derive it from the task:

```text
done when: text output stays byte-identical, the json parses, both run against the sample project
```

Three checks you can run beat a mood to satisfy.

## 2. Match the check to the change

- A CLI change runs the real command.
- A UI change walks the changed flow in the running app.
- A parser or migration replays a saved input.
- A perf change compares before and after profiles, alternating runs, with a median and range and the limiter named.
- A storage change reads back the written value from a second view (reopen it, query the database read-only).
- A bug fix reproduces the bug first, on the code before the fix, then shows it gone.

## 3. Drive the real app

1. Find the project's verification skill: `.claude/skills/verify-*/SKILL.md`. Several → pick the one whose surface the change touches.
2. None → do the check by hand for this change, then tell the user once that `/create-verify-skill` would make it repeatable. Do not generate one unasked.
3. Read the skill and its `features/README.md`. Pick every feature file whose user paths the change reaches, including through shared components, services or routes.
4. Follow the skill: Launch, Doctor, then drive each picked feature from every entry point its map lists. One convenient entry point is not proof of the others.
5. Capture evidence where the skill says: the action and the resulting state, plus side effects (rows, files, messages).
6. Run Cleanup. Confirm the evidence survived it.

If the map is wrong about the app (a renamed button, a moved route), finish the proof by the real path, then note the drift for `/maintain-verify-skill`. Do not edit the map mid-proof unless the user asked.

Never weaken a check to make it pass. A precondition you can't meet is a failure with its reason, not a skip.

## 4. Report

Lead with the verdict per check: **pass**, **fail**, or **inconclusive** (the check couldn't run, and why). Then for each check:

- The exact command or user path driven.
- The observed output or state.
- The evidence path (screenshot, ARIA snapshot, transcript, query result).

A confident reply without evidence is a failure of this skill. If any check is inconclusive, the change is not done; say what would make it conclusive.

Script the check when you can: a deterministic script that reruns the comparison beats a one-time look. Keep its output where the user can see it, and commit it only when the trail must be auditable later.
