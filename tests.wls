#!/usr/bin/env wolframscript
(* End-to-end test runner. Loads the forward and inverse converters, then
   runs two test suites without duplicating any assertion logic:

   (1) The regression suite is *extracted from* the "## Tests" section of
       MarkdownToNotebook.md - each fenced wl block in that section is an
       explicit `VerificationTest[code, expected, TestID -> "..."]` expression.
       The exact same cells become the resource's `VerificationTests` slot in
       the produced .nb (the docked Run Tests button evaluates them), so the
       in-notebook tests and this CI script share a single source of truth.

   (2) The round-trip suite is the original sweep over every literate-markdown
       document in the repository: convert with "PreserveSource" -> True so
       the TaggingRules stash carries the source, then assert
       NotebookToMarkdown[nb] === original.

   Exit code is 0 on full pass, 1 on any failure (so CI can rely on it). *)

print[args___] := WriteString["stdout", StringJoin[ToString /@ {args}], "\n"]

dir = DirectoryName[$InputFileName]
Get[FileNameJoin[{dir, "MarkdownToNotebook.wl"}]]
Get[FileNameJoin[{dir, "NotebookToMarkdown.wl"}]]

results = {}
recordResult[name_String, ok_] := (
    AppendTo[results, {name, ok}];
    print[If[ok, "  PASS  ", "  FAIL  "], name]
)

(* === extracted regression suite ===
   litParse + sectionsFrom give us the parsed "## Tests" section directly; each
   wl block's "Code" field is the VerificationTest source. ToExpression
   evaluates it; a TestResultObject reports its own pass / fail. *)

print["regressions (from MarkdownToNotebook.md ## Tests):"]

testBlocks = With[{
    parsed = litParse @ Import[FileNameJoin[{dir, "MarkdownToNotebook.md"}], "Text"]
},
    Cases[Lookup[sectionsFrom[parsed["Blocks"]], "tests", {}], b_ /; codeBlockQ[b]]
]

Scan[
    b |-> Block[{result, name, ok},
        result = Quiet @ ToExpression[b["Code"]];
        name = If[Head[result] === TestObject, result["TestID"], "(no TestID)"];
        ok = Head[result] === TestObject && result["Outcome"] === "Success";
        recordResult[name, ok];
        If[ ! ok && Head[result] === TestObject,
            print["     expected: ", ToString[result["ExpectedOutput"], InputForm],
                  "\n     actual:   ", ToString[result["ActualOutput"], InputForm],
                  "\n     outcome:  ", result["Outcome"]]
        ]
    ],
    testBlocks
]

(* === round-trip pass === *)

print[""]
print["round-trip (md -> nb[PreserveSource -> True] -> md'):"]

sources = Join[
    {FileNameJoin[{dir, "MarkdownToNotebook.md"}],
     FileNameJoin[{dir, "NotebookToMarkdown.md"}]},
    Select[FileNames["*.md", FileNameJoin[{dir, "examples"}]], ! StringEndsQ[#, "-out.md"] &],
    FileNames["*.md", FileNameJoin[{dir, "examples", "AccessibleColors", "docs"}], Infinity]
]

Scan[
    src |-> Block[{original, nb, recovered, ok},
        original = Import[src, "Text"];
        nb = MarkdownToNotebook[src, "PreserveSource" -> True];
        recovered = NotebookToMarkdown[nb];
        ok = recovered === original;
        recordResult["round-trip: " <> FileNameTake[src], ok]
    ],
    sources
]

(* === summary === *)

print[""]
print["==== summary ====", "  ", Count[results, {_, True}], " / ", Length[results], " pass"]

If[ ! AllTrue[results, Last],
    print["FAILURES:"];
    Scan[print["  ", #[[1]]] &, Select[results, ! Last[#] &]];
    Exit[1]
]
