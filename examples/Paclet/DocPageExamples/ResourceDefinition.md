---
Template: Paclet
ResourceType: Paclet
Name: WolframInstitute/DocPageExamples
Context: WolframInstitute`DocPageExamples`
Paclet: WolframInstitute/DocPageExamples
Description: One documentation page of every reference page type - format, service connection, device, interpreter, entity, character, message, program, workflow - each backed by real registered code
ContributedBy: Nikolay Murzin, Claude (Anthropic)
Keywords: [documentation, page types, format, service connection, device, interpreter, entity, character, message, program, workflow, markdown]
MainGuide: Documentation/English/Guides/DocPageExamples.nb
License: MIT
WolframVersion: 14.3+
Categories: [Notebook Documents & Presentation]
SourceControlURL: https://github.com/WolframInstitute/MarkdownToNotebook
Links: ["[MarkdownToNotebook - the converter that builds these pages](https://github.com/WolframInstitute/MarkdownToNotebook)"]
---

## Details & Options

- The Wolfram documentation system has a page type for each kind of thing it documents: an *import/export format*, a *service connection*, a *device*, an *interpreter type*, an *entity type*, a *named character*, a *message*, a *command-line program*, a *workflow*, and a *workflow guide*. Each has its own cell styles, title decoration, and URI kind.
- This paclet carries exactly one page of each, so the whole roster can be seen side by side in one place.
- Every page is authored as plain markdown and converted with `MarkdownToNotebook`; nothing here is hand-edited notebook markup.
- The point is that the pages are *honest*: loading the paclet registers the format, the service, the device class, and the entity store for real, so every example on every page evaluates in an ordinary kernel with no network, no hardware, and no credentials.

## Basic Description

Loading the paclet registers a plain-text maze format (`MAZE`), a local
placeholder-text service (`"Lorem"`), a simulated signal device
(`"RandomSignal"`), and an entity type (`"WallpaperGroup"`); it defines
[MazeGenerate]() and [MazeParse]() and ships a `mazegen` command-line script.
Those exist so that the ten documentation pages describing them have something
true to describe.

## Basic Examples

The `MAZE` format is registered on load, so a maze imports as a character matrix:

```wl
ImportString["#####\n#S..#\n###.#\n#..G#\n#####", "MAZE"]
```

---

Its `"Graphics"` element renders the same maze:

```wl
ImportString["#####\n#S..#\n###.#\n#..G#\n#####", {"MAZE", "Graphics"}]
```

---

`MazeGenerate` builds a random perfect maze of any size:

```wl
SeedRandom[42];
Column[StringJoin /@ MazeGenerate[{4, 8}]]
```

---

The `"Lorem"` service connects with no credentials and runs entirely in the kernel:

```wl
ServiceExecute[ServiceConnect["Lorem"], "Sentence", {"Words" -> 6, "Seed" -> 42}]
```

## Scope

`MazeParse` pads ragged input and issues [MazeParse::ragged]() when it does:

```wl
MazeParse[{"#####", "#S.#"}]
```

---

The `"WallpaperGroup"` entity type answers property queries like any other:

```wl
EntityValue[Entity["WallpaperGroup", "p4m"], {"LatticeType", "PointGroupOrder"}]
```

---

The `"RandomSignal"` device opens, reads, and closes through the device framework:

```wl
SeedRandom[7];
With[{dev = DeviceOpen["RandomSignal"]}, {DeviceRead[dev], DeviceClose[dev]}]
```

## Applications

Generate a maze and render it through the format's own `"Graphics"` element,
the two halves of the paclet meeting in one expression:

```wl
SeedRandom[2024];
ImportString[StringRiffle[StringJoin /@ MazeGenerate[{8, 12}], "\n"], {"MAZE", "Graphics"}]
```

---

Solve a generated maze by treating open cells as a graph and finding the path
from `S` to `G`:

```wl
SeedRandom[11];
With[{grid = MazeGenerate[{6, 9}]},
 With[{open = Position[grid, "." | "S" | "G"]},
  With[{g = Graph[UndirectedEdge @@@ Select[Subsets[open, {2}], ManhattanDistance @@ # == 1 &]]},
   Highlighted[
    ArrayPlot[Replace[grid, {"#" -> 1, _ -> 0}, {2}], Mesh -> All, ImageSize -> 320],
    FindShortestPath[g, First @ Position[grid, "S"], First @ Position[grid, "G"]] // Length]]]]
```

## Hero Image

A maze from `MazeGenerate`, rendered through the `MAZE` format's own
`"Graphics"` import element. The maze is inlined as literal `MAZE` text so the
image depends on nothing but the registered format - the hero cell is the one
cell a resource notebook evaluates outside the documentation's own context:

```wl
ImageResize[
 Rasterize[
  Framed[
   Column[{
      Style["DocPageExamples", 30, Bold, GrayLevel[0.15], FontFamily -> "Source Sans Pro"],
      Style["one documentation page of every reference page type", 13, GrayLevel[0.45], FontFamily -> "Source Sans Pro"],
      Spacer[16],
      Show[
        ImportString[StringRiffle[{
           "#############################", "#S#.......#.........#.....#.#",
           "#.#.###.#.#.#######.#.#.#.#.#", "#.#.#.#.#.#.#.....#...#.#.#.#",
           "#.#.#.#.#.#.#.###.#####.#.#.#", "#.#...#.#.#.#...#.......#...#",
           "#.###.#.#.#.###.###########.#", "#...#.#.#.#.#...#.#.......#.#",
           "###.#.#.#.#.#.###.#.###.###.#", "#.#.#.#.#.#.#.#.......#...#.#",
           "#.#.#.#.###.#.#######.###.#.#", "#.#.#.#.....#.......#.#...#.#",
           "#.#.#.#############.#.#.###.#", "#.#.#.#...#.......#.#.#.....#",
           "#.#.###.#.#.#####.#.#.#######", "#.......#...#.......#......G#",
           "#############################"}, "\n"], {"MAZE", "Graphics"}],
        ImageSize -> {Automatic, 260}]},
     Alignment -> Center, Spacings -> 0.9],
   Background -> GrayLevel[0.98], FrameMargins -> 30, FrameStyle -> GrayLevel[0.9], RoundingRadius -> 16],
  ImageResolution -> 144, Background -> None],
 {Automatic, 500}]
```
