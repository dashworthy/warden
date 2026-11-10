---
version: 1
phases:
  - design
  - code
---

# BP-005: Reuse or generalize before adding a single-use component

**Description:** Each UI component or reusable piece of UI logic (a hook or its equivalent) a change adds is, in
this order of preference: an existing entry in `<<shared_ui_dirs>>` reused or extended; a new generic one in
`<<shared_ui_dirs>>`; or, only when it can't be made generic, a single-use one beside its page. The choice, the
search behind it, the similar one-off code the search found and a person's answer are recorded in `<<design_doc>>`.

**Rationale:** Single-use components that repeat each other drift apart in look and behavior: a fix lands in one
copy, the next page starts a third, and the page folders fill with private copies until the shared library no
longer reflects what the application uses. A search that isn't written down can't be checked, so "simpler to start
fresh" wins by default. Recording the decision, with the one-offs a new generic component could replace, turns
duplication into follow-up work instead of leaving it unnoticed, and keeps the change itself small: existing
callers move later, each in its own change.

**Violations:**

```text
orders page folder (new): ArchiveOrderDialog
  a dialog "Archive order?" with Cancel and a danger "Archive" button that calls onArchive
<<shared_ui_dirs>> already holds confirmAction (header, message, acceptLabel, danger, onAccept)
<<design_doc>> has no Component decisions row for ArchiveOrderDialog
```

A page-local confirm dialog for a destructive action when the shared library already has one, with no recorded
decision.

```markdown
## Component decisions

| Component or hook | Decision | Compared with | Similar one-offs | Reason | Person's answer |
|---|---|---|---|---|---|
| `LineCountChip` | Single-use | | | Quicker to write for this page | Approved |
```

A single-use row that names no shared entry it was compared with, records no search, and gives convenience as its
reason.

**Compliant examples:**

```text
orders page: confirmAction({ header: 'Archive order?', message: 'It leaves every open list.',
                             acceptLabel: 'Archive', danger: true, onAccept: archive })
```

```markdown
## Component decisions

Search: read <<component_catalog>>; `git grep -n -E 'line-count|lines\.length' -- ':(glob)<<paths>>'`

| Component or hook | Decision | Compared with | Similar one-offs | Reason | Person's answer |
|---|---|---|---|---|---|
| `Archive order?` confirm | Reuse `confirmAction` | `confirmAction` | | | Approved |
| `LineCountChip` | Single-use | `Badge` (count), `Tabs` (count) | none | Reads the order's open lines through the orders API hook; a prop would move that read into every caller | Approved |
```

**Bindings:**

| Binding | What it is | How to find it | Laravel | Node |
|---|---|---|---|---|
| `<<paths>>` | Where the frontend's components and UI logic live | The frontend source root: `vite.config.*` inputs, `tsconfig.json` `include`, or the folders holding `.tsx`, `.vue` or `.blade.php` files (`git ls-files \| grep -E '\.(tsx\|jsx\|vue\|blade\.php)$' \| cut -d/ -f1-2 \| sort \| uniq -c`). For Blade, add the class-based component folder. No frontend: the ward doesn't apply. | `resources/views/**`, `app/View/Components/**` (Inertia: `resources/js/**`) | `src/**` |
| `<<shared_ui_dirs>>` | Where shared, reusable components and hooks live | The folders most pages import from: `git grep -h -o -E "from '[^']*(components\|hooks\|ui)[^']*'" \| sort \| uniq -c \| sort -rn \| head`; for Blade, where `<x-…>` tags resolve. If there is none, the person names where shared components go; until then the ward doesn't apply. | `resources/views/components`, `app/View/Components` (Inertia: `resources/js/components`, `resources/js/hooks`) | `src/components`, `src/hooks` |
| `<<component_catalog>>` | Optional. The list of shared components and when to use each | Look in `<<shared_ui_dirs>>` for a README, CATALOG or index file; look for Storybook (`.storybook/`, `*.stories.*`) or a design-system site the README links. Without one, the catalog is the listing of `<<shared_ui_dirs>>`: the checker reads each entry's name and props, and a new or extended component has no entry to add. | none: the listing of `resources/views/components` | Storybook: one story per component in `src/components/**/*.stories.tsx` |
| `<<component_file_pattern>>` | Regex matching a file that can define a component or reusable UI logic | The extensions the files in `<<shared_ui_dirs>>` use. | `\.blade\.php$\|^app/View/Components/.*\.php$` (Inertia: `\.tsx?$`) | `\.tsx?$` |
| `<<component_definition_pattern>>` | Optional. Regex matching a diff line that adds a component or hook inside an existing file | How the codebase declares components and hooks (`export function Foo`, `export const useFoo`). Without it (every component is its own file, as in Blade), step 1 lists added files only. | none: each Blade component is its own file (Inertia: as Node) | `^\+export (default )?(function\|const) ([A-Z]\|use[A-Z])` |
| `<<excluded_pattern>>` | Regex matching added files that are not components: tests, stories, generated code | The test runner's file pattern (`vitest`/`jest` config), Storybook's pattern, and generator output folders (in `.gitignore`, or files headed "generated"). | `^resources/views/vendor/` | `\.(test\|spec\|stories)\.tsx?$\|/__tests__/\|^src/api/generated/` |
| `<<page_entry_points>>` | How to tell a page entry point: the file a route renders | Read the router: views named by the server's render calls in routes and controllers, a client router config, or file-based routes. | views named by `view()` or `Route::view()` in `routes/` and `app/Http/Controllers` (Inertia: `Inertia::render()`) | components a route mounts in `src/router.tsx` |
| `<<design_doc>>` | Where a change's design decisions are written | Look for a folder of design, RFC, ADR or change documents (`git ls-files \| grep -i -E '(design\|rfc\|adr\|changes)/'`) or a design section in the pull request template. If none, the pull request description. | `docs/changes/<change>.md` | the pull request description |
| `<<follow_ups>>` | Where work a change defers is listed | A follow-ups or next-steps section in existing design documents, or the issue tracker the pull request template links. If none, a `## Follow-ups` section in `<<design_doc>>`. | `## Follow-ups` in `docs/changes/<change>.md` | `## Follow-ups` in the pull request description |

**Verification:**

1. List the components and UI logic units the change adds, using one `':(glob)<glob>'` pathspec per glob of
   `<<paths>>`:
   `git diff --name-status --diff-filter=A <base>...HEAD -- ':(glob)<<paths>>' | grep -E '<<component_file_pattern>>' | grep -v -E '<<excluded_pattern>>'`
   and, when `<<component_definition_pattern>>` is bound, the new definitions in existing files:
   `git diff <base>...HEAD -- ':(glob)<<paths>>' | grep -E '<<component_definition_pattern>>'`.
   Drop page entry points (`<<page_entry_points>>`). If nothing is left, the ward is N/A.
2. Confirm `<<design_doc>>` has a `## Component decisions` section: the search it ran, and one row per component or
   unit from step 1 with its decision (Reuse `X`, Extend `X`, New generic, or Single-use), the shared entries
   compared, the similar one-offs (file:line), the reason for a single-use decision, and a person's answer.
3. Check each row against the code:
   - Reuse or Extend: the diff uses the named entry. An extended entry keeps every existing caller working without
     changing its call site (new props or parameters are optional and default to the old behavior), and its
     `<<component_catalog>>` entry is updated when the project has a catalog.
   - New generic: it lives in `<<shared_ui_dirs>>`; it reads no page-specific data, routes or API calls (they
     arrive as props or parameters); it has a `<<component_catalog>>` entry when the project has a catalog; and it
     declares only the props or parameters its callers in this change pass. Each similar one-off is listed in
     `<<follow_ups>>` as a migration, and none is migrated in this change.
   - Single-use: it lives beside its page, and its reason names what ties it to the page (page data, a route or an
     API call that a prop could replace only by moving it into every caller) and the shared entries it was compared
     with. Convenience, speed or "simpler to start fresh" is not a reason. Markup or logic in it that has no such tie
     and repeats a one-off elsewhere is a new generic unit of its own.
4. Search again: read `<<component_catalog>>` (or, without one, the listing of `<<shared_ui_dirs>>`) for an entry
   that covers each new component or unit, and search `<<paths>>` for the primitives, markup or logic it is built
   from, e.g. `git grep -n -E '<dialog|role="alertdialog"|setTimeout\(' -- ':(glob)<<paths>>'`.
5. In the `design` phase, check the plan instead of a diff: `<<design_doc>>` has a `## Component decisions` row for
   every component or unit the plan adds, with the search, the decision, the shared entries compared, the similar
   one-offs and a person's answer, as step 2 describes, and step 4's search finds nothing the rows miss.

- PASS when every component and unit from step 1 has a complete row that matches the code, every row has a
  person's answer, and the checker's own search finds no shared entry or one-off a row missed.
- FAIL when a component or unit has no row or no person's answer; a shared entry covers it but isn't used; a
  single-use row has no reason, or only a convenience reason, or a reason a prop could satisfy without moving a
  read into every caller; a new generic one reads page-specific data, declares a prop or parameter no caller in
  the change passes, lacks its catalog entry when the project has a catalog, or migrates an existing caller in this
  change; an extended one changes an existing call site; or the checker's search finds a shared entry or similar
  one-off a row doesn't list.

**Applicability:** UI components and reusable UI logic units (hooks or their equivalent) a change adds under
`<<paths>>`, and in the `design` phase those a plan adds. Files matching `<<excluded_pattern>>` and page entry
points are out of scope. Changing an existing component's props, without adding a component or unit, is out of
scope.
