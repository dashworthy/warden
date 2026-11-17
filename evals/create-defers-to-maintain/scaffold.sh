#!/usr/bin/env bash
set -euo pipefail
git init -q
git config user.email "eval@example.com"
git config user.name "eval"
git config commit.gpgsign false
cat > package.json <<'__EVAL_EOF__'
{
  "name": "tally",
  "private": true,
  "type": "module",
  "scripts": { "tally": "node cli.js" }
}
__EVAL_EOF__
cat > .gitignore <<'__EVAL_EOF__'
data/
artifacts/
__EVAL_EOF__
cat > README.md <<'__EVAL_EOF__'
# tally

A tiny todo CLI. No dependencies; Node 18+.

Todos are stored in `$DATA_DIR/todos.json` (default `./data`). Set `DATA_DIR` to use a different store.

```
node cli.js add Buy milk        # add one todo
node cli.js import todos.txt    # add one todo per non-empty line of a file
node cli.js list                # human-readable
node cli.js list --json         # JSON
```
__EVAL_EOF__
cat > store.js <<'__EVAL_EOF__'
import fs from 'node:fs'
import path from 'node:path'

const dir = () => process.env.DATA_DIR || path.resolve('data')
const file = () => path.join(dir(), 'todos.json')

export function load() {
  try { return JSON.parse(fs.readFileSync(file(), 'utf8')) } catch { return [] }
}

export function save(todos) {
  fs.mkdirSync(dir(), { recursive: true })
  fs.writeFileSync(file(), JSON.stringify(todos, null, 2))
}

export function addTodo(title) {
  if (!title) throw new Error('title is required')
  const todos = load()
  const todo = { id: todos.length + 1, title, done: false }
  todos.push(todo)
  save(todos)
  return todo
}

export function listTodos() {
  return load()
}
__EVAL_EOF__
cat > cli.js <<'__EVAL_EOF__'
#!/usr/bin/env node
import fs from 'node:fs'
import { addTodo, listTodos } from './store.js'

const [cmd, ...args] = process.argv.slice(2)

if (cmd === 'add') {
  const todo = addTodo(args.join(' '))
  console.log(`added #${todo.id}: ${todo.title}`)
} else if (cmd === 'import') {
  const lines = fs.readFileSync(args[0], 'utf8').split('\n').filter((l) => l.trim())
  for (const line of lines) addTodo(line)
  console.log(`imported ${lines.length} todos`)
} else if (cmd === 'list') {
  const todos = listTodos()
  if (args.includes('--json')) console.log(JSON.stringify(todos))
  else for (const t of todos) console.log(`#${t.id} ${t.done ? '[x]' : '[ ]'} ${t.title}`)
} else {
  console.error('usage: tally add <title> | tally import <file> | tally list [--json]')
  process.exit(2)
}
__EVAL_EOF__
mkdir -p .claude/skills/verify-tally
cat > .claude/skills/verify-tally/SKILL.md <<'__EVAL_EOF__'
---
name: verify-tally
description: Drive and prove the tally todo CLI (node cli.js add, import and list) against an isolated store. Use to verify any change to tally's behavior.
---

# Verify tally

## Launch

tally is a short-lived CLI, so there is no server to start. Give every drive its own store:

```bash
RUN=$(date +%s)
export DATA_DIR=$(mktemp -d)
mkdir -p "artifacts/verify/$RUN"
```

Ready when the doctor passes.

## Doctor

```bash
node --version                                   # v18 or later
DATA_DIR=$DATA_DIR node cli.js list --json       # [] on a fresh store
```

## Drive

Run `DATA_DIR=$DATA_DIR node cli.js <command>` (see each feature file). Every command reads and writes the same store.

## Evidence

Write everything to `artifacts/verify/$RUN/` (gitignored): each command with its stdout, stderr and
exit code, and a read-back with `node cli.js list --json` after every write.

## Cleanup

```bash
rm -rf "$DATA_DIR"
```

Remove only the store this run created. Never delete `artifacts/`.

## Helpers

None.
__EVAL_EOF__
mkdir -p .claude/skills/verify-tally/features
cat > .claude/skills/verify-tally/features/README.md <<'__EVAL_EOF__'
# tally verification map

## Baseline preconditions

- A fresh `DATA_DIR` per SKILL.md, with the doctor passing.

## Driving conventions

- Every command runs as `DATA_DIR=$DATA_DIR node cli.js <command>`.
- Prove every write with a read-back from `node cli.js list --json`.

## Features

- [Add a todo](./add-todo.md) covers adding one todo, importing a file, and validation.
- [List todos](./list-todos.md) covers text and JSON output.
__EVAL_EOF__
mkdir -p .claude/skills/verify-tally/features
cat > .claude/skills/verify-tally/features/add-todo.md <<'__EVAL_EOF__'
# Add a todo

A user adds one todo with a title, or many at once from a file, and they appear in the list.

## Sub-features

- `add-one` creates a todo with `node cli.js add`.
- `add-import` creates one todo per non-empty line with `node cli.js import <file>`.
- `add-empty` rejects an empty title.

## How to get to it (user POV)

- `node cli.js add <title>` in a terminal.
- `node cli.js import <file>` in a terminal.

## Driving it with the tally CLI

Preconditions:

- A fresh `DATA_DIR` and the doctor passing.

- **Add one.** Run `DATA_DIR=$DATA_DIR node cli.js add Buy milk`. Exit 0 and stdout is `added #1: Buy milk`.
- **Import.** Write `Walk dog` and `Pay rent` on two lines to `$DATA_DIR/in.txt`, then run `DATA_DIR=$DATA_DIR node cli.js import "$DATA_DIR/in.txt"`. Exit 0 and stdout is `imported 2 todos`.
- **Empty title.** Run `DATA_DIR=$DATA_DIR node cli.js add`. Exit 1 with `title is required`.
- **Proof.** Run `DATA_DIR=$DATA_DIR node cli.js list --json`. It lists `Buy milk`, `Walk dog` and `Pay rent`.

## Gotchas

- `add` joins every argument with spaces; quote nothing.
- ids are positional (`length + 1`), so start from an empty store.
__EVAL_EOF__
mkdir -p .claude/skills/verify-tally/features
cat > .claude/skills/verify-tally/features/list-todos.md <<'__EVAL_EOF__'
# List todos

A user sees every todo as text or as JSON.

## Sub-features

- `list-text` prints one line per todo with its id and done box.
- `list-json` prints every todo as a JSON array.

## How to get to it (user POV)

- `node cli.js list` or `node cli.js list --json` in a terminal.

## Driving it with the tally CLI

Preconditions:

- At least one todo added.

- **Text.** Run `DATA_DIR=$DATA_DIR node cli.js list`. One `#<id> [ ] <title>` line per todo.
- **JSON.** Run `DATA_DIR=$DATA_DIR node cli.js list --json`. A JSON array of every todo.

## Gotchas

- An empty store prints nothing in text mode and `[]` in JSON mode.
__EVAL_EOF__
git add -A
git commit -q -m "base"
