---
Template: Message
Name: MazeParse::ragged
Paclet: WolframInstitute/DocPageExamples
Context: WolframInstitute`DocPageExamples`
URI: WolframInstitute/DocPageExamples/ref/message/MazeParse/ragged
Description: Message issued when a .maze file has lines of unequal length
Keywords: [maze, ragged, padding, import]
SeeAlso: [Message, Quiet, Off, StringPadRight]
---

# MazeParse::ragged

`MazeParse::ragged` is issued when `MazeParse` reads a `.maze` file in which some
line is shorter than the header row, so the character grid is not rectangular.
This usually indicates trailing characters stripped by an editor or a truncated
file; the maze still imports, but the short rows are completed with wall cells.

- The ragged line is padded on the right with `"#"` (wall) characters up to the width of the header row, so the result is always a full rectangular matrix.
- The message is issued once per import, even when several lines are ragged; the reported line number is that of the shortest line.
- Use [Quiet]() or `Off[MazeParse::ragged]` to suppress the message when ragged files are expected.

## Examples

### Basic Examples

Load the paclet, which provides `MazeParse` and its `ragged` message:

```wl
Needs["WolframInstitute`DocPageExamples`"]
```

A maze whose second line lost two trailing characters triggers the message:

```wl
ragged = MazeParse[{"####", "#S"}];
Grid[ragged, Spacings -> {0.4, 0.1}]
```

The padded result is nevertheless rectangular:

```wl
Dimensions[ragged]
```

<!-- => {2, 4} -->

A rectangular maze parses silently:

```wl
MazeParse[{"#####", "#S.G#", "#####"}] // Grid
```

### Scope

Even when several lines are ragged, the message is issued only once, reporting the
shortest line:

```wl
MazeParse[{"######", "#S", "#..#", "######"}] // Grid
```

Wrap the call in [Quiet]() with the specific message name to suppress it entirely:

```wl
Quiet[MazeParse[{"####", "#SG", "####"}], MazeParse::ragged] // Grid
```
