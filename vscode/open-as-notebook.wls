#!/usr/bin/env wolframscript
(* ::Package:: *)

(*  open-as-notebook.wls  --  used by the VS Code "Open as Wolfram Notebook" button.

    Converts a Markdown file to a temporary notebook with the deployed
    MarkdownToNotebook resource function (the same one the build scripts use),
    injects a docked "Save to Markdown" cell whose button writes the edited notebook
    back to the same .md via the deployed NotebookToMarkdown, and writes the notebook
    to disk.  The VS Code extension then opens that notebook in the desktop front end.

    Paths arrive through the environment so nothing machine-specific lives here:
        MTN_MD_PATH  the .md file to open (also the save-back target)
        MTN_OUT_NB   where to write the generated .nb
    On success the script prints the .nb path as its last line; on failure it prints a
    line beginning with "ERROR:" and exits non-zero.                                    *)

fail[msg_] := (Print["ERROR: " <> msg]; Exit[1]);

$m2nUrl = "https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook";
$n2mUrl = "https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/NotebookToMarkdown";

mdPath = Environment["MTN_MD_PATH"];
outNb  = Environment["MTN_OUT_NB"];

If[! StringQ[mdPath] || ! StringQ[outNb],
    fail["MTN_MD_PATH and MTN_OUT_NB must be set"]];
If[! FileExistsQ[mdPath], fail["markdown file not found: " <> mdPath]];

(* a left-over Automatic $CloudBase makes the resource fetch URLParse[Automatic]
   and fail intermittently; pin it before touching the deployed function *)
$CloudBase = "https://www.wolframcloud.com";
nb = ResourceFunction[$m2nUrl][mdPath, "Notebook"];
If[! MatchQ[nb, _Notebook], fail["MarkdownToNotebook did not return a Notebook"]];

(* --- the docked "Save to Markdown" toolbar ------------------------------------------
   The button action is held; mdPath and the deployed URL are frozen in as string
   literals with With, so the generated notebook is self-contained and needs no
   arguments at click time.  The resource function is fetched on first click. *)
dockCell = With[{md = mdPath, label = FileNameTake[mdPath], n2mUrl = $n2mUrl},
    Cell[
        BoxData @ ToBoxes @ Row[{
            Button[
                Style["\:2193  Save to Markdown", 12, FontWeight -> "SemiBold"],
                ($CloudBase = "https://www.wolframcloud.com";
                 ResourceFunction[n2mUrl][EvaluationNotebook[], md];
                 CurrentValue[EvaluationNotebook[], {TaggingRules, "MTNsaved"}] = md),
                Method -> "Queued", Appearance -> "DialogBox", ImageMargins -> 4
            ],
            Spacer[14],
            Style[label, GrayLevel[0.45], 11]
        }],
        "DockedCell",
        CellFrame -> {{0, 0}, {0.5, 0}}, CellFrameColor -> GrayLevel[0.8],
        CellFrameMargins -> {{14, 14}, {7, 7}}, Background -> GrayLevel[0.96]
    ]
];

asList[v_] := Which[
    MatchQ[v, {___}],                                          v,
    v === None || v === Inherited || v === Automatic || v === {}, {},
    True,                                                      {v}
];

(* Preferred path: open the notebook in the front end so we can read the
   *effective* docked cells (whatever the stylesheet / inheritance supplies) and
   APPEND ours rather than replace them -- a notebook-level DockedCells option
   overrides the stylesheet, so a headless merge cannot see the toolbar. *)
savedViaFE = Quiet @ Check[
    UsingFrontEnd[
        obj = NotebookPut[nb];
        existing = asList @ AbsoluteCurrentValue[obj, DockedCells];
        SetOptions[obj, DockedCells -> Prepend[existing, dockCell]];
        NotebookSave[obj, outNb];
        NotebookClose[obj];
    ];
    FileExistsQ[outNb],
    False
];

(* Headless fallback: merge only with any DockedCells already on the expression. *)
If[! TrueQ[savedViaFE] || ! FileExistsQ[outNb],
    nbOpts  = Rest[List @@ nb];
    existing = asList @ Replace[Cases[nbOpts, (DockedCells -> v_) :> v], {{v_} :> v, {} -> None}];
    nbOpts2 = Prepend[DeleteCases[nbOpts, _[DockedCells, _]], DockedCells -> Append[existing, dockCell]];
    nb2 = Notebook[First[nb], Sequence @@ nbOpts2];
    res = Quiet @ Export[outNb, nb2, "NB"];
    If[res === $Failed || ! FileExistsQ[outNb],
        stream = OpenWrite[outNb, CharacterEncoding -> "UTF-8"];
        If[stream === $Failed, fail["could not write " <> outNb]];
        WriteString[stream, "(* Content-type: application/vnd.wolfram.notebook *)\n\n"];
        WriteString[stream, ToString[nb2, InputForm]];
        Close[stream];
    ];
];
If[! FileExistsQ[outNb], fail["failed to write notebook: " <> outNb]];

Print[outNb];
