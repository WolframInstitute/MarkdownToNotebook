---
name: create-wolfram-documentation
description: Orchestrate publishable Wolfram Language documentation for a project or paclet - authored as literate-markdown (.md) and built into notebooks / ref pages with MarkdownToNotebook, using the family of Wolfram authoring skills hosted at github.com/WolframInstitute/MarkdownToNotebook. Use this whenever the user wants to document a Wolfram paclet or project, generate reference pages / a guide / tutorials / an overview / a computational essay for their Wolfram Language code, publish a Function/Data/Example/Prompt/Demonstration resource, port existing .nb documentation to markdown, or set up a Wolfram docs pipeline. This is the entry point for "/create-wolfram-documentation". It surveys the project, picks the right doc types, backs up existing .nb docs, ports them to .md, authors each page, and wires up the build.
---

# Create Wolfram documentation

Turn a Wolfram Language project into **publishable documentation authored as
literate-markdown** and built into notebooks / `ref/` pages with
[`MarkdownToNotebook`](https://github.com/WolframInstitute/MarkdownToNotebook).
The markdown is the source of truth; the `.nb` are generated and gitignored.
You never hand-edit notebook cell styles - you write `.md` and the converter
fills the official templates.

This is an **orchestrator**. It does not itself contain the per-page
conventions - those live in a family of focused authoring skills at the WI
GitHub location. Your job is to survey the project, choose which doc types to
create, and drive the right sub-skill for each, protecting the user's existing
docs on the way.

## The authoring skills (at the WI GitHub location)

Each doc type has its own skill under
`https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/skills/<name>/SKILL.md`.
**Before authoring a page of a given type, read that skill's `SKILL.md`** - it
carries the frontmatter, section contract, code-cell options, and build/check
steps for that type. Prefer a **local checkout** of
`WolframInstitute/MarkdownToNotebook` if one is on disk (look for a `skills/`
directory next to `MarkdownToNotebook.wl`); otherwise `WebFetch` the raw
`SKILL.md` from GitHub.

| Doc type | Skill | Use for |
|---|---|---|
| Paclet definition | `wolfram-paclet` | the paclet's `ResourceDefinition.nb` (metadata, hero image); the hub that the doc pages hang off |
| Symbol reference page | `wolfram-symbol-page` | one `ref/` page per exported/public symbol (Usage, Details, Examples, Scope) |
| Guide page | `wolfram-guide-page` | the paclet's landing page / curated function index (`guide/`) |
| Tech note / tutorial | `wolfram-tech-note` | a task- or concept-oriented tutorial (`tutorial/`) |
| Overview page | `wolfram-overview-page` | a navigable TOC index when the paclet has several guides / many pages |
| Computational essay | `wolfram-computational-essay` | a narrative prose-and-code notebook (Notebook Archive / Cloud), not a resource |
| Function Repository | `wolfram-function-resource` | a standalone deployable `ResourceFunction` |
| Data Repository | `wolfram-data-repository` | a curated dataset resource |
| Example Repository | `wolfram-example-repository` | an example/dataset resource with content elements |
| Prompt Repository | `wolfram-prompt` | an LLM persona / function / modifier prompt |
| Demonstration | `wolfram-demonstration` | an interactive `Manipulate` demonstration |

Shared references (read as needed, same repo):
`docs/README.md` (template map), `docs/doc-pages.md` (Symbol/Guide/TechNote
conventions), `docs/resource-notebooks.md` (resource templates),
`docs/examples.md` (the one-cell-per-demonstration rule), `GUIDE.md` (Wolfram
Language code style).

## Workflow

Run these in order. Confirm the plan with the user before generating files, and
**never destroy an existing `.nb` doc without backing it up first**.

### 1. Survey the project
- Find the paclet metadata: `PacletInfo.wl` / `PacletInfo.m` - read `Name`,
  `Version`, the context(s), and the `Documentation` extension.
- Find the source: `Kernel/*.wl` (or `*.m`). Enumerate the **public/exported
  symbols** (usage messages, `` `Package` `` exports, or symbols with
  `::usage`) - these become symbol pages.
- Find existing docs: `Documentation/English/**/*.nb`, a root
  `ResourceDefinition.nb`, `README*`, `docs/`, tutorials, papers.
- Decide the publish target: a **paclet** (ref/guide/tutorial pages), a
  **standalone resource** (Function/Data/Example/Prompt/Demonstration), or a
  **computational essay**. A project can want several.

### 2. Propose the doc set
Map the survey to concrete pages and confirm with the user (`AskUserQuestion`
if the scope is ambiguous). A typical paclet:
- 1 paclet definition (`wolfram-paclet`) if publishing to the Paclet Repository.
- 1 guide page (`wolfram-guide-page`) listing the functions.
- 1 symbol page per public symbol (`wolfram-symbol-page`).
- Tech notes for the main workflows (`wolfram-tech-note`).
- An overview page (`wolfram-overview-page`) if there is more than one guide or
  a large symbol set.

### 3. Back up existing `.nb` docs (do this BEFORE anything else)
If the project already has notebook docs, copy them somewhere safe first:
```bash
ts=$(date +%Y%m%d-%H%M%S)
mkdir -p "docs-backup-$ts"
# copy every generated/authored notebook out of harm's way
rsync -a --prune-empty-dirs --include='*/' --include='*.nb' --exclude='*' \
      Documentation "docs-backup-$ts/" 2>/dev/null
cp -f ResourceDefinition.nb "docs-backup-$ts/" 2>/dev/null || true
```
Tell the user where the backup went. Add the generated `.nb` output paths to
`.gitignore` (the `.md` is the source of truth; the `.nb` are rebuilt).

### 4. Port existing docs to `.md` (offer this)
If there are existing `.nb` docs, offer to **port them to markdown** so the
project switches to the markdown-as-source workflow rather than starting from a
blank page. Use the inverse converter,
[`NotebookToMarkdown`](https://github.com/WolframInstitute/MarkdownToNotebook)
(the round-trip twin of `MarkdownToNotebook`), then refine the result against
the matching authoring skill:
```wl
Get["NotebookToMarkdown.wl"];  (* from a WolframInstitute/MarkdownToNotebook checkout *)
Export["docs/Symbols/Foo.md", NotebookToMarkdown[Import["Documentation/English/ReferencePages/Symbols/Foo.nb"]], "Text"]
```
Non-notebook docs (a `README`, a paper, doc comments) are ported by hand into
the appropriate `.md` template. Always diff the ported `.md` against the backup
so nothing is silently dropped.

### 5. Author each page
For each planned page, read the matching sub-skill's `SKILL.md`, then write the
`.md` under `docs/` (mirroring the paclet layout: `docs/Symbols/`, `docs/Guides/`,
`docs/Tutorials/`, root `ResourceDefinition.md`). Follow that skill exactly for
frontmatter, the `[Symbol]()` / `` `code` `` link split, the
one-cell-per-demonstration rule, and `<!-- => ... -->` expected-result hints.

### 6. Build and publish with PacletPage
Never write a build script: PacletPage builds, packs and publishes every paclet
(see the `wolfram-paclet` skill for its release script). Install it from its
resource, in a fresh kernel for the newest release:
```wl
PacletInstall[ResourceObject["https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/PacletPage"]];
Needs["WolframInstitute`PacletPage`"]
```
`BuildPacletDocumentation[dir]` converts each `docs/**/*.md` into the paclet's
`Documentation/English/…` layout, keyed by its frontmatter `Template`, and
`ResourceDefinition.md` into `ResourceDefinition.nb`, with the paclet loaded so
example cells resolve its symbols. `DeployPacletResource[dir]` packs a fresh
archive, whose documentation build turns the authoring notebooks into finished
pages, checks it holds every page and loads alone, and deploys the paclet
resource; `PublishPacletPage[dir, name]` does all of it and publishes the
documentation site with its feedback form.

### 7. Verify
`BuildPacletDocumentation[dir]` must give `"Failed" -> {}` and
`"Unevaluated" -> <||>`: the second names the sections of a symbol page or the
definition that read a name only an earlier section defined, since those start
afresh at each heading and `---` (tutorials and Overview pages run in one
context). `PublishPacletPage[dir, name, "DryRun" -> True]` builds and loads the
archive and scrapes the resource without publishing; after a release, the
result's `"Check"` says whether the site, every page and the feedback form are
reachable. Open a built page and confirm the Examples render as their own
section.

## Guardrails
- **Backup before generate.** Step 3 is not optional if `.nb` docs exist.
- **Markdown is the source.** Generated `.nb` are gitignored; re-author the
  `.md` and rebuild, never hand-edit the notebook.
- **One demonstration per code cell.** No two unrelated computations in one
  `wl` cell (see `docs/examples.md`).
- **No `Needs[...]` in example cells** on doc pages - the page's context is
  loaded for you; put extra contexts in a `ContextPath:` frontmatter key.
- **Read the sub-skill first** for each page type; this orchestrator only
  routes - the real conventions live in those skills.
