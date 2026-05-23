#!/usr/bin/env wolframscript
(* Generate the GitHub-renderable markdown twins of every examples/*.md document:
   examples/<name>-out.md, with each evaluated example output rasterized to a
   dark-mode PNG under examples/images/. Mirrors the root build-out.wls but loops
   over the example documents, skipping the *-out.md twins it produces. *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

dir = DirectoryName[$InputFileName]
Get[FileNameJoin[{ParentDirectory[dir], "MarkdownToNotebook.wl"}]]

(* render the example outputs in dark mode *)
$lightDark = "Dark"

(* cold run: clear the persistent example cache so screenshots re-evaluate dark *)
Scan[DeleteObject, PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"]]

sources = Select[FileNames["*.md", dir], ! StringEndsQ[#, "-out.md"] &]
print["build-out: ", Length[sources], " example document(s) in ", FileNameTake[dir]]

(* hold one dark front-end session open across the whole pass: the example
   evaluation and the per-output rasterizations both need it. *)
UsingFrontEnd[
    CurrentValue[$FrontEnd, LightDark] = "Dark";
    Scan[
        src |-> Block[{out = FileNameJoin[{dir, FileBaseName[src] <> "-out.md"}]},
            MarkdownToNotebook[src, out];
            print["  wrote ", FileNameTake[out]]
        ],
        sources
    ]
]

print["build-out: done (+ images/)"]
