(* ::Package:: *)

(* WolframInstitute`DocPageExamples` - the minimal real library behind the
   MarkdownToNotebook reference-subtype example pages. Loading it registers,
   for real and fully in-kernel:

     - the MAZE plain-text import/export format        (docs Format page)
     - the "Lorem" placeholder-text service connection (docs ServiceConnection page)
     - the RandomSignal simulated device class         (docs Device page)
     - the WallpaperGroup entity store                 (docs Entity page)

   and defines MazeParse (with its ::ragged message, the docs Message page)
   and MazeGenerate (the core of the mazegen command-line script, the docs
   Program page). Everything runs headlessly with no network, so the example
   pages' code cells evaluate for real at documentation build time. *)

BeginPackage["WolframInstitute`DocPageExamples`"]

MazeGenerate::usage = "MazeGenerate[{rows, cols}] generates a random perfect maze as a matrix of characters in the MAZE format (# wall, . open, S start, G goal)."
MazeParse::usage = "MazeParse[lines] parses a list of MAZE-format lines into a character matrix, padding ragged lines with walls."

Begin["`Private`"]

(* === MAZE format (Format page) ===
   A .maze file is equal-length lines of # (wall), . (open), S (start),
   G (goal). Import returns the character matrix; the Dimensions and
   Graphics elements derive from it. Export pads ragged rows with the
   "Padding" option's character. *)

importMaze[source_, ___] := {"Data" -> Characters /@ ReadList[source, String]}

ImportExport`RegisterImport["MAZE", importMaze, {
        (* post-import functions: each receives the raw {"Data" -> matrix}
           rules and returns its element's VALUE *)
        "Dimensions" -> (Dimensions[Lookup[#, "Data"]] &),
        "Graphics" -> (ArrayPlot[Lookup[#, "Data"], Mesh -> True,
            ColorRules -> {"#" -> Black, "." -> White, "S" -> Darker[Green], "G" -> Red}] &)
    },
    "AvailableElements" -> {"Data", "Dimensions", "Graphics"},
    "DefaultElement" -> "Data"
]

exportMaze[file_, data_, opts___] := With[{
    pad = Lookup[Flatten[{opts}], "Padding", "#"],
    width = Max[Length /@ data]
},
    Export[file, StringRiffle[StringJoin /@ (PadRight[#, width, pad] & /@ data), "\n"], "String"]
]

ImportExport`RegisterExport["MAZE", exportMaze, "Options" -> {"Padding"}]

(* === MazeParse (Message page) === *)

MazeParse::ragged = "Line `1` is shorter than the header row; padding with walls."

MazeParse[lines : {__String}] := With[{width = StringLength[First[lines]]},
    If[ ! SameQ @@ StringLength /@ lines,
        Message[MazeParse::ragged, First @ Ordering[StringLength /@ lines, 1]]];
    Characters[StringPadRight[#, width, "#"]] & /@ lines
]

(* === MazeGenerate (Program page - the core of Scripts/mazegen.wls) ===
   Recursive-backtracker perfect maze on an r x c cell grid, rendered on the
   (2r+1) x (2c+1) character grid: cell (i,j) at (2i, 2j), the wall between
   two carved neighbours opened at their index sum. Uses the current random
   state - SeedRandom upstream makes it reproducible. *)

MazeGenerate[{rows_Integer?Positive, cols_Integer?Positive}] := Block[{
    $RecursionLimit = Max[4096, 8 rows cols], visited, passage, carve, grid
},
    visited = ConstantArray[False, {rows, cols}];
    passage = <||>;
    carve[cell : {i_, j_}] := (
        visited[[i, j]] = True;
        Do[
            If[ 1 <= next[[1]] <= rows && 1 <= next[[2]] <= cols && ! visited[[next[[1]], next[[2]]]],
                passage[Sort[{cell, next}]] = True;
                carve[next]
            ],
            {next, RandomSample[cell + # & /@ {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}]}
        ]
    );
    carve[{1, 1}];
    grid = ConstantArray["#", 2 {rows, cols} + 1];
    Do[grid[[2 i, 2 j]] = ".", {i, rows}, {j, cols}];
    Scan[(grid[[#[[1, 1]] + #[[2, 1]], #[[1, 2]] + #[[2, 2]]]] = ".") &, Keys[passage]];
    grid[[2, 2]] = "S";
    grid[[2 rows, 2 cols]] = "G";
    grid
]

(* === RandomSignal device (Device page) ===
   A simulated noise source: DeviceRead returns one uniform sample scaled by
   the writable "Amplitude" property. Registration is idempotent under
   re-loading (a second register of the same class is quieted). *)

Quiet @ DeviceFramework`DeviceClassRegister["RandomSignal",
    "ReadFunction" -> Function[RandomReal[{-1, 1}]],
    "Properties" -> {"Amplitude" -> 1., "SampleRate" -> 100}
]

(* === WallpaperGroup entity store (Entity page) ===
   Six representative plane symmetry groups; registered once. *)

$WallpaperGroupStore = EntityStore["WallpaperGroup" -> <|
    "Entities" -> <|
        "p1"  -> <|"Label" -> "wallpaper group p1",  "PointGroupOrder" -> 1,  "LatticeType" -> "Oblique"|>,
        "p2"  -> <|"Label" -> "wallpaper group p2",  "PointGroupOrder" -> 2,  "LatticeType" -> "Oblique"|>,
        "pm"  -> <|"Label" -> "wallpaper group pm",  "PointGroupOrder" -> 2,  "LatticeType" -> "Rectangular"|>,
        "p4"  -> <|"Label" -> "wallpaper group p4",  "PointGroupOrder" -> 4,  "LatticeType" -> "Square"|>,
        "p4m" -> <|"Label" -> "wallpaper group p4m", "PointGroupOrder" -> 8,  "LatticeType" -> "Square"|>,
        "p6m" -> <|"Label" -> "wallpaper group p6m", "PointGroupOrder" -> 12, "LatticeType" -> "Hexagonal"|>
    |>
|>]

If[ FreeQ[$EntityStores, "WallpaperGroup"],
    PrependTo[$EntityStores, $WallpaperGroupStore]
]

(* === the Lorem service (ServiceConnection page) ===
   A fully local placeholder-text service: no network, no authentication.
   Requests: "Sentence" (Words, Seed), "WordList" (Words, Seed). A Seed makes
   the output reproducible; Automatic uses the current random state. *)

$loremWords = {"lorem", "ipsum", "dolor", "sit", "amet", "consectetur",
    "adipiscing", "elit", "sed", "do", "eiusmod", "tempor", "incididunt",
    "labore", "dolore", "magna", "aliqua"}

loremRandom[body_, seed_] := Replace[seed, {
    Automatic :> body[],
    s_Integer :> BlockRandom[SeedRandom[s]; body[]]
}]

loremWordList[n_Integer, seed_] := loremRandom[Function[RandomChoice[$loremWords, n]], seed]

loremSentence[n_Integer, seed_] := StringRiffle[
    MapAt[Capitalize, loremWordList[n, seed], 1], " "] <> "."

params = <||>
params["ServiceFrameworkVersion"] = "0.1.0"
params["ServiceName"] = "Lorem"
params["Information"] = "Generate placeholder text locally, through the service-connection interface"
params["AuthenticationMethod"] = None
params["ProcessedRequests"] = <||>
params["ProcessedRequests", "Sentence"] = <|
    "ExecuteFunction" -> Function[loremSentence[Lookup[#, "Words", 8], Lookup[#, "Seed", Automatic]]],
    "SubmitFunction" -> None,
    "Parameters" -> {"Words" -> 8, "Seed" -> Automatic}
|>
params["ProcessedRequests", "WordList"] = <|
    "ExecuteFunction" -> Function[loremWordList[Lookup[#, "Words", 12], Lookup[#, "Seed", Automatic]]],
    "SubmitFunction" -> None,
    "Parameters" -> {"Words" -> 12, "Seed" -> Automatic}
|>

End[]

EndPackage[]

ServiceFramework`DefineServiceConnection[WolframInstitute`DocPageExamples`Private`params]
