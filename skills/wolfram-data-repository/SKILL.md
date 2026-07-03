---
name: wolfram-data-repository
description: Author a Wolfram Data Repository resource (a curated dataset packaged with its statistical metadata, primary content, named accessors, and worked examples) as a literate-markdown document and convert it to the official definition notebook with MarkdownToNotebook. Use this whenever the user wants to create, write, draft, or publish a Wolfram Data Repository submission, a Data resource, a dataset accessible via ResourceData / WolframDataRepository, or anything that says `Template: Data` / `ResourceType: Data` - especially when they would rather write markdown than hand-edit notebook cells. Also use it when asked to add content elements, statistical metadata, or examples to such a resource.
---

# Authoring a Data Repository resource in markdown

`MarkdownToNotebook` fills the official Data Repository definition notebook (the
one `CreateNotebook["DataResource"]` opens, with its docked Deploy / Submit /
Check toolbar) from a literate-markdown document. A Data resource packages a
curated dataset together with its statistical metadata (author, publisher, date,
geographic / temporal coverage, license, citation), one primary content payload,
any number of named accessors, and worked examples that demonstrate the data.
The author writes YAML frontmatter and `## section` headings; the converter
chooses every cell style. Use the `Data` template.

The canonical worked example is the seventeen wallpaper groups dataset at
[examples/WallpaperGroups.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/examples/WallpaperGroups.md)
- a flat `Association` of records keyed by IUC symbol, with two named accessors
(`ByLattice`, `ByPointGroup`) and the four canonical example subsections.
Model new documents on it, and read
https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/data-repository.md
for the slot-by-slot mapping (every Markdown key -> template slot -> notebook
cell shape).

Read first - the canonical guidelines:

- Data Repository submission guidelines (the rules a submission is reviewed against): https://resources.wolframcloud.com/DataRepository/guidelines
- Data Repository style guidelines: https://resources.wolframcloud.com/DataRepository/style-guidelines
- Write Data Resource Examples (the `$$Object` / `$$Data` convention used by the example cells): https://reference.wolfram.com/language/workflow/WriteDataResourceExamples.html
- Use Data from the Wolfram Data Repository (retrieval patterns the examples should demonstrate): https://reference.wolfram.com/language/workflow/UseDataFromTheWolframDataRepository.html
- Wolfram Language code style: https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/GUIDE.md

## Frontmatter

Fence a `key: value` YAML header with `---` at the very top. The keys mirror the
template's metadata slots (see
[docs/data-repository.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/data-repository.md)
for the full table):

```
---
Template: Data
ResourceType: Data
Name: Seventeen Wallpaper Groups
Description: One-line summary of what the dataset is
ContributedBy: Author Name
Keywords: [symmetry, wallpaper group, crystallography]
Categories: [Mathematics]
ContentTypes: [Numerical Data, Entity Store]
Author: First Last
Date: 2026
Publisher: Original Publisher
GeographicCoverage: Global
TemporalCoverage: Timeless
Language: English
Rights: CC0
Citation: "Last, F. (2026). Dataset Name. Wolfram Data Repository."
RelatedSymbols: [Polygon, GroupOrder]
Links: ["[Wikipedia](https://en.wikipedia.org/wiki/Wallpaper_group)"]
SubmissionNotes: Optional one sentence for the reviewer
---
```

What each key means:

- `Name` - the resource's display name; specific, plain text. Required.
- `Description` - one line, plain text, no ending punctuation. Required.
- `ContributedBy` - public contributor credit shown on the resource page. Required.
- `Author` (alias `SMDAuthor`) - statistical-metadata original author; falls
  back to `ContributedBy` if omitted.
- `Date` (alias `SMDDate`) - original publication year / date of the dataset.
- `Publisher` (alias `SMDPublisher`) - original publisher of the dataset.
- `GeographicCoverage` - place coverage (`Global`, a country, a region, ...).
- `TemporalCoverage` - time coverage (a year, range, or `Timeless`).
- `Language` - dataset language (`English`, ...).
- `Rights` - free-text licensing / rights statement (e.g. `CC0`, `CC BY 4.0`,
  `Public Domain`, or a one-line custom statement). Not a fixed dropdown.
- `Citation` - the bibliographic citation, quoted so internal commas survive.
  Alternatively a `## Citation` section.
- `Keywords` - flat metadata list.
- `Categories` - fixed checkbox grid; see the valid list below. Always set it.
- `ContentTypes` - fixed checkbox grid; see the valid list below. Always set it.
- `RelatedSymbols` (alias `SeeAlso`) - related Wolfram Language symbols.
- `Links` - related external links, each `"[label](url)"`.
- `SubmissionNotes` - private notes to the reviewer (only visible pre-submission).

`Categories` fills a fixed checkbox grid for Data resources, so each entry must
be one of the official Data Repository categories (pick the one or few that
fit; do not invent names). The valid set is exactly these 34 (from
`` ResourceSystemClient`Private`resourceSortingProperties[][DataResource]["Categories"] ``):
Agriculture, Astronomy, Chemistry, Computational Universe, Computer Systems,
Culture, Demographics, Earth Science, Economics, Education, Engineering,
Geography, Geometry Data, Government, Graphics, Health, Healthcare, History,
Human Activities, Images, Language, Life Science, Machine Learning,
Manufacturing, Mathematics, Medicine, Meteorology, Physical Sciences,
Politics, Reference, Social Media, Sociology, Statistics,
Text & Literature, Transportation.

`ContentTypes` fills the other fixed checkbox grid. The valid set is exactly
these 10 (same registry):
Audio, Entity Store, Geospatial Data, Graphs, Image, Numerical Data, Text,
Time Series, Vector Database, Video.

An empty `Categories` or `ContentTypes` grid is a submission hint, so always
set both.

## Conventions

The cross-template conventions live in three docs - point at them, do not
duplicate:

- [docs/resource-guidelines.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/resource-guidelines.md)
  for the shared rules (Name, Description, Author Notes, Links, straight
  quotes, ...).
- [docs/examples.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/examples.md)
  for the one-demonstration-per-cell / one-sentence `:`-terminated caption /
  `---`-between-siblings example-authoring rule that every Data example
  section must follow.
- [docs/formatting.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/formatting.md)
  for inline formatting: backtick `` `code` `` -> Template Input, inline math
  `$...$`, and inferred symbol links written as `<code>[Range]()</code>`.

## Data payload shape (the `## Content` section)

A Data resource has **one primary content** payload plus zero or more **named
additional content elements**. Both are authored inside a single `## Content`
section, one `wl` cell per element. Each cell becomes an `Input` cell carrying
the `DefaultContent` tag the scraper needs.

Inside the deployed notebook the special expression
`ResourceObject[EvaluationNotebook[]]` resolves to "this resource"; outside it
(in headless conversion or in your editor) it does not. So mark every content
cell `#| eval: false` - the converter still inserts the code into the
definition notebook, and the cell evaluates correctly once the notebook is
opened in the front end.

The two cell shapes:

- **Primary content** - one cell, no string key:

  ````
  ```wl
  #| eval: false
  ResourceData[ResourceObject[EvaluationNotebook[]]] = myData
  ```
  ````

  This populates `$$Data` for every example cell.

- **Additional data elements** - any number of named cells:

  ````
  ```wl
  #| eval: false
  ResourceData[ResourceObject[EvaluationNotebook[]], "ByLattice"] =
      GroupBy[Values[myData], #["Lattice"] &, Length]
  ```
  ````

  Each becomes a named accessor reachable as
  `ResourceData[ResourceObject["<Name>"], "ByLattice"]`.

The actual data payload can be anything `Compress`-able and small enough to
ship as part of the resource. Common shapes:

- An `Association` of records keyed by a natural identifier (the wallpaper
  groups example).
- A `Dataset[...]` (a tabular dataset; gets the Dataset display panel).
- An `EntityStore[...]` for a typed entity catalog with computable properties
  (declare `ContentTypes: [Entity Store]`).
- A packed numerical array, time series (`TimeSeries`, `TemporalData`), graph
  (`Graph`), image (`Image`), or audio (`Audio`) value, each shown with the
  appropriate output cell.
- For very large data, ship a small "schema / header" payload as primary
  content and link to the bulk source via `Links`.

Define helper values used by the examples *inside* the `## Content` cell that
sets up `myData` so they are in scope for the examples too, or recompute them
inline in the example section.

## Example sections

The Data template's `ExampleNotebook` slot has **four canonical subsections**,
filled in this order by the matching `##` headings (absent sections are
skipped):

- `## Basic Examples` - start with the simplest use: look up one entry, show
  the length, show the head.
- `## Scope & Additional Elements` - exercise the named accessors and the
  breadth of the dataset (group-by counts, slice by a key, etc.).
- `## Visualizations` - one or more plots / graphics derived from the data.
- `## Analysis` - deeper analyses or properties the data exposes (e.g.
  invariants, statistics, derived quantities).

Per the [official `$$Object` / `$$Data` convention](https://reference.wolfram.com/language/workflow/WriteDataResourceExamples.html),
the deployed example cells receive two injected variables:

- `$$Object` - the `ResourceObject` the notebook defines.
- `$$Data` - its primary `ResourceData`.

Prefer `$$Object` / `$$Data` over hard-coded `ResourceObject["Name"]` /
`ResourceData["Name"]` so the examples stay correct as the deployed name and
version change. Mark any cell that mentions `$$Object` / `$$Data` `#| eval:
false` (they do not resolve headlessly); for runnable demonstrations, compute
the same expression inline against the local symbol (the wallpaper-groups
example uses `wallpaperGroups[...]` directly so the conversion produces real
`Out[]` cells).

Each example follows the same one-demonstration-per-cell /
one-sentence `:`-terminated caption / `---`-between-siblings rule
[docs/examples.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/examples.md)
documents once. Record an expected result with an `<!-- => ... -->` comment
after a cell.

## Other sections

- `## Details` - prose, bullets, and pipe tables explaining what the data is,
  how it was collected, and how to interpret the fields. Each bullet becomes
  its own `Notes` cell; a markdown pipe table becomes a `TableNotes` grid.
  Inline math is `$...$`.
- `## Citation` - alternative to the `Citation` frontmatter key, when the
  citation is long enough that a section is cleaner.
- `## Author Notes` - optional prose, fills the Author Information panel.

## Code-cell options

A fenced `wl` cell carries `#|` option lines at the top (the Quarto cell-option
convention), one `key: value` per line: `eval: false` (show code without
running - **required for `## Content` cells and any cell using `$$Object` /
`$$Data`**), `file: path` (replace the body with a local file or URL),
`screenshot: true` (rasterize a produced `Notebook`), `tear: h` (torn-paper
screenshot capped to `h` points), `flag: future|excised|...`. To link a
documented symbol inline, wrap an inferred ref in `<code>`:
`<code>[Range]()</code>` (the empty parens make markdown viewers render it as
a clickable link, and the `<code>` wrapper applies code styling).

## Author Notes

AI-authorship disclosure is **required** when the resource was drafted or
substantially edited with help from an LLM-based assistant - identify the
model, the human supervisor, and which parts are model-generated vs
hand-edited. The minimum-bar template and rationale live in
[the AI-assisted authoring disclosure section of resource-guidelines.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/resource-guidelines.md#ai-assisted-authoring-disclosure-author-notes);
the text fills the same Author Notes slot in the Data template that it does
in every other resource template.

## Worked example

See [examples/WallpaperGroups.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/examples/WallpaperGroups.md)
for the canonical end-to-end document: frontmatter with every statistical-
metadata field set, `## Details` with bullets and inline math, `## Content`
with one primary payload and two named accessors (all `#| eval: false`),
and all four example subsections (`## Basic Examples`,
`## Scope & Additional Elements`, `## Visualizations`, `## Analysis`)
filled in.

## Convert and deploy

```
(* MarkdownToNotebook is not on the public Function Repository yet, so use
   its public cloud deployment *)
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
mtn["WallpaperGroups.md", "WallpaperGroups.nb"]
```

To deploy publicly, do **not** rely on a headless `DeployResource` (it scrapes
an empty definition); scrape the notebook into a `ResourceObject` and
`CloudDeploy` the resulting Data resource - see the deploy note in
https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/subtleties.md .
Submit to the repository with the docked Submit button or `ResourceSubmit`.
Before submitting, run `` DefinitionNotebookClient`CheckDefinitionNotebook[nbo] ``
and clear its hints (that doc lists the common ones and their fixes).

## Check

Before submission, run the docked *Check* button (top of every resource
definition notebook) - it lints the document against the submission
guidelines and reports hints by level. Headless, the same lint runs through
`` DefinitionNotebookClient`CheckDefinitionNotebook[nbo] `` after stamping
CellIDs and saving (the headless build does not assign CellIDs, and the
scraper needs them to locate cells):

```wl
Needs["DefinitionNotebookClient`"]
UsingFrontEnd @ Block[{nbo = NotebookOpen[File["MyDataset.nb"]]},
    CurrentValue[nbo, CreateCellID] = True;
    SelectionMove[nbo, All, Notebook];
    FrontEndTokenExecute[nbo, "Save"];
    Normal @ DefinitionNotebookClient`CheckDefinitionNotebook[nbo]
]
```

Each row is `<|"Level" -> ..., "Tag" -> ..., "Parameters" -> ...|>` with
`Level` one of `Suggestion` / `Warning` / `Error`. Common tags to address
before submission: `DescriptionTooLong` (shorten to under 128 chars),
`ExampleTextLastCharacter` (end an example caption with `:`),
`FoundUnformattedCode` (wrap a stray WL symbol in `` `backticks` `` or in
an inferred link with empty parens like `[Range]()` (substitute the actual
symbol name for `Range`)), `ThreeDotEllipsis` (use `…` not `...`),
`NotASystemSymbol` (link foreign function-repo names instead of formatting
them as system symbols), `LargeCellBounds/CellHeight` (rasterized output too
big - crop it with `#| tear: h` or shrink the source). The repo's
`check.wls` runs the same lint on every built `.nb` and prints a per-file
summary.

## TODO - verify against Wolfram Data Repository submission requirements

A few details could not be fully verified from inside the repo / installed
kernel and should be checked against the live Data Repository submission
flow before treating them as canonical:

- **`Rights` registry** - the Data template's `SMDRights` slot is a free-text
  cell with default placeholder "Data Rights" (verified via
  `` DefinitionNotebookClient`DefinitionTemplate["Data"] ``), so this skill
  treats it as freeform. If the live submission UI enforces a closed set of
  license labels (CC0 / CC BY / Public Domain / ...), that constraint is not
  surfaced here.
- **Required vs optional statistical-metadata fields** - the slot mapping in
  [docs/data-repository.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/data-repository.md)
  documents which slots exist, but does not say which the Check pass treats
  as required. The conservative read is that `Author` / `Date` / `Publisher`
  / `GeographicCoverage` / `TemporalCoverage` / `Language` / `Rights` /
  `Citation` should all be set; whether the reviewer rejects on a missing
  one was not directly checked.
- **Maximum dataset size / `Compress`-ability** - the resource ships its
  primary content embedded in the deployed notebook, but the exact size
  threshold above which a submission is rejected is not documented here.
  Re-check the live guidelines for large datasets.
