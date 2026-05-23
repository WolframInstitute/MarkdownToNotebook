#!/usr/bin/env wolframscript
(* Build the Example Repository definition notebooks from every examples/*.md
   document. Loads the converter from the parent directory and runs it on each
   top-level example markdown, writing a sibling .nb. The one-level glob skips the
   AccessibleColors submodule (its own .md files are nested) and the generated
   *-out.md twins. *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

(* match the deployed-notebook appearance: pin the front end to light so the
   example-notebook thumbnails rendered during conversion are not darkened. *)
Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"]

dir = DirectoryName[$InputFileName]
Get[FileNameJoin[{ParentDirectory[dir], "MarkdownToNotebook.wl"}]]

(* cold run: clear the persistent example cache so the examples re-evaluate *)
Scan[DeleteObject, PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"]]

sources = Select[FileNames["*.md", dir], ! StringEndsQ[#, "-out.md"] &]
print["build: ", Length[sources], " example document(s) in ", FileNameTake[dir]]

Scan[
    src |-> Block[{result, nb, outNb},
        result = MarkdownToNotebook[src, "Association"];
        nb = result["Notebook"];
        outNb = MarkdownToNotebook[src, FileNameJoin[{dir, FileBaseName[src] <> ".nb"}]];
        print["  ", FileNameTake[src]];
        print["    Template:       ", result["Template"]];
        print["    Name:           ", result["Metadata"]["Name"]];
        print["    Output cells:   ", Count[nb, Cell[_, "Output", ___], Infinity], " (evaluated examples)"];
        print["    Unfilled slots: ", Count[nb, _TemplateSlot, Infinity]];
        print["    wrote:          ", FileNameTake[outNb], " (", Head @ Quiet @ Get[outNb], ")"]
    ],
    sources
]

print["build: done"]
