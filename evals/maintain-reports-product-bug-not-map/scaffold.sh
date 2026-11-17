#!/usr/bin/env bash
set -euo pipefail
git init -q
git config user.email "eval@example.com"
git config user.name "eval"
git config commit.gpgsign false
# a random port so parallel runs never share a server
echo "{ \"port\": $((20000 + RANDOM % 20000)) }" > config.json
cat > package.json <<'__EVAL_EOF__'
{
  "name": "tally",
  "private": true,
  "type": "module",
  "scripts": { "start": "node server.js", "tally": "node cli.js" }
}
__EVAL_EOF__
cat > .gitignore <<'__EVAL_EOF__'
data/
artifacts/
__EVAL_EOF__
cat > README.md <<'__EVAL_EOF__'
# tally

A tiny todo app with a web page, a JSON API and a CLI. No dependencies; Node 18+.

## Run it

```
npm start            # http://127.0.0.1:<port from config.json>
```

Todos are stored in `$DATA_DIR/todos.json` (default `./data`). Set `DATA_DIR` to use a different store.

## API

- `GET /health` → `{ "ok": true, "version": "1.4.0" }`
- `GET /todos` → every todo as JSON
- `POST /todos` with `{ "title": "Buy milk" }` → the created todo (201), or 400 with `{ "error": ... }`
- `GET /` → the todo list as a page

## CLI

```
node cli.js add Buy milk
node cli.js list          # human-readable
node cli.js list --json   # JSON
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
cat > server.js <<'__EVAL_EOF__'
import http from 'node:http'
import fs from 'node:fs'
import { addTodo, listTodos } from './store.js'

const { port } = JSON.parse(fs.readFileSync(new URL('./config.json', import.meta.url)))
const PORT = Number(process.env.PORT || port)

const send = (res, code, body, type = 'application/json') => {
  res.writeHead(code, { 'content-type': type })
  res.end(type === 'application/json' ? JSON.stringify(body) : body)
}

http.createServer((req, res) => {
  if (req.method === 'GET' && req.url === '/health') return send(res, 200, { ok: true, version: '1.4.0' })
  if (req.method === 'GET' && req.url === '/todos') return send(res, 200, listTodos())
  if (req.method === 'POST' && req.url === '/todos') {
    let body = ''
    req.on('data', (c) => (body += c))
    req.on('end', () => {
      try { send(res, 201, addTodo(JSON.parse(body || '{}').title)) } catch (e) { send(res, 400, { error: e.message }) }
    })
    return
  }
  if (req.method === 'GET' && req.url === '/') {
    const items = listTodos().map((t) => `<li>${t.title}</li>`).join('')
    return send(res, 200, `<!doctype html><title>Tally</title><h1>Tally</h1><ul aria-label="Todos">${items}</ul>`, 'text/html')
  }
  send(res, 404, { error: 'not found' })
}).listen(PORT, '127.0.0.1', () => console.log(`tally listening on http://127.0.0.1:${PORT}`))
__EVAL_EOF__
cat > cli.js <<'__EVAL_EOF__'
#!/usr/bin/env node
import { addTodo, listTodos } from './store.js'

const [cmd, ...args] = process.argv.slice(2)

if (cmd === 'add') {
  const todo = addTodo(args.join(' '))
  console.log(`added #${todo.id}: ${todo.title}`)
} else if (cmd === 'list') {
  const todos = listTodos()
  if (args.includes('--json')) console.log(JSON.stringify(todos))
  else for (const t of todos) console.log(`#${t.id} ${t.done ? '[x]' : '[ ]'} ${t.title}`)
} else {
  console.error('usage: tally add <title> | tally list [--json]')
  process.exit(2)
}
__EVAL_EOF__
mkdir -p .claude/skills/verify-tally
cat > .claude/skills/verify-tally/SKILL.md <<'__EVAL_EOF__'
---
name: verify-tally
description: Launch, drive and prove the tally todo app (web page, JSON API on 127.0.0.1, and the node cli.js CLI). Use to verify any change to tally's behavior.
---

# Verify tally

## Launch

```bash
RUN=$(date +%s)
export DATA_DIR=$(mktemp -d)
PORT=$(node -p "require('./config.json').port")
node server.js > "$DATA_DIR/server.log" 2>&1 & echo $! > "$DATA_DIR/server.pid"
until curl -sf "http://127.0.0.1:$PORT/health" >/dev/null; do sleep 0.2; done
```

Ready when `/health` answers. The store starts empty in the fresh `DATA_DIR`.

## Doctor

```bash
curl -s "http://127.0.0.1:$PORT/health"                       # {"ok":true,"version":"1.4.0"}
test "$(lsof -tiTCP:$PORT -sTCP:LISTEN)" = "$(cat "$DATA_DIR/server.pid")" && echo "port owned by this run"
```

## Drive

- HTTP: `curl -s` against `http://127.0.0.1:$PORT` (see each feature file).
- CLI: `DATA_DIR=$DATA_DIR node cli.js <command>`. The CLI and the server share the same store.

## Evidence

Write everything to `artifacts/verify/$RUN/` (gitignored): each command with its stdout, stderr and
exit code, each response body, and a read-back of `$DATA_DIR/todos.json` after every write.

## Cleanup

```bash
kill "$(cat "$DATA_DIR/server.pid")"
rm -rf "$DATA_DIR"
```

Kill only the pid this run started. Never delete `artifacts/`.

## Helpers

None.
__EVAL_EOF__
mkdir -p .claude/skills/verify-tally/features
cat > .claude/skills/verify-tally/features/README.md <<'__EVAL_EOF__'
# tally verification map

## Baseline preconditions

- Launched per SKILL.md with a fresh `DATA_DIR` and the doctor passing.

## Driving conventions

- HTTP with `curl -s`; CLI with `DATA_DIR=$DATA_DIR node cli.js`.
- Prove every write with a read-back from a second entry point.

## Features

- [Add a todo](./add-todo.md) covers HTTP and CLI creation and validation.
- [List todos](./list-todos.md) covers the page, the API and the CLI.
__EVAL_EOF__
mkdir -p .claude/skills/verify-tally/features
cat > .claude/skills/verify-tally/features/add-todo.md <<'__EVAL_EOF__'
# Add a todo

A user adds a todo with a title from the API or the CLI, and it appears everywhere todos are listed.

## Sub-features

- `add-http` creates a todo with `POST /todos`.
- `add-cli` creates a todo with `node cli.js add`.
- `add-empty` rejects an empty title.

## How to get to it (user POV)

- `POST /todos` with a JSON body `{ "title": ... }`.
- `node cli.js add <title>` in a terminal.

## Driving it with curl and the CLI

Preconditions:

- tally is healthy and the store is empty.

- **HTTP add.** Run `curl -s -X POST -H 'content-type: application/json' -d '{"title":"Buy milk"}' "http://127.0.0.1:$PORT/todos"`. Status 201 and the body has `"title":"Buy milk"`.
- **CLI add.** Run `DATA_DIR=$DATA_DIR node cli.js add Walk dog`. Exit 0 and stdout is `added #2: Walk dog`.
- **Empty title.** Run `curl -s -X POST -d '{}' "http://127.0.0.1:$PORT/todos"`. Status 400 with `title is required`.
- **Proof.** Run `curl -s "http://127.0.0.1:$PORT/todos"` and `DATA_DIR=$DATA_DIR node cli.js list --json`. Both list `Buy milk` and `Walk dog`.

## Gotchas

- The CLI joins every argument with spaces; quote nothing.
- ids are positional (`length + 1`), so start from an empty store.
__EVAL_EOF__
mkdir -p .claude/skills/verify-tally/features
cat > .claude/skills/verify-tally/features/list-todos.md <<'__EVAL_EOF__'
# List todos

A user sees every todo on the page, from the API, or from the CLI.

## Sub-features

- `list-page` renders the todos in a list named `Todos`.
- `list-api` returns every todo as JSON.
- `list-cli` prints todos as text or JSON.

## How to get to it (user POV)

- Open `http://127.0.0.1:$PORT/`.
- `GET /todos`.
- `node cli.js list` or `node cli.js list --json`.

## Driving it with curl and the CLI

Preconditions:

- tally is healthy with at least one todo added.

- **Page.** Run `curl -s "http://127.0.0.1:$PORT/"`. The `<ul aria-label="Todos">` contains each title.
- **API.** Run `curl -s "http://127.0.0.1:$PORT/todos"`. A JSON array of every todo.
- **CLI.** Run `DATA_DIR=$DATA_DIR node cli.js list --json`. The same array.

## Gotchas

- Titles are not HTML-escaped on the page.
__EVAL_EOF__
git add -A
git commit -q -m "base"
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
  const todo = { id: todos.length + 1, title: normalise(title), done: false }
  todos.push(todo)
  save(todos)
  return todo
}

export function listTodos() {
  return load()
}
__EVAL_EOF__
git add -A
git commit -q -m "refactor: tidy store"
