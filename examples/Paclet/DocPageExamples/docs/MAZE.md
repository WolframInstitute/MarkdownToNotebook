---
Template: Format
Name: MAZE
Extension: .maze
Context: WolframInstitute`DocPageExamples`
Paclet: WolframInstitute/DocPageExamples
URI: WolframInstitute/DocPageExamples/ref/format/MAZE
Description: Plain-text format for rectangular maze levels with walls, open cells, start and goal markers.
Keywords: [maze, grid, level, ascii, game]
SeeAlso: [Import, Export, ImportString, ExportString, ArrayPlot]
RelatedGuides: [DocPageExamples]
---

# MAZE

MAZE is a plain-text format for rectangular two-dimensional maze levels. Each file stores a single level as an ASCII character grid and is the native level format of the WolframInstitute/DocPageExamples paclet.

## Background & Context

- MIME type: `text/x-maze`.
- MAZE is a plain-text ASCII format storing one rectangular maze level per file.
- Each line of the file is one row of the maze; all lines have equal length.
- The character `#` denotes a wall, `.` an open cell, `S` the start and `G` the goal.
- Loading the WolframInstitute/DocPageExamples paclet registers the MAZE import and export converters.

## Import & Export

- `Import["file.maze"]` imports a maze file, returning the level as a matrix of characters.
- `Import["file.maze", elem]` imports the specified element from a maze file.
- `ImportString["data", "MAZE"]` imports a maze level from a string.

---

- `Export["file.maze", expr]` exports a matrix of characters to a maze file.
- `ExportString[expr, "MAZE"]` generates the MAZE text of a level as a string.

## Import Elements

| "Data" | the maze as a matrix of characters (default) |
|---|---|
| "Dimensions" | the size of the maze as {rows, cols} |
| "Graphics" | the maze rendered as graphics using ArrayPlot |

## Options

| "Padding" | "#" |
|---|---|

- With `"Padding" -> "c"`, rows shorter than the longest row are padded with the character c on export; the default pads with walls.

## Examples

### Basic Examples

Load the paclet; the MAZE import and export converters are registered on load:

```wl
Needs["WolframInstitute`DocPageExamples`"]
```

Import a level from a string; the default "Data" element is the character matrix:

```wl
maze = ImportString["#########\n#S..#...#\n#.#.#.#.#\n#...#.#G#\n#########", "MAZE"]
```

The "Dimensions" element gives the grid size as {rows, cols}:

```wl
ImportString["#########\n#S..#...#\n#.#.#.#.#\n#...#.#G#\n#########", {"MAZE", "Dimensions"}]
```

ExportString round-trips the matrix back to MAZE text:

```wl
ExportString[maze, "MAZE"]
```

### Import Elements

The "Graphics" element renders a level as an [ArrayPlot](), with walls black, the start green and the goal red:

```wl
ImportString["###########\n#S..#..#..#\n#.#.#.##..#\n#.#....#.##\n#...##...G#\n###########", {"MAZE", "Graphics"}]
```

### Options

Ragged rows are padded to the longest row on export; the default fills with walls:

```wl
ExportString[{{"S", "."}, {".", ".", ".", "G"}}, "MAZE"]
```

With "Padding" -> ".", short rows are padded with open cells instead:

```wl
ExportString[{{"S", "."}, {".", ".", ".", "G"}}, "MAZE", "Padding" -> "."]
```
