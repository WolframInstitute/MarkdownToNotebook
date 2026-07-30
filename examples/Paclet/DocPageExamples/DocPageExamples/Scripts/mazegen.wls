#!/usr/bin/env wolframscript
(* mazegen - generate a random maze in the MAZE plain-text format.

       mazegen [-w width] [-h height] [--seed n]

   The core is WolframInstitute`DocPageExamples`MazeGenerate; this script only
   parses the command line and prints the grid. Documented by the paclet's
   Program page (docs ref/program/mazegen). *)

PacletDirectoryLoad[DirectoryName[$InputFileName, 2]]
Needs["WolframInstitute`DocPageExamples`"]

(* named integer arguments, parsed type-safely; unknown flags are ignored *)
argValue[flag_String, default_Integer] := Replace[
    FirstPosition[$ScriptCommandLine, flag, None],
    {
        {i_Integer} /; i < Length[$ScriptCommandLine] :> Replace[
            Interpreter["Integer"][$ScriptCommandLine[[i + 1]]],
            Except[_Integer] :> default],
        _ -> default
    }
]

width  = Clip[argValue["-w", 9], {2, 60}]
height = Clip[argValue["-h", 5], {2, 60}]
seed   = argValue["--seed", 0]

If[seed =!= 0, SeedRandom[seed]]

Scan[Print, StringJoin /@ MazeGenerate[{height, width}]]
