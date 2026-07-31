#!/usr/bin/env wolframscript
(* Build the DocPageExamples paclet documentation: one page of every
   reference subtype (Format / ServiceConnection / Device / Interpreter /
   Entity / Character / Message / Program) plus a Workflow and a
   WorkflowGuide page, each authored in docs/*.md and backed by the REAL
   code the paclet registers on load - so every example cell evaluates
   genuinely at build time.

   Two stages, like the WolframParser example: MarkdownToNotebook writes the
   authoring notebooks into build/DocSource, then DocumentationBuild turns
   them into the paclet's Documentation/ (navigation Index + SearchIndex),
   with the target subdirectory per template taken from the converter's
   $docTemplateDirectories. *)

Quiet @ UsingFrontEnd[CurrentValue[$FrontEnd, LightDark] = "Light"]

rootDir = DirectoryName[$InputFileName]
pacletDir = FileNameJoin[{rootDir, "DocPageExamples"}]

(* the paclet must be live BEFORE conversion: the pages' Needs resolves to
   this directory, and the MAZE / Lorem / RandomSignal / WallpaperGroup
   registrations happen on load *)
PacletDirectoryLoad[pacletDir]

Get[FileNameJoin[{rootDir, "..", "..", "..", "MarkdownToNotebook.wl"}]]
Needs["WolframInstitute`DocPageExamples`"]
Needs["DocumentationBuild`"]

srcDocDir  = FileNameJoin[{rootDir, "build", "DocSource"}]
destDocDir = FileNameJoin[{pacletDir, "Documentation"}]
If[DirectoryQ[srcDocDir], DeleteDirectory[srcDocDir, DeleteContents -> True]]

(* the built page's path: $docTemplateDirectories for the template, and the
   file name from the page URI's trailing segments - a Message page's URI has
   TWO of them (ref/message/Symbol/tag -> Messages/Symbol/tag.nb) *)
outPath[tmpl_String, meta_] := Block[{dir = $docTemplateDirectories[tmpl], segs},
    segs = If[ tmpl === "Message",
        Replace[StringSplit[Lookup[meta, "URI", ""], "/"], {
            {___, "message", sym_, tag_} :> {sym, tag},
            _ :> {StringReplace[Lookup[meta, "Name", "Untitled"], "::" -> "-"]}
        }],
        {Lookup[meta, "Name", "Untitled"]}
    ];
    FileNameJoin[Join[{srcDocDir, "English"}, dir, Most[segs], {Last[segs] <> ".nb"}]]
]

buildDoc[srcFile_String] := Block[{info, tmpl, out},
    info = MarkdownToNotebook[srcFile, "Association", "EvaluateSeparator" -> None];
    tmpl = info["Template"];
    out = outPath[tmpl, info["Metadata"]];
    Quiet @ CreateDirectory[DirectoryName[out], CreateIntermediateDirectories -> True];
    MarkdownToNotebook[srcFile, out, "EvaluateSeparator" -> None];
    Print["  ", FileNameTake[srcFile], " (", tmpl, ") -> ", StringReplace[out, srcDocDir <> "/" -> ""]]
]

Print["building DocPageExamples documentation (authoring notebooks)"]
Scan[buildDoc, Sort @ FileNames["*.md", FileNameJoin[{rootDir, "docs"}]]]

(* The ResourceDefinition is the Paclet Repository submission artifact, not a
   documentation page: it lives beside the paclet (not under docs/) and builds
   into the paclet directory. Its examples are INDEPENDENT of one another, so
   it uses the default delimiter-respecting evaluation - EvaluateSeparator ->
   Automatic resets the example context at each heading and each `---`, unlike
   the doc pages above, whose sections deliberately thread one kernel session. *)
rd = FileNameJoin[{rootDir, "ResourceDefinition.md"}]
If[ FileExistsQ[rd],
    MarkdownToNotebook[rd, FileNameJoin[{pacletDir, "ResourceDefinition.nb"}], "EvaluateSeparator" -> Automatic];
    Print["  ResourceDefinition.md -> ", FileNameTake[pacletDir], "/ResourceDefinition.nb"]
]

Print["running DocumentationBuild: ", srcDocDir, " -> ", destDocDir]
If[DirectoryQ[destDocDir], DeleteDirectory[destDocDir, DeleteContents -> True]]
UsingFrontEnd @ DocumentationBuild`DocumentationBuildNotebooks[srcDocDir, destDocDir, "LinkBase" -> "WolframInstitute/DocPageExamples"]
Print["  built ", Length @ FileNames["*.nb", FileNameJoin[{destDocDir, "English"}], Infinity],
      " documentation notebooks (+ Index / SearchIndex)"]
