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
git add -A
git commit -q -m "base"
# the change under test: left uncommitted
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
} else if (cmd === 'count') {
  const todos = listTodos()
  const open = todos.filter((t) => !t.done).length
  console.log(`${todos.length} todos, ${open} open`)
} else {
  console.error('usage: tally add <title> | tally list [--json] | tally count')
  process.exit(2)
}
__EVAL_EOF__
