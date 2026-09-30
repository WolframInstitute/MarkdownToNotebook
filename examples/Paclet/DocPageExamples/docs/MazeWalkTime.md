---
Template: Symbol
Name: MazeWalkTime
Context: WolframInstitute`DocPageExamples`
Paclet: WolframInstitute/DocPageExamples
URI: WolframInstitute/DocPageExamples/ref/MazeWalkTime
Keywords: [maze, walking time, shortest path, quantity, units]
SeeAlso: [Quantity, UnitConvert, GraphDistance, FindShortestPath]
RelatedGuides: [DocPageExamples]
Typeset:
  _Quantity: StandardForm
---

# MazeWalkTime

## Usage

<code>[MazeWalkTime]()[*maze*, *speed*]</code> gives the time to walk the shortest path from the start `S` to the goal `G` of *maze* at the walking *speed*.

## Details & Options

- *maze* is a character matrix in the MAZE format, as `MazeGenerate` and `MazeParse` return it: `#` for a wall, `.` for an open cell, and `S` and `G` for the start and the goal.
- The walk moves between orthogonally adjacent cells that are not walls, one cell per step, so its length is the number of steps from `S` to `G` times the cell size.
- *speed* is a <code>[Quantity]()</code> with units of length per time, in any units of length and time.
- The result is a <code>[Quantity]()</code> in seconds. Exact inputs give an exact time.
- A goal that walls cut off from the start gives `Missing["NotReachable"]`.
- MazeWalkTime takes this option:

| option | default | effect |
|---|---|---|
| <code>"CellSize"</code> | <code>Quantity[1, "Meters"]</code> | the side length of one maze cell |

## Basic Examples

A small maze, drawn in the MAZE format's colors:

```wl
maze = MazeParse[{"#########", "#S..#...#", "###.#.#.#", "#...#.#.#", "#.###.#.#", "#.....#G#", "#########"}];
ArrayPlot[maze, ColorRules -> {"#" -> Black, "." -> White, "S" -> Green, "G" -> Red}, Mesh -> True]
```

The time to walk from `S` to `G` at a brisk walking pace:

```wl
MazeWalkTime[maze, Quantity[1.4, "Meters"/"Seconds"]]
```

<!-- => 15.7143 seconds -->

## Scope

A speed in any units of length per time, here an exact one, which gives an exact time:

```wl
MazeWalkTime[maze, Quantity[5, "Kilometers"/"Hours"]]
```

<!-- => 396/25 seconds -->

---

A maze from `MazeGenerate`:

```wl
SeedRandom[42];
MazeWalkTime[MazeGenerate[{8, 12}], Quantity[1.4, "Meters"/"Seconds"]]
```

<!-- => 48.5714 seconds -->

## Options

### CellSize

Cells half a meter across halve the walk:

```wl
MazeWalkTime[maze, Quantity[1.4, "Meters"/"Seconds"], "CellSize" -> Quantity[50, "Centimeters"]]
```

<!-- => 7.85714 seconds -->

## Applications

Compare walking and running through the same maze:

```wl
MazeWalkTime[maze, #] & /@ {Quantity[1.4, "Meters"/"Seconds"], Quantity[3.5, "Meters"/"Seconds"]}
```

## Properties and Relations

The time is the number of steps $n$ times the cell size $s$ over the speed $v$. Written as a formula, this definition reads as typeset math and runs as ordinary code:

```wl
walkTime[n_, s_, v_] := (*TraditionalForm*)(n s)/v
```

It agrees with MazeWalkTime for the 22-step path through the maze above:

```wl
walkTime[22, Quantity[1, "Meters"], Quantity[1.4, "Meters"/"Seconds"]] == MazeWalkTime[maze, Quantity[1.4, "Meters"/"Seconds"]]
```

<!-- => True -->

---

Doubling the speed halves the time:

```wl
With[{v = Quantity[1.4, "Meters"/"Seconds"]}, MazeWalkTime[maze, 2 v] == MazeWalkTime[maze, v]/2]
```

<!-- => True -->

## Possible Issues

A goal walled off from the start cannot be reached:

```wl
MazeWalkTime[MazeParse[{"#####", "#S#G#", "#####"}], Quantity[1.4, "Meters"/"Seconds"]]
```

<!-- => Missing["NotReachable"] -->

---

A speed needs units of length per time; any other quantity leaves the call unevaluated:

```wl
MazeWalkTime[{{"S", "G"}}, Quantity[3, "Kilograms"]]
```

## Neat Examples

The mean walking time through ten generated mazes of each size:

```wl
SeedRandom[1];
ListLinePlot[
    Table[{n, Mean @ Table[QuantityMagnitude @ MazeWalkTime[MazeGenerate[{n, n}], Quantity[1.4, "Meters"/"Seconds"]], 10]}, {n, 2, 16}],
    AxesLabel -> {"size", "seconds"}, PlotMarkers -> Automatic]
```
