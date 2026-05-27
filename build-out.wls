#!/usr/bin/env wolframscript
(* Generate the GitHub-renderable markdown twins for the resource documents in
   this directory - MarkdownToNotebook-out.md and NotebookToMarkdown-out.md -
   with every evaluated example output rasterized to a dark-mode PNG under
   images/. This is the ".md" target of the forward converter itself
   (MarkdownToNotebook[source, "out.md"]); the dark renderings are pinned with
   the $lightDark global so the twin reads well against GitHub's dark theme. *)

dir = DirectoryName[$InputFileName];
SetDirectory[dir];
Get[FileNameJoin[{dir, "MarkdownToNotebook.wl"}]];
Get[FileNameJoin[{dir, "NotebookToMarkdown.wl"}]];

(* render the example outputs in dark mode *)
$lightDark = "Dark";

(* cold run: clear the persistent example cache so screenshots re-evaluate dark *)
Scan[DeleteObject, PersistentObjects["MarkdownToNotebook/ExampleOutput/*", "Local"]];

sources = {"MarkdownToNotebook.md", "NotebookToMarkdown.md"};

(* hold one front-end session (set to dark) open across the whole pass: the
   example evaluation and the per-output rasterizations both need it, and a
   headless session resolves the Automatic appearance to dark anyway. *)
UsingFrontEnd[
    CurrentValue[$FrontEnd, LightDark] = "Dark";
    Scan[
        name |-> Block[{src = FileNameJoin[{dir, name}], out = FileNameJoin[{dir, FileBaseName[name] <> "-out.md"}]},
            Print["build-out: generating ", FileNameTake[out]];
            MarkdownToNotebook[src, out];
            Print["build-out: wrote ", FileNameTake[out], " (+ images/)"]
        ],
        sources
    ]
]
