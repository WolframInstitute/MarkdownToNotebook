---
Template: FunctionResource
ResourceType: Function
Name: NotebookToMarkdown
Description: Recover a faithful literate-markdown twin of a Wolfram notebook
ContributedBy: Nikolay Murzin, Claude (Anthropic)
Keywords: [markdown, literate programming, inverse, function repository, notebook, round trip]
Categories: [Notebook Documents & Presentation]
SeeAlso: [ResourceFunction, ResourceObject, NotebookGet, MarkdownToNotebook]
Links: ["[MarkdownToNotebook - the forward converter](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/)", "[Source on GitHub](https://github.com/WolframInstitute/MarkdownToNotebook)"]
EntrySymbol: NotebookToMarkdown
---

`NotebookToMarkdown` is the inverse of [MarkdownToNotebook](https://resources.wolframcloud.com/FunctionRepository/resources/MarkdownToNotebook/). Given a notebook expression, a [NotebookObject](), or a `.nb` file path, it walks the cells and emits a literate-markdown twin - frontmatter (when the cells indicate a Symbol-template doc page), the verbatim typed Input code, Usage signatures, Notes / property tables, and the standard `Title` / `Section` / `Text` / `Item` / `Code` cell-style sequence mapped back to markdown blocks.

## Definition

The implementation is a single plain `.wl` file, inlined here at conversion
time via the `#| file:` option; the deployed resource therefore carries it
inline:

```wl
#| file: NotebookToMarkdown.wl
```

## Usage

<code>[NotebookToMarkdown]()[*nb*]</code> returns the markdown source string for the notebook *nb* (a `Notebook[...]` expression, a [NotebookObject](), or a `.nb` file path).

<code>[NotebookToMarkdown]()[*nb*, "*file*.md"]</code> writes the markdown to *file* and returns the file path.

## Details & Options

- The *nb* argument can be a [Notebook]() expression, a [NotebookObject]() open in the front end, or a string `".nb"` file path. The file form `Get`s the notebook off disk; the NotebookObject form `NotebookGet`s the live one.
- `NotebookToMarkdown` always walks the cells - it does not consult any `TaggingRules` stash a forward run might have left behind. Walker quality is therefore the function's responsibility and is exercised on every input.
- Standard styles map back as: `Title` / `Section` / `Subsection` / `Subsubsection` to `#` / `##` / `###` / `####` headings; `Text` / `Caption` / `Quote` / `ExampleText` / `CodeText` to prose; `Item` / `ItemNumbered` to markdown lists; `Code` / `Input` / `ExampleInput` to ```` ```wl ... ``` ```` fenced blocks; `Program` cells (`#| eval: false`, or non-`wl` fenced source) to a no-language fenced block; `Output` / `Message` / `Print` are skipped by default (they regenerate on re-conversion - keep `Output` with `"PreserveOutputs"`).
- The doc-template scaffolding cells - the `Usage` slot, `Notes`, `2ColumnTableMod` / `3ColumnTableMod` property tables, `ExampleSection` / `Subsection` titles, the `PrimaryExamplesSection` opener - all round-trip with their template-implied markdown shape: `## Usage`, `## Details & Options`, a pipe-table per `*TableMod`, `## Basic Examples`, etc.
- **Frontmatter is recovered** when the notebook carries an `ObjectName` cell (the Symbol-template marker): the `Categorization` / `Keywords` / `SeeAlso` / `MoreAbout` cells feed a YAML block at the top of the output, so a shipped reference page round-trips to a rebuildable literate-markdown twin. Notebooks without an `ObjectName` cell (an arbitrary `.nb`) get no frontmatter, just the body.
- **Code cells are verbatim** when a front end is available: the implementation calls the FE's `InputText` export packet so subscripts, `@`, `//`, `[[…]]`, `%`, and 2D-box content survive as their linear-syntax forms. Without a FE the walker falls back to a kernel-only `boxToCode` tree walk - still faithful for plain WL but less so for exotic 2D shapes. Either way the cell text wraps in a fence whose backtick run is one longer than the longest backtick run inside the cell body, so a cell that shows a ` ``` ` fence inside its own source still produces valid markdown.
- **Signature recovery.** An `InlineFormula` cell whose box tree is a call form (`Sym[...]`, an inferred-link `ButtonBox`) renders as <code>[Sym]()[*x*, *y*]</code> - a clickable head with code styling, italic args, subscripts as canonical inline math (`$obj_{i}$`, the form [MarkdownToNotebook]()'s forward parser round-trips to a clean subscript). 2D math without a call shape renders as `$math$` with Greek letters and operators mapped to their TeX commands (`\theta`, `\pi`, `\dagger`, `\cdot`).
- **Empty placeholder sections** (a doc-template `## Properties & Relations` heading with no following content) are dropped from the output when frontmatter is being emitted, matching MarkdownToNotebook's forward-path behaviour. For an arbitrary notebook every heading is kept.
- **Round-trip contract for signatures**: subscripted arguments emit as `$obj_{i}$` (base inside the math). The looser `*obj*$_i$` form (italic base plus a separate `$_i$`) renders fine raw but round-trips broken through MTN, so the walker never emits it.

### Options for round-tripping non-standard cells

The walker's default output is the clean literate-markdown twin above. The following options additionally preserve what markdown can't natively express - a non-standard `CellStyle`, `CellTags`, or an `Output` cell - by emitting MarkdownToNotebook `#|` directives the forward path reads back (see *Cell options* in [docs/formatting.md](https://github.com/WolframInstitute/MarkdownToNotebook/blob/main/docs/formatting.md)).

| Option | Default | Effect |
|---|---|---|
| `"Metadata"` | `Automatic` | `Automatic` emits `#| style:` / `#| tags:` only for cells that are **not** a doc template's own default/scaffolding cells (a built reference page recovers clean, while a hand-authored custom style or tag round-trips); `"Comment"` always emits them, in GitHub-invisible `<!-- #| ... -->` comments; `"Inline"` always emits them as bare `#|` lines; `None` never emits cell metadata. |
| `"PreserveOutputs"` | `False` | `True` keeps each `Output` cell as box data: inlined as `#| boxes: <expr>` when small, or written to a `<base>-out-N.wxf` sidecar beside the `.md` and referenced by `#| file:` when its WXF size exceeds `"OutputInlineLimit"`. Graphics / raster outputs are left out (the markdown twin renders those as images). |
| `"OutputInlineLimit"` | `2048` | WXF byte threshold for inline `#| boxes:` vs. a `.wxf` sidecar. |

A cell is a template default cell - skipped under `Automatic` - when it uses a DocumentationTools scaffolding style (`UsageInputs`, `RelatedSymbol`, ...) or carries a structural template marker tag (`Template*`, `SectionMoreInfo*`, `Compatibility*`, `Name` / `Title` / `Description` / ...).

## Basic Examples

Walk a small notebook and recover the markdown body:

```wl
NotebookToMarkdown @ Notebook[{
    Cell["Demo", "Title"],
    Cell["A paragraph.", "Text"],
    Cell[BoxData["Range[5]^2"], "Input"]
}]
```

<!-- => "# Demo\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n" -->

---

Recover a shipped reference page (a `Symbol` / `Guide` / `TechNote` authoring notebook) as a rebuildable literate-markdown twin:

```wl
#| eval: false
NotebookToMarkdown[
    "/path/to/Documentation/English/ReferencePages/Symbols/MyFn.nb",
    "/path/to/MyFn.md"
]
```

## Scope

A `.nb` file path is read via `Get` and converted the same way as the in-memory `Notebook[…]` form. Round-trip an authored notebook through disk to demonstrate:

```wl
With[{tmp = FileNameJoin[{$TemporaryDirectory, "ntm-scope-demo.nb"}]},
    Put[Notebook[{Cell["Demo", "Title"], Cell["A paragraph.", "Text"], Cell[BoxData["Range[5]^2"], "Input"]}], tmp];
    NotebookToMarkdown[tmp]
]
```

<!-- => "# Demo\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n" -->

## Properties and Relations

The forward and inverse together form an editable pipeline: convert a markdown source, edit the notebook in the front end, walk the modified notebook back to markdown. The walker reflects the *current* state of the cells, so hand edits survive the round trip. Walker output is not byte-identical to the original source - cell `#|` *processing* options (`eval`, `tear`, `screenshot`, ...) are not recovered, fenced-block language tags for non-`wl` fences are lost (the .nb cell only remembers it's `"Program"` styled, not the original language), and the FE may have introduced decorative cells the walker filters out - but feeding the walker's output back through the forward path produces an equivalent notebook. Cell *structure* that markdown can't express - a custom `CellStyle`, `CellTags`, or an `Output` cell - is recovered on demand via the `"Metadata"` / `"PreserveOutputs"` options above.

## Possible Issues

- Frontmatter is recovered only when the notebook has an `ObjectName` cell (the Symbol-template marker). A FunctionResource / Data / TechNote / Demonstration notebook walks to a bare body; add the `Template:` / `Name:` / etc. block back by hand if you need a rebuildable twin.
- The fenced-block language tag is lost for non-`wl` fences (a `text` / `ebnf` / `python` block becomes a Program-styled cell in the .nb, which walks back to a no-language fence). The block round-trips structurally but the syntax-highlighting hint doesn't.
- The faithful Input recovery uses the front end's `InputText` packet. In a session with no FE link available, the walker falls back to a kernel-only `boxToCode` tree walk; the cell still recovers, but subscripts, the `@` / `//` shorthand, and other 2D-input niceties are returned in their box-source rather than the typed form.

## Neat Examples

A round-trip smoke test: forward, walk, forward again, and check the second forward run produces a notebook whose Input cells (by reconstructed source text, normalised) match the first:

```wl
With[{md = "# Demo\n\n## Section\n\nA paragraph.\n\n```wl\nRange[5]^2\n```\n"},
    Module[{nb1, md2, nb2, normWS, sourceTexts},
        nb1 = MarkdownToNotebook[md, "Evaluate" -> False];
        md2 = NotebookToMarkdown[nb1];
        nb2 = MarkdownToNotebook[md2, "Evaluate" -> False];
        normWS[s_String] := StringDelete[StringReplace[s, "\\\n" -> ""], Whitespace];
        sourceTexts[nb_] := normWS @ boxToCode[#] & /@
            Cases[nb, Cell[BoxData[b_], "Input" | "Code" | "ExampleInput" | "Program", ___] :> b, Infinity];
        sourceTexts[nb1] === sourceTexts[nb2]
    ]
]
```

<!-- => True -->

## Tests

Each `wl` cell in this section is an explicit `VerificationTest[code, expected, TestID -> …]` expression that becomes one Input cell in the resource's `VerificationTests` slot (the docked *Run Tests* button evaluates them). The repo's `tests.wls` scrapes this section and runs the same assertions out-of-band, so the in-notebook button and the CI script share a single source of truth.

An `InlineFormula` cell wrapping a `FormBox` is emitted as `$math$`, not as a backticked code span, and in math mode a Wolfram Greek glyph becomes its canonical TeX command (`\[Theta]` -> `\theta`, not a raw Unicode `θ`) so the output is valid TeX rather than a literal codepoint (regression: the previous handler both wrapped every `InlineFormula` content in backticks, giving ``` `$θ$` ``` with extra delimiters, and left the Greek letter as Unicode):

```wl
VerificationTest[
    StringContainsQ[
        NotebookToMarkdown @ Notebook[{
            Cell[TextData[{"angle ", Cell[BoxData[FormBox["\[Theta]", TraditionalForm]], "InlineFormula"]}], "Text"]
        }],
        "$\\theta"
    ],
    True,
    TestID -> "InlineFormula+FormBox -> $math$ (no backticks)"
]
```

The named math constants `\[ExponentialE]`, `\[ImaginaryI]`, `\[ImaginaryJ]`, `\[DifferentialD]`, `\[CapitalDifferentialD]` occupy the same private-use band as the FE structural markers the converter drops, but they are content. They map to plain ASCII (`e`, `i`, `j`, `d`, `D`) before that drop, so a `SuperscriptBox["\[ExponentialE]", …]` keeps its base instead of collapsing to an orphan `$^{…}$` (regression: `e^{i 2 π λ}` rendered as a bare superscript `^{2 π λ}` with the base `e` and exponent `i` silently deleted):

```wl
VerificationTest[
    With[{md = NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"in the form ", Cell[BoxData[
            SuperscriptBox["\[ExponentialE]", RowBox[{"\[ImaginaryI]", " ", "2", "\[Pi]", " ", "\[Lambda]"}]]],
            "InlineFormula"]}], "Text"]
    }]},
        StringContainsQ[md, "$e^{i"] && StringContainsQ[md, "\\pi"] &&
            StringContainsQ[md, "\\lambda"] && ! StringContainsQ[md, "$^{"]
    ],
    True,
    TestID -> "math constants \[ExponentialE]/\[ImaginaryI] survive in a SuperscriptBox"
]
```

In code the same glyphs are meaning-bearing tokens, so `boxToCode` maps each one to its ASCII `\[Name]` long-name escape instead of the prose letter: the escape re-parses to the original constant / `BracketingBar` operator, where the letters change the meaning (`2+3i` is a product with the symbol `i`, not a complex number, and `|x|` is `Alternatives` - in fact a top-level syntax error) (regression: `boxToCode` ran every token through the prose `normStr` alone, so recovered code spans came back as `2+3i` and `|x|`):

```wl
VerificationTest[
    {
        boxToCode["\[ImaginaryI]"],
        boxToCode[RowBox[{"2", "+", "3", "\[ImaginaryI]"}]],
        boxToCode["\[ExponentialE]"],
        boxToCode["\[ImaginaryJ]"],
        boxToCode["\[DifferentialD]"],
        boxToCode["\[CapitalDifferentialD]"],
        boxToCode[RowBox[{"\[LeftBracketingBar]", "x", "\[RightBracketingBar]"}]]
    },
    {"\\[ImaginaryI]", "2+3\\[ImaginaryI]", "\\[ExponentialE]", "\\[ImaginaryJ]",
     "\\[DifferentialD]", "\\[CapitalDifferentialD]",
     "\\[LeftBracketingBar]x\\[RightBracketingBar]"},
    TestID -> "boxToCode: constant glyphs and bracketing bars -> long-name escapes"
]
```

```wl
VerificationTest[
    {
        ToExpression[boxToCode[RowBox[{"2", "+", "3", "\[ImaginaryI]"}]], InputForm, HoldForm],
        ToExpression[boxToCode[RowBox[{"\[LeftBracketingBar]", "x", "\[RightBracketingBar]"}]], InputForm, HoldForm]
    },
    {HoldForm[2 + 3 I], HoldForm[BracketingBar[x]]},
    TestID -> "boxToCode: recovered code re-parses to the original expression"
]
```

The left "spec" column of a doc table is the literal thing you type, so a subscript-free call-form (`"Graph"[g]`) renders as inline code just like a bare-string entry (`"Bell"`) - no mix of code-styled pill and plain text. A code span cannot hold a 2D subscript, though: a subscript-bearing spec (`"Multiplexer"[op_1,op_2,…]`) is rendered as a signature with canonical `$op_{1}$` math instead, which shows a real subscript and round-trips back to the `SubscriptBox` (backticking it would linearize `op_1` to the literal text `Subscript[op, 1]`):

```wl
VerificationTest[
    {
        gridCellMd["\"Bell\""],
        gridCellMd[RowBox[{"\"Graph\"", "[", StyleBox["g", "TI"], "]"}]],
        gridCellMd[RowBox[{"\"Mux\"", "[", SubscriptBox[StyleBox["op", "TI"], "1"], "]"}]]
    },
    {"`\"Bell\"`", "`\"Graph\"[g]`", "\"Mux\"[$op_{1}$]"},
    TestID -> "table spec column: simple specs inline-code, subscript specs canonical $math$"
]
```

A code cell's original surface layout is preserved by walking the `BoxData` tree directly - so a multi-statement Input cell with literal `"\n"` separators round-trips with its line breaks intact (regression: an earlier `MakeExpression`-based deparse choked on multi-statement boxes and fell back to literal `RawBoxes[RowBox[…]]` output):

```wl
VerificationTest[
    StringContainsQ[
        NotebookToMarkdown @ Notebook[{
            Cell[BoxData[RowBox[{RowBox[{"a", " ", "=", " ", "1"}], ";", "\n", RowBox[{"b", " ", "=", " ", "2"}], ";"}]], "Input"]
        }],
        "a = 1;\nb = 2;"
    ],
    True,
    TestID -> "multi-statement Input cell preserves the \"\\n\" between statements"
]
```

Decoration cells the resource template injects are silently dropped - the help-bubble opener that sits inside a heading's `TextData` is a `Cell[BoxData[PaneSelectorBox[…]]]`, never authored content, so the recovered heading is just the title (regression: the opener leaked through as raw box source jammed onto the heading line):

```wl
VerificationTest[
    StringTrim @ NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"Caption", Cell[BoxData[PaneSelectorBox[{True -> "x"}, Dynamic[True]]], "Section"]}], "Section"]
    }],
    "## Caption",
    TestID -> "drops MoreInfoOpener-shaped decoration cells from heading TextData"
]
```

A code signature authored inside a TraditionalForm `FormBox` renders as a `<code>` span, not `$math$` - in math mode its literal `{}`/`[]` would be invisible TeX grouping (braces vanish) and the code would show italic (regression: a `QuantumEvolve[H,{L1,...},...]` signature wrapped in a FormBox lost its list braces and rendered as big italic math):

```wl
VerificationTest[
    With[{md = NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"have ", Cell[BoxData[FormBox[RowBox[{"Foo", "[", RowBox[{"a", ",", "b"}], "]"}], TraditionalForm]]], " only"}], "Text"]
    }]},
        StringContainsQ[md, "<code>"] && ! StringContainsQ[md, "$Foo"]
    ],
    True,
    TestID -> "code signature in FormBox renders as <code>, not $math$"
]
```

An "Annotate" annotation (the palette's *Annotate (and arrows)* button) lives in a cell's `CellFrameLabels` as a `"TextAnnotation"` frame label plus a matching `"TextAnnotation"` CellTag. NotebookToMarkdown lifts the note text into a dedicated `#| annotation:` directive (its date prefix kept verbatim) and suppresses the now-redundant `TextAnnotation` tag, so the editorial note survives the round-trip instead of being dropped:

```wl
VerificationTest[
    With[{md = NotebookToMarkdown @ Notebook[{
        Cell["body", "Text", CellTags -> "TextAnnotation",
            CellFrameLabels -> {{Inherited, Inherited}, {Inherited,
                Cell[TextData[{"26.06.22: review me ", "\n\n",
                    Cell[BoxData[ButtonBox["x", BaseStyle -> "TextAnnotationRemoveButton"]]], "\n"}],
                    "TextAnnotation", CellSize -> {590, Inherited}]}}]
    }]},
        StringContainsQ[md, "#| annotation: 26.06.22: review me"] && ! StringContainsQ[md, "tags: TextAnnotation"]
    ],
    True,
    TestID -> "annotation -> #| annotation: directive (TextAnnotation tag not leaked)"
]
```

In math, letterlike / operator glyphs that have no 2D box structure (`ℏ`, the n-ary `⋁`, the much-greater `≫`) map to their TeX command instead of leaking as raw Unicode, and ASCII relational / arrow operators typed literally into `TraditionalForm` (`<=`, `=!=`, `->`) become `\le` / `\not\equiv` / `\to` with normalized spacing (issue #32):

```wl
VerificationTest[
    {walkerMath["E=" <> FromCharacterCode[16^^210F]], walkerMath["0 <= x"], walkerMath["a =!= b"]},
    {"E=\\hbar ", "0 \\le x", "a \\not\\equiv b"},
    TestID -> "math glyphs/operators -> TeX (hbar, <=, =!=)"
]
```

The centered / vertical / descending ellipses are the same story one step further out: the box -> LaTeX table names `\[Ellipsis]` (`\ldots`) but not its three siblings, so they used to leak into the markdown as raw `⋯` / `⋮` / `⋱` and a `\cdots` never came back as a command. Each now maps to its LaTeX name - the reverse partner of the forward `\cdots` pre-substitution (issue #68):

```wl
VerificationTest[
    {walkerMath[RowBox[{"a", "\[CenterEllipsis]", "b"}]],
     walkerMath[RowBox[{"a", "\[VerticalEllipsis]", "b"}]],
     walkerMath[RowBox[{"a", "\[DescendingEllipsis]", "b"}]]},
    {"a\\cdots b", "a\\vdots b", "a\\ddots b"},
    TestID -> "ellipsis glyphs -> \\cdots / \\vdots / \\ddots (issue #68)"
]
```

A handful of *content* glyphs (the `\[LeftBracketingBar]` / `\[RightBracketingBar]` Abs/Norm bars, `\[LongEqual]`, `\[ImplicitPlus]`, `\[Limit]`) live inside the front-end structural-PUA band but are not box-structure markers, so they survive the drop instead of vanishing from the formula (issue #37):

```wl
VerificationTest[
    walkerMath[SuperscriptBox[RowBox[{"\[LeftBracketingBar]", SubscriptBox["c", "j"], "\[RightBracketingBar]"}], "2"]],
    "|c_{j}|^{2}",
    TestID -> "Abs/Norm bars survive in math (content PUA, issue #37)"
]
```

Structural math boxes that previously dumped their raw box tree or fused with a neighbour now map to TeX: a `GridBox` wrapped in delimiters becomes a `pmatrix` / `bmatrix` / `vmatrix`, the `Norm` / `Abs` templates become `\lVert..\rVert` / `\lvert..\rvert`, and a ket keeps a trailing space so the next token can't fuse into `\rangle` (issue #33):

```wl
VerificationTest[
    {walkerMath[RowBox[{"(", GridBox[{{"a", "b"}, {"c", "d"}}], ")"}]],
     walkerMath[TemplateBox[{"v"}, "Norm"]],
     walkerMath[RowBox[{TemplateBox[{"\[Psi]"}, "Ket"], "dt"}]]},
    {"\\begin{pmatrix}a & b \\\\ c & d\\end{pmatrix}", "\\lVert v\\rVert ", "|\\psi \\rangle dt"},
    TestID -> "structural math: pmatrix, Norm, ket spacing (issue #33)"
]
```

A delimited matrix keeps its environment even when the fence and the grid are **siblings** in a flattened `RowBox` (`H = ( g )`, not a tidy three-element `RowBox`) - the fence/grid/fence run is fused wherever it sits, so `( )` / `[ ]` / `{ }` give `pmatrix` / `bmatrix` / `Bmatrix` instead of demoting to a bare `matrix` with literal parens; and a `vmatrix` / `Vmatrix`, which arrives as an `Abs` / `Norm` `TemplateBox` wrapping the grid, is recovered as that environment rather than a norm-of-matrix (issue #63):

```wl
VerificationTest[
    {walkerMath[RowBox[{"H", "=", "(", GridBox[{{"1", "2"}, {"3", "4"}}], ")"}]],
     walkerMath[RowBox[{"H", "=", "{", GridBox[{{"1", "2"}, {"3", "4"}}], "}"}]],
     walkerMath[TemplateBox[{GridBox[{{"1", "2"}, {"3", "4"}}]}, "Abs"]],
     walkerMath[TemplateBox[{GridBox[{{"1", "2"}, {"3", "4"}}]}, "Norm"]]},
    {"H=\\begin{pmatrix}1 & 2 \\\\ 3 & 4\\end{pmatrix}",
     "H=\\begin{Bmatrix}1 & 2 \\\\ 3 & 4\\end{Bmatrix}",
     "\\begin{vmatrix}1 & 2 \\\\ 3 & 4\\end{vmatrix}",
     "\\begin{Vmatrix}1 & 2 \\\\ 3 & 4\\end{Vmatrix}"},
    TestID -> "delimited matrix with siblings fuses to the right env; Abs/Norm-of-grid -> v/Vmatrix (issue #63)"
]
```

An inline call-form (`Sym[...]`, a `sigCallBoxQ` box) renders as the `<code>[Sym]()[...]</code>` signature DSL only on a documentation page (an `ObjectName` cell, where MTN round-trips it); in a narrative notebook it becomes real inline math with the head upright via `\mathrm` (issue #38):

```wl
VerificationTest[
    {StringContainsQ[NotebookToMarkdown[Notebook[{Cell[TextData[{Cell[BoxData[RowBox[{"Tr", "[", SubscriptBox["A", "i"], "]"}]], "InlineFormula"]}], "Text"]}]], "$\\mathrm{Tr}[A_{i}]$"],
     StringContainsQ[NotebookToMarkdown[Notebook[{Cell["Tr", "ObjectName"], Cell[TextData[{Cell[BoxData[RowBox[{"Tr", "[", SubscriptBox["A", "i"], "]"}]], "InlineFormula"]}], "Text"]}]], "<code>[Tr]()"]},
    {True, True},
    TestID -> "call-form: narrative -> $math$, doc page -> <code> DSL (issue #38)"
]
```

A standalone graphic whose cell IS the graphic (an `Input`/`Code` cell holding only a `GraphicsBox` - a hand-pasted figure) is exported to a `.png` beside the `.md` and emitted as `![]()`, instead of being dropped like regenerable output (issue #34):

```wl
VerificationTest[
    Block[{$n2mAssetDir = $TemporaryDirectory, $n2mAssetBase = "vt-fig", $n2mFigCounter = 0},
        StringMatchQ[blockFor["Input", BoxData[ToBoxes[Graphics[{Disk[]}]]]], "![](" ~~ ___ ~~ ".png)"]],
    True,
    TestID -> "authored figure in Input cell -> image, not dropped (issue #34)"
]
```

An `Iconize` icon in a code cell is an `InterpretationBox` whose display tree is front-end decoration (a `DynamicModuleBox` around an `"IconizedObject"` `TemplateBox`); its real content is the held expression in the interpretation slot. The walker used to unwrap to the display tree and dump `DynamicModuleBox[...]` box noise into the fence; it now emits the stored interpretation's `InputForm` text, and a held `Sequence` of several iconized expressions emits comma-separated (issue #72):

```wl
VerificationTest[
    {boxToCode[RowBox[{"Animate", "[", "x", ",",
        InterpretationBox[
            DynamicModuleBox[{Typeset`open = False},
                TemplateBox[{"Expression", "SequenceIcon", Dynamic[Typeset`open]}, "IconizedObject"]],
            Sequence[SaveDefinitions -> True, AnimationRunning -> False],
            SelectWithContents -> True, Editable -> False], "]"}]],
     StringContainsQ[
        NotebookToMarkdown @ Notebook[{Cell[BoxData[ToBoxes[Iconize[Range[10]]]], "Input"]}],
        "{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}"]},
    {"Animate[x,SaveDefinitions -> True, AnimationRunning -> False]", True},
    TestID -> "Iconize icon -> stored interpretation, Sequence comma-riffled (issue #72)"
]
```

A BookToolsStyles `InlineMath` cell is a `$math$` span by style alone: the book stylesheet sizes inline math itself, so the cell is a bare `Cell[BoxData[boxes], "InlineMath"]` with no `FormBox` or `FontSize` marker. The walker emits it as math unconditionally - no content gate applies, so a bare single TI letter stays `$u$` instead of demoting to a code span (issue #70):

```wl
VerificationTest[
    NotebookToMarkdown @ Notebook[{
        Cell[TextData[{"math ", Cell[BoxData[StyleBox["u", "TI"]], "InlineMath"],
            " and ", Cell[BoxData[RowBox[{StyleBox["c", "TI"], StyleBox["z", "TI"]}]], "InlineMath"],
            " end"}], "Text"]}],
    "math $u$ and $cz$ end\n",
    TestID -> "chapter inline: InlineMath cells walk back to $math$ unconditionally"
]
```

A `Template: Chapter` build's reserved back-matter sections walk back to the exact markdown that builds them: the `Resources` H2 is a `ResourcesSubsection` cell, an `Exercise` is one numbered item, a `MoreExplore` bullet keeps its `- `, and the `ResourcesText` / `TakeawaysText` prose bodies are known styles, so no `#| style:` directive leaks (issues #50, #78):

```wl
VerificationTest[
    Block[{md = NotebookToMarkdown @ MarkdownToNotebook[
        "---\nTemplate: Chapter\nName: Tiny\n---\n\n# Tiny\n\n## Summary\n\nA summary line.\n\n- First point.\n\n## Exercises\n\n1. Do the thing.\n\n## More to Explore\n\n- An entry to explore.\n\n## Resources\n\nA resources line.\n\n## Takeaways\n\nA takeaway line.\n\n## References\n\n- Ref one.\n",
        "Evaluate" -> False]},
        {StringContainsQ[md, "## Summary\n\nA summary line.\n\n- First point."],
         StringContainsQ[md, "## Exercises\n\n1. Do the thing."],
         StringContainsQ[md, "## More to Explore\n\n- An entry to explore."],
         StringContainsQ[md, "## Resources\n\nA resources line."],
         StringContainsQ[md, "## Takeaways\n\nA takeaway line."],
         StringContainsQ[md, "## References\n\n- Ref one."],
         StringContainsQ[md, "#| style:"]}],
    {True, True, True, True, True, True, False},
    TestID -> "chapter back matter: ## Summary / ## References round-trip (issue #50)"
]
```

A `$$...$$` block inside a `::: solved-example` / `::: proof` div builds as a `SolvedExampleDisplayFormula(Numbered)` / `ProofTheoremDisplayFormula` cell, the same centering-PaneBox shape as `DisplayFormula`; each unwraps back to a plain `$$...$$` block instead of dumping raw boxes into a `$...$` span (issue #78):

```wl
VerificationTest[
    {blockFor["SolvedExampleDisplayFormula",
        BoxData[PaneBox[RowBox[{SuperscriptBox[StyleBox["x", "TI"], "2"], "=", "4"}],
            ImageSize -> Full, Alignment -> Center]]],
     blockFor["ProofTheoremDisplayFormula",
        BoxData[PaneBox[RowBox[{SuperscriptBox[StyleBox["x", "TI"], "2"], "=", "4"}],
            ImageSize -> Full, Alignment -> Center]]],
     blockFor["SolvedExampleDisplayFormulaNumbered", BoxData[SqrtBox["2"]]]},
    {"$$x^{2}=4$$", "$$x^{2}=4$$", "$$\\sqrt{2}$$"},
    TestID -> "book-genre display cells -> $$...$$ (Solved/ProofTheorem, no box dump)"
]
```

A `NotesSubsection` cell (the ref-page style that groups notes inside the Details section) walks back to a `###` heading, behind the same `## Details & Options` header injection the first `Notes` cell gets (issue #77):

```wl
VerificationTest[
    StringContainsQ[
        NotebookToMarkdown[Notebook[{Cell["TinyFn", "ObjectName"],
            Cell["A note.", "Notes"],
            Cell["Grouped notes", "NotesSubsection"],
            Cell["Another note.", "Notes"]}]],
        "## Details & Options\n\n- A note.\n\n### Grouped notes\n\n- Another note."],
    True,
    TestID -> "NotesSubsection walks back to a ### heading inside Details & Options (issue #77)"
]
```
