---
name: wolfram-paclet
description: Author a Wolfram Language paclet's definition (ResourceDefinition.md) in literate markdown, and build, deploy, submit and publish the paclet with the PacletPage paclet - documentation notebooks from markdown, a checked paclet resource, the Paclet Repository submission and a documentation site with feedback. Use this whenever the user wants to create, write, build, release or publish a Wolfram Language paclet, a Paclet Repository resource, a paclet ResourceDefinition (metadata, usage, examples, hero image), or a paclet's documentation site. Pair it with the Symbol, Guide, and TechNote skills, which author the paclet's documentation pages.
---

# Paclets: a markdown definition, built and published with PacletPage

A paclet is its code (`PacletInfo.wl`, `Kernel/`), its documentation pages written as markdown
under `docs/`, and its definition, `ResourceDefinition.md`, at its root. The
[PacletPage](https://github.com/WolframInstitute/PacletPage) paclet takes it from that markdown to
a published paclet: the documentation notebooks, the paclet resource deployed to the cloud, the
Paclet Repository submission and a documentation site with a feedback form, each step without a
front end. Never write build, deploy or submit scripts of your own; a paclet's release script is a
few lines calling `PublishPacletPage`.

Worked examples: PacletPage itself (its
[ResourceDefinition.md](https://github.com/WolframInstitute/PacletPage/blob/main/ResourceDefinition.md),
[docs/](https://github.com/WolframInstitute/PacletPage/tree/main/docs) and
[release.wls](https://github.com/WolframInstitute/PacletPage/blob/main/release.wls), published at
https://www.wolframcloud.com/obj/wolframinstitute/PacletPage), and the AccessibleColors definition
at https://github.com/sw1sh/AccessibleColors/blob/main/ResourceDefinition.md . Read
https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/resource-notebooks.md and
https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/resource-guidelines.md for
the slot mapping and Paclet Repository rules.

Author the pages with the `wolfram-guide-page`, `wolfram-symbol-page`, and `wolfram-tech-note`
skills; the metadata here must agree with `PacletInfo.wl`.

Read first - the canonical guidelines:

- Paclet Repository, creating paclets: https://resources.wolframcloud.com/PacletRepository/creating-paclets
- Paclet Repository, submission guidelines (the rules a paclet is reviewed against): https://resources.wolframcloud.com/PacletRepository/guidelines
- Wolfram Language code style: https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/GUIDE.md

## Layout

```
MyPaclet/
|-- PacletInfo.wl           name, version, description, the Kernel extension's symbols
|-- Kernel/                 the code
|-- ResourceDefinition.md   the paclet resource's definition (this skill)
|-- docs/
|   |-- Guides/*.md         wolfram-guide-page
|   |-- Symbols/*.md        wolfram-symbol-page
|   `-- Tutorials/*.md      wolfram-tech-note
`-- release.wls             PublishPacletPage, nothing else
```

`PacletInfo.wl` declares a `{"Documentation", "Language" -> "English"}` extension beside its
`"Kernel"` one, and lists the paclet's public symbols under the Kernel extension's `"Symbols"`. Git
ignores what the build makes: `build/`, `Documentation/`, `*.paclet`, `ResourceDefinition.nb`.

## Frontmatter

```
---
Template: Paclet
ResourceType: Paclet
Name: Publisher/PacletName
Context: Publisher`PacletName`
Paclet: Publisher/PacletName
Description: WCAG color-contrast and accessibility utilities for the Wolfram Language
ContributedBy: Author Name
Keywords: [keyword one, keyword two]
MainGuide: Documentation/English/Guides/PacletName.nb
License: MIT
WolframVersion: 14.0+
Categories: [Visualization & Graphics]
Disclosures: [LocalFiles, ExternalServices]
Sources: ["A bibliographic citation"]
SourceControlURL: https://github.com/you/PacletName
Links: ["[label](https://example.com)"]
---
```

Notes that bite (see
https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/subtleties.md):
`Name`/`Paclet` include the publisher ID (`Publisher/PacletName`); `MainGuide` is the
**relative** notebook path, not a bare name; `Description` must match `PacletInfo.wl`'s
`"Description"` exactly; each `Sources` entry is one citation (commas inside it are preserved);
`SourceControlURL` is the source link on the resource page. `Categories` fills a fixed checkbox
group, so always set it to one or more **valid Paclet Repository categories** (do not invent
names) - an empty group is a submission hint. The valid set is exactly these 23 (from
`ResourceSystemClient`Private`resourceSortingProperties["Paclet"]["Categories"]`):
Cloud & Deployment, Core Language & Structure, Data Manipulation & Analysis,
Engineering Data & Computation, External Interfaces & Connections,
Financial Data & Computation, Geographic Data & Computation, Geometry,
Graphs & Networks, Higher Mathematical Computation, Images,
Knowledge Representation & Natural Language, Machine Learning,
Notebook Documents & Presentation, Scientific and Medical Data & Computation,
Social, Cultural & Linguistic Data, Sound & Video, Strings & Text,
Symbolic & Numeric Computation, System Operation & Setup,
Time-Related Computation, User Interface Construction, Visualization & Graphics.

`Disclosures` toggles the standalone disclosure checkboxes in the Paclet template's
**Disclosures** section. Each name is independent (unlike Categories these are nine separate
checkboxes, not one CheckboxesCell). Only set the ones whose trigger your paclet actually meets -
the submission reviewer reads them. Valid set (from the Paclet template's `CheckboxBox`
`{False, name}` tags):

- `LocalFiles` - creates / deletes / modifies / imports local files (the loader's own IO is excepted).
- `ExternalServices` - calls non-Wolfram network services (REST APIs, web scraping, sockets, ...).
- `LocalSystemInteractions` - shells out to external processes, reads the clipboard, controls another app, accesses sensors.
- `OSConfiguration` - mutates OS-level settings (environment variables, scheduled tasks, registry, ...).
- `PacletDependencies` - depends on other paclets being installed.
- `WLSystemConfiguration` - mutates the kernel environment: `$ContextPath`, `$Path`, persistent values, persistent objects, ...
- `WLSystemSymbols` - defines or `Set`s values on `` System` `` symbols (or another paclet's context).
- `WolframAccount` - uses Wolfram ID, the user's cloud account / cloud objects, Wolfram credits, scheduled cloud tasks, WolframAlpha calls.
- `Other` - any disclosure not covered above (describe it in the section's text area).

## Sections

- `## Details & Options` - bullets become `Notes` cells; pipe tables become grids.
- `## Usage` - the symbols the paclet provides, as `<code>[Range]()</code>` inferred reference
  links (the `<code>` wrapper applies code styling, the empty parens make markdown viewers render
  it as a clickable link).
- Example sections (`## Basic Examples`, `## Scope`, `## Applications`, ...) - follow the
  example-authoring rule in [docs/examples.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/examples.md)
  (one demonstration per cell, one-sentence `:`-terminated caption, `---` between siblings).
  The definition, like a symbol page, evaluates each section and each example between `---` in a
  clean context, so every one must define what it uses: a section that reads a name only an
  earlier section defined is left unevaluated, and the build reports it under `"Unevaluated"`.
- `## Hero Image` - the landing-page image. Its first executable cell is evaluated; show the
  image and keep the generating code in a closed group (the converter uses the
  `Cell[CellGroupData[{input, output}, {2}]]` idiom). The scraped image must be 400-1500 px on
  each side with aspect ratio `h/w` in 0.5-1.25, or the build flags
  `HeroImageTooSmall`/`TooLarge`/`Squashed`. A ready image can ship as a paclet asset loaded with
  `Import[PacletObject["Publisher/PacletName"]["AssetLocation", "Hero"], "WXF"]`; keep it as WXF,
  since importing a PNG on 15.1 first installs ImageMetadataTools from GitHub.
- `## Author Notes` - optional prose, fills the Author Information panel. **Required when the
  paclet was drafted with help from an AI assistant**: identify the model, the human supervisor,
  and which parts are model-generated vs hand-edited. See the [AI-assisted authoring
  disclosure](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/resource-guidelines.md#ai-assisted-authoring-disclosure-author-notes)
  section of the resource guidelines for the minimum-bar template.

## Code-cell options

`#|` lines at the top of a fenced `wl` cell: `eval`, `file`, `screenshot`, `tear`, `flag`,
`boxes` (one `key: value` per line). `#| boxes: true` reads the body as a literal box expression
(`RowBox`, `GridBox`, `TemplateBox`, `TooltipBox`, ...) and splices it into a
`Cell[BoxData[…], "Input"]` unchanged - useful for showing a hand-built box decoration without
round-tripping through evaluation. Inline math is `$...$`; to link a documented symbol inline,
wrap an inferred ref in `<code>`: `<code>[Range]()</code>`.

## Build, deploy and publish with PacletPage

Install PacletPage from its resource, in a fresh kernel for the newest release:

```wl
PacletInstall[ResourceObject["https://www.wolframcloud.com/obj/wolframinstitute/DeployedResources/Paclet/WolframInstitute/PacletPage"]];
Needs["WolframInstitute`PacletPage`"]
```

| Function | |
|---|---|
| `BuildPacletDocumentation[dir]` | `docs/**/*.md` into `Documentation/English` notebooks and `ResourceDefinition.md` into `ResourceDefinition.nb`, with MarkdownToNotebook; unchanged pages from a cache, the rest evaluated afresh |
| `DeployPacletResource[dir]` | a fresh archive, checked to hold every documentation page and to load alone in a fresh kernel, deployed as the paclet resource in the connected account, with its hero image, version and git commit |
| `SubmitPacletResource[dir]` | the same archive, the definition notebook checked, submitted to the Paclet Repository |
| `PublishPacletPage[dir, name]` | all of it, and the documentation site `name` with its feedback form; `"Submit" -> True` submits too |

A paclet's `release.wls`:

```wl
Needs["WolframInstitute`PacletPage`"];
dir = DirectoryName[$InputFileName];
release = PublishPacletPage[dir, "PacletName",
    "Account" -> "publisher@example.org",
    "DryRun" -> MemberQ[Rest[$ScriptCommandLine], "--dry-run"],
    "SiteOptions" -> {"FeedbackOptions" -> {"Domains" -> {"example.org"}}}
];
If[ ! AssociationQ[release] || release["Build"]["Failed"] =!= {} || release["Build"]["Unevaluated"] =!= <||>, Exit[1]];
Exit[If[release["Check"] === None || TrueQ[release["Check"]["OK"]], 0, 1]]
```

- Run it in a kernel connected to the account that publishes; with `"Account"`, any other
  connected account is refused before anything is built.
- Commit the paclet first and raise its `"Version"` in `PacletInfo.wl` for every release: the
  release records the git commit, and a version already released from another commit is refused.
- `"DryRun" -> True` builds the documentation and the archive, loads it and scrapes the resource,
  but publishes nothing.
- A failed or unevaluated page fails the release: `release["Build"]["Failed"]` names the pages
  that did not convert, `release["Build"]["Unevaluated"]` the sections that read a name only an
  earlier section defined.
- A tutorial or an Overview page runs in one context, so its later sections use what earlier ones
  define; the definition and the symbol pages start afresh at each heading and `---`.
- A large paclet: `"BuildOptions" -> {"Parallel" -> n}` converts on parallel kernels, and
  `"ResourceOptions" -> {"Parallel" -> n, "Incremental" -> True}` builds only the changed pages.
  `"ResourceOptions" -> {"Exclude" -> {...}}` leaves out files, such as a runtime the paclet links
  to from a toolchain, which is refused otherwise.
- Submitting puts the paclet in front of the Paclet Repository's reviewers: pass `"Submit" -> True`,
  or call `SubmitPacletResource`, only when the user asks for it.
- A deployed paclet installs with `PacletInstall[ResourceObject[url]]`, `url` the deployed
  resource's.

To preview the definition notebook alone, convert it with the published converter:

```wl
mtn = ResourceFunction[ResourceObject["https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook"]];
mtn["ResourceDefinition.md", "ResourceDefinition.nb"]
```

## Check

`SubmitPacletResource[dir, "DryRun" -> True]` runs the Paclet Repository's own check of the
definition notebook, and stops on an error, before anything is submitted. To read every hint,
run the check as the docked *Check* button does, after stamping CellIDs and saving (the headless
build does not assign CellIDs, and the scraper needs them to locate cells):

```wl
Needs["DefinitionNotebookClient`"]
UsingFrontEnd @ Block[{nbo = NotebookOpen[File["ResourceDefinition.nb"]]},
    CurrentValue[nbo, CreateCellID] = True;
    SelectionMove[nbo, All, Notebook];
    FrontEndTokenExecute[nbo, "Save"];
    Normal @ DefinitionNotebookClient`CheckDefinitionNotebook[nbo]
]
```

Each row is `<|"Level" -> ..., "Tag" -> ..., "Parameters" -> ...|>` with `Level` one of
`Suggestion` / `Warning` / `Error`. Common tags to address before submission:
`DescriptionTooLong` (shorten to under 128 chars), `ExampleTextLastCharacter` (end an example
caption with `:`), `FoundUnformattedCode` (wrap a stray WL symbol in `` `backticks` `` or in an
inferred link with empty parens like `[Range]()` (substitute the actual symbol name for `Range`),
`ThreeDotEllipsis` (use `…` not `...`), `NotASystemSymbol` (link foreign function-repo names
instead of formatting them as system symbols), `LargeCellBounds/CellHeight` (rasterized output
too big - crop it with `#| tear: h` or shrink the source).

After a release, `CheckPacletPage[PacletPageCatalog[resourceURL], "PacletName"]` checks, as an
anonymous reader, that the site, every page and the feedback form are reachable.
