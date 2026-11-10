# Best-practice format

The contract for warden's catalog of best practices: generic wards that any repository can adopt.
A best practice states a principle with named blanks; adopting it fills the blanks from one
repository and writes an ordinary ward to that repository's registry (see `registry-format.md`).
Checks never read the catalog: they read only the adopted ward.

## Location

The catalog lives in the plugin, not in a repository's registry:

```
best-practices/
├── catalog.md                       the index: one row per best practice
└── BP-001/
    ├── ward.md                      the best practice
    └── examples/
        ├── laravel-<what>.md        one example per stack, each with its bindings filled
        └── node-<what>.md
```

## Catalog

`catalog.md` holds one row per best practice, in ID order:
`` | [BP-001](BP-001/ward.md) | <name> | code | 3 | Laravel, Node | ``. The columns are ID, Name,
Phases (as in the registry), Bindings (how many blanks it has), and Stacks (the stacks its examples
cover).

## Best-practice file

`best-practices/BP-NNN/ward.md` is a ward in the registry format with these differences:

- **Frontmatter** holds `version` (an integer, raised whenever the rule, a binding or the
  verification changes meaning) and `phases`. It has no `source`, `decided`, `paths`,
  `human-review` or `enforced-by`: those belong to the repository that adopts it. A question a
  person must always answer goes in a `human-review` binding (below) instead.
- **Heading:** `# BP-NNN: <imperative name>`.
- **Blanks:** every place that would name a repository's own function, class, folder, command,
  file, tool or convention is a blank, written `<<snake_case_name>>`. Not `{{ }}`: Blade, Vue,
  Mustache and i18next use it for real code, so an example couldn't tell a blank from its own template. Nothing in Description,
  Rationale, Verification or Applicability names a specific framework, library or project; say
  "the project's translation function", or use the blank.
- **Bindings:** a seventh field, after Compliant examples and before Verification, lists every
  blank used in the file:

  ~~~markdown
  **Bindings:**

  | Binding | What it is | How to find it | Laravel | Node |
  |---|---|---|---|---|
  | `<<paths>>` | Where the governed code lives | … | `app/Http/Controllers/**` | `src/routes/**` |
  | `<<translate_fn>>` | The function user-facing text goes through | Search for … | `__()` | `t()` from i18next |
  ~~~

  - `<<paths>>` is always a binding: adoption turns it into the adopted ward's `paths`. Leave it
    out only for a ward that applies anywhere.
  - "How to find it" is what an agent runs or reads to fill the blank in an unfamiliar repository:
    a search, the config file to read, the convention to look for. It says what to do when the
    repository has nothing to bind (the ward doesn't apply, or the person decides).
  - A binding may be optional; its row says what the ward does without it.
  - A `human_review` binding, when present, holds the question a person answers, worded generically.
- **Violations and Compliant examples** are short and stack-neutral: pseudocode, or one snippet per
  stack, each labelled with its stack. The examples folder carries the realistic code.
- **Verification** uses the blanks in its commands (`git grep -n '<<translate_fn>>('`), and keeps
  explicit PASS and FAIL conditions that hold for every stack.

## Examples

At least two examples, in different stacks (Laravel and Node by default), named
`<stack>-<what>.md`. Each is an ordinary ward example (Sample, Expected fix shape, fix code), with a
`## Bindings` section before Sample giving the value of every blank for that example:

~~~markdown
# <what the example shows>

## Bindings

- `<<paths>>`: `src/routes/**`
- `<<translate_fn>>`: `t()` from i18next

## Sample
…
~~~

The self-test runs on an example as on a registry ward, with the bindings read as filled in.

## Adopting a best practice

`/record-ward BP-NNN` adopts one:

1. Fill every binding from the repository, following its "How to find it", and show each value
   with its evidence (file:line, or the command and its output).
2. A required binding the repository can't fill makes the best practice not applicable: say why
   and write nothing, unless the person supplies the value.
3. Write the adopted ward in the registry format: every blank replaced, `paths` from `<<paths>>`,
   `human-review` from a `human_review` binding, `source: 'warden BP-NNN v<version>'`, today's
   `decided`, and `upstream: 'BP-NNN@<version>'`. Rewrite at least one example in the repository's
   own language and code.
4. Self-test, propose and wait for approval exactly as for a new ward.

An adopted ward is the repository's own from then on: it may be tightened like any other ward.
`upstream` records where it came from, so an audit can compare it with a newer version.

## IDs

`BP-NNN`, zero-padded to three digits, never renumbered or reused, as ward IDs are.
