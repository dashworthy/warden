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
git add -A
git commit -q -m "base"
