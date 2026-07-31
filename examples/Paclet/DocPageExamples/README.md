# DocPageExamples

A minimal **real** paclet backing one markdown-authored documentation page of
every reference subtype `MarkdownToNotebook` supports beyond Symbol / Guide /
TechNote:

| Page | Template | The real thing behind it |
|---|---|---|
| [MAZE](docs/MAZE.md) | `Format` | a registered `Import`/`Export` format (`ImportString[..., "MAZE"]` works) |
| [Lorem](docs/Lorem.md) | `ServiceConnection` | a local `ServiceConnect["Lorem"]` service (framework connection, no network) |
| [RandomSignal](docs/RandomSignal.md) | `Device` | a registered `DeviceOpen["RandomSignal"]` device class |
| [Integer](docs/Integer.md) | `Interpreter` | the system `Interpreter["Integer"]` type |
| [WallpaperGroup](docs/WallpaperGroup.md) | `Entity` | a registered `EntityStore` (six plane symmetry groups) |
| [CirclePlus](docs/CirclePlus.md) | `Character` | the system `\[CirclePlus]` character |
| [MazeParse::ragged](docs/MazeParse-ragged.md) | `Message` | a real message the paclet's `MazeParse` issues |
| [mazegen](docs/mazegen.md) | `Program` | `Scripts/mazegen.wls`, a wolframscript CLI over `MazeGenerate` |
| [Filter a Dataset](docs/FilterADataset.md) | `Workflow` | plain system code, every step evaluates |
| [Data Wrangling](docs/DataWrangling.md) | `WorkflowGuide` | a curated index of workflow pages |

Loading the paclet registers the MAZE format, the Lorem service, the
RandomSignal device class, and the WallpaperGroup entity store - so every
example cell on every page **evaluates for real** at documentation build time,
headlessly, with no network.

The paclet's own front page is the [guide](docs/DocPageExamples.md), and
[`ResourceDefinition.md`](ResourceDefinition.md) is its Paclet Repository
definition - both authored in markdown like everything else.

## Build

```
wl -f build.wls        (or:  wolframscript -f build.wls)
```

converts each `docs/*.md` to its authoring notebook under `build/DocSource`
(one directory per page type: `ReferencePages/Formats`, `.../Services`,
`.../Devices`, ..., `Workflows`, `WorkflowGuides`), then runs
`DocumentationBuild` into `DocPageExamples/Documentation` with the navigation
index and search index a shipping paclet needs, and finally builds
`ResourceDefinition.md` into the paclet's `ResourceDefinition.nb`.

## Deploy

```
wl -f deploy.wls       (or:  wolframscript -f deploy.wls)
```

scrapes the definition notebook and `CloudDeploy`s the resource publicly to
`<account>/DeployedResources/Paclet/WolframInstitute/DocPageExamples`, so the
resource page and every documentation page it bundles can be viewed online
without submitting to the repository. Prints the public URL.
