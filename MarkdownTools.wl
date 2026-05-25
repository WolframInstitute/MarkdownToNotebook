(* MarkdownTools - the tiny shared library used by both MarkdownToNotebook
   (the forward converter, markdown -> notebook) and NotebookToMarkdown (the
   inverse, notebook -> markdown). At the moment it carries one thing - the
   stash protocol that lets a notebook MarkdownToNotebook produced carry the
   original source markdown in its TaggingRules so the inverse can recover it
   verbatim (round-trip without a cell walker). Both converters Get this file
   in so the stash key and read/write helpers stay in agreement; either
   resource can be loaded on its own.

   Deliberately plain top-level definitions (no BeginPackage), the same shape
   as both consumers, so a resource definition notebook can inline this file
   with a "#| file: MarkdownTools.wl" cell and have it work on Get. *)

(* Single source of truth for the TaggingRules key the stash lives under. *)
$markdownSourceKey = "MarkdownToNotebook"

(* Forward direction: stamp a notebook with the original markdown source and
   chosen template name. The forward converter calls this once at the end of
   its build pipeline, so every notebook this code base produces is self-
   contained (the rendered view + the source it came from in one file).
   Merges with existing TaggingRules - the Symbol/Guide path already writes a
   "Metadata" entry, and we add ours alongside without clobbering it. *)
withMarkdownSource[Notebook[cells_, o : OptionsPattern[]], src_String, tmpl_String] := Block[
    {oldRules = Lookup[{o}, TaggingRules, {}], newEntry},
    newEntry = $markdownSourceKey -> <|"Source" -> src, "Template" -> tmpl|>;
    Notebook[cells,
        TaggingRules -> If[ListQ[oldRules],
            Append[DeleteCases[oldRules, $markdownSourceKey -> _], newEntry],
            {newEntry}
        ],
        Sequence @@ FilterRules[{o}, Except[TaggingRules]]
    ]
]
withMarkdownSource[other_, _, _] := other

(* Inverse direction: given a notebook (or its option sequence), return the
   stashed entry as <|"Source" -> ..., "Template" -> ...|>, or a Missing[...]
   that says why the lookup failed. Callers test AssociationQ on the result.
   Implemented through `Replace[key, rules]` (no third argument - that is a
   level spec; a literal default would crash the call when it is an association)
   and then a fallback for the no-match case where Replace returns the key
   itself. *)
markdownSourceOf[Notebook[_, o : OptionsPattern[]]] := markdownSourceOf[{o}]
markdownSourceOf[opts_List] := Block[{tr = Lookup[opts, TaggingRules, {}], hit},
    If[ListQ[tr],
        hit = Replace[$markdownSourceKey, tr];
        If[hit === $markdownSourceKey, Missing["KeyAbsent", $markdownSourceKey], hit],
        Missing["NoTaggingRules"]
    ]
]
markdownSourceOf[_] := Missing["NoSource"]
