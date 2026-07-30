---
Template: Program
Name: mazegen
Paclet: WolframInstitute/DocPageExamples
Context: WolframInstitute`DocPageExamples`
URI: WolframInstitute/DocPageExamples/ref/program/mazegen
Description: Generate random mazes in the MAZE plain-text format from the command line
Keywords: [maze, maze generation, command line, script, depth-first search]
SeeAlso: [SeedRandom, RandomSample, FindShortestPath, Graph]
RelatedGuides: [DocPageExamples]
Links: ["[Maze generation algorithm (Wikipedia)](https://en.wikipedia.org/wiki/Maze_generation_algorithm)"]
---

# mazegen

`mazegen` is a wolframscript-driven command-line maze generator shipped with the WolframInstitute/DocPageExamples paclet. It carves a perfect maze (every pair of cells joined by exactly one path) and writes it to standard output in the MAZE plain-text format.

## NAME

- `mazegen` -- generate random mazes in the MAZE plain-text format

## SYNOPSIS

- `mazegen -w width -h height` -- generate a width x height maze and write it to standard output
- `mazegen --seed n` -- seed the pseudorandom generator so the same maze is produced on every run

## DESCRIPTION

`mazegen` carves mazes on a rectangular grid of cells with a randomized depth-first backtracker: starting from the top-left cell, it repeatedly tunnels to a random unvisited neighbor and retreats when none remains, until every cell has been visited. The script is a thin command-line wrapper around `MazeGenerate`, which the paclet defines on load; the randomness is driven by [SeedRandom]() and [RandomSample]() in the underlying kernel session.

- The MAZE plain-text format draws walls with `#` and open cells with `.`; a maze of w x h cells occupies 2 h + 1 lines of 2 w + 1 characters each.
- The outer border is always closed; the top-left cell is the start, marked `S`, and the bottom-right cell is the goal, marked `G`.
- Without `--seed`, the generator uses the kernel's current random state and every run produces a different maze; `--seed 0` is equivalent to omitting the flag.
- Flag values are parsed type-safely with [Interpreter](); a value that is not an integer falls back to the default, and unknown flags are ignored.
- Requested dimensions are clipped to the range 2 to 60 cells in each direction.

## OPTIONS

### Generation Options

- `-w n` -- maze width in cells (default 9)
- `-h n` -- maze height in cells (default 5)
- `--seed n` -- seed for the pseudorandom generator (default: the current random state)

## EXAMPLES

### Generate a maze

Generate a reproducible 9 x 5 maze:

```sh
$ mazegen -w 9 -h 5 --seed 42
```

Loading the paclet defines `MazeGenerate`, the in-kernel core of the script:

```wl
Needs["WolframInstitute`DocPageExamples`"]
```

Seed the generator and carve the same maze the script prints; `MazeGenerate[{rows, cols}]` returns the level as a matrix of characters:

```wl
SeedRandom[42];
maze = MazeGenerate[{5, 9}];
Column[Style[StringJoin[#], FontFamily -> "Source Code Pro"] & /@ maze]
```

---

### Solve the maze

The carved passages form a tree, so the route from the start to the goal is unique. Working directly on the returned character matrix, connect every pair of adjacent open cells and let [FindShortestPath]() walk the tree from `S` to `G`:

```wl
SeedRandom[42];
maze = MazeGenerate[{5, 9}];
openQ = MatchQ[Extract[maze, #], "." | "S" | "G"] &;
edges = Flatten @ Table[
    If[openQ[cell + step], UndirectedEdge[cell, cell + step], Nothing],
    {cell, Position[maze, "." | "S" | "G"]}, {step, {{0, 1}, {1, 0}}}];
path = FindShortestPath[Graph[edges], First @ Position[maze, "S"], First @ Position[maze, "G"]];
Length[path]
```

Mark the interior of the solution path with `*` to display it on the level:

```wl
Column[Style[StringJoin[#], FontFamily -> "Source Code Pro"] & /@
    ReplacePart[maze, Thread[Rest[Most[path]] -> "*"]]]
```

## FILES

- `mazegen` is installed under the `Scripts/` directory of the WolframInstitute/DocPageExamples paclet, registered as the paclet asset `"mazegen"`.
- Evaluate `PacletObject["WolframInstitute/DocPageExamples"]["AssetLocation", "mazegen"]` to locate the installed script.
