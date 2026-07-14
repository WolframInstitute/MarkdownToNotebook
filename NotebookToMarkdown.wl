(* NotebookToMarkdown - the inverse of MarkdownToNotebook. Given a notebook
   (expression / NotebookObject / .nb file path), recover a literate-markdown
   twin: frontmatter (when the cells indicate a resource template), the verbatim
   typed Input code, Usage signatures, Notes / property tables, and the standard
   cell-style sequence walked back to markdown blocks.

   Walker-only by design: any TaggingRules stash a forward run might have left
   behind is ignored, so this code is exercised on every input and round-trip
   quality is the walker's responsibility, not a memoized shortcut.

   A faithful round trip uses the front end's InputText export to recover code
   cells verbatim (preserving subscripts, `@`, `//`, `[[…]]`, `%`). The public
   entry points wrap the work in UsingFrontEnd; if the call fails (no FE
   reachable, e.g. a minimal Notebook[] expression handed in directly), the
   walker falls back to a pure-kernel boxToCode tree walk so it still produces
   output, just less faithfully for exotic 2D code shapes.

   Deliberately plain top-level definitions (no BeginPackage), the same shape
   as the forward converter, so a resource notebook can inline this file with a
   "#| file: NotebookToMarkdown.wl" cell and have it work on Get. *)

(* === decoration filters ===
   The resource templates (Demonstration, Symbol, ...) insert decorative cells
   inline with the heading TextData - the help-bubble opener that pops the
   "MoreInfo" guidance for each slot. The opener is a Cell wrapping a
   PaneSelectorBox of the "MoreInfoOpenerButtonTemplate"; the body it pops is
   a sibling Cell of style "MoreInfoText". Neither belongs in the recovered
   markdown - the source never mentioned them, the front end injected them.
   Return "" from inlineMd for any such cell so it falls out of the
   StringJoin. The broader match catches *any* PaneSelectorBox-in-a-Cell-in-
   TextData because such a thing is, by construction, a UI affordance the
   template injected (the source markdown has no way to express it). *)
decorationCellQ[Cell[BoxData[_PaneSelectorBox], ___]] := True
decorationCellQ[Cell[_, "MoreInfoText" | "MoreInfoTextOuter", ___]] := True
decorationCellQ[_] := False

(* === character normalization ===
   Wolfram FORMAL symbols (\[FormalA]..\[FormalZ] = 0xF800-0xF819, capitals
   0xF81A-0xF833) render fine in Mathematica but are INVISIBLE private-use
   glyphs in a web/markdown view, so a formal placeholder shows as nothing (the
   empty "**"). Map them to plain letters. Wolfram letter glyphs (script /
   gothic / double-struck) and named math constants (ExponentialE,
   ImaginaryI, ImaginaryJ, DifferentialD, CapitalDifferentialD) share the
   same PUA band as the FE structural box markers (the box-escape lead-ins,
   0xE000-0xF7FF) - the markers themselves are pure noise -> drop, but the
   letters / constants are content -> map to ASCII so they survive the drop. *)
(* Wolfram stores script / gothic / double-struck letters in a PUA band; keep
   their *style* (issue #31) by mapping to the real Unicode mathematical-
   alphanumeric glyph (for prose / headings) and to \mathcal / \mathfrak /
   \mathbb in math.  Each row is {PUAstart, count, ASCIIstart, UnicodeBase,
   <|holeIndex -> codepoint|>, texCommand}; the Mathematical Alphanumeric blocks
   are contiguous except for letters unified into the Letterlike Symbols block,
   listed as holes. *)
$mathAlpha = {
    {63396, 26, 65, 16^^1D538, <|2 -> 16^^2102, 7 -> 16^^210D, 13 -> 16^^2115, 15 -> 16^^2119, 16 -> 16^^211A, 17 -> 16^^211D, 25 -> 16^^2124|>, "mathbb"},
    {63206, 26, 97, 16^^1D552, <||>, "mathbb"},
    {63451, 10, 48, 16^^1D7D8, <||>, "mathbb"},
    {63344, 26, 65, 16^^1D49C, <|1 -> 16^^212C, 4 -> 16^^2130, 5 -> 16^^2131, 7 -> 16^^210B, 8 -> 16^^2110, 11 -> 16^^2112, 12 -> 16^^2133, 17 -> 16^^211B|>, "mathcal"},
    {63154, 26, 97, 16^^1D4B6, <|4 -> 16^^212F, 6 -> 16^^210A, 14 -> 16^^2134|>, "mathcal"},
    {63370, 26, 65, 16^^1D504, <|2 -> 16^^212D, 7 -> 16^^210C, 8 -> 16^^2111, 17 -> 16^^211C, 25 -> 16^^2128|>, "mathfrak"},
    {63180, 26, 97, 16^^1D51E, <||>, "mathfrak"}
};
(* PUA codepoint -> canonical Unicode glyph (prose, normCharCode) *)
$puaAlphaGlyph = Association @ Flatten @ Table[
    With[{r = $mathAlpha[[k]]},
        Table[(r[[1]] + i) -> FromCharacterCode[Lookup[r[[5]], i, r[[4]] + i]], {i, 0, r[[2]] - 1}]],
    {k, Length[$mathAlpha]}];
(* canonical Unicode glyph (what normStr produces) -> TeX command (math, $mathTeX) *)
$mathAlphaTeX = Association @ Flatten @ Table[
    With[{r = $mathAlpha[[k]]},
        Table[FromCharacterCode[Lookup[r[[5]], i, r[[4]] + i]] -> "\\" <> r[[6]] <> "{" <> FromCharacterCode[r[[3]] + i] <> "}", {i, 0, r[[2]] - 1}]],
    {k, Length[$mathAlpha]}];

normCharCode[n_Integer] := Which[
    63488 <= n <= 63513, FromCharacterCode[n - 63488 + 97],   (* formal a..z *)
    63514 <= n <= 63539, FromCharacterCode[n - 63514 + 65],   (* formal A..Z *)
    KeyExistsQ[$puaAlphaGlyph, n], $puaAlphaGlyph[n],         (* script/gothic/double-struck -> Unicode glyph *)
    (* \[CapitalDifferentialD] \[DifferentialD] \[ExponentialE] \[ImaginaryI] \[ImaginaryJ] *)
    63307 <= n <= 63311, FromCharacterCode @ {68, 100, 101, 105, 106}[[n - 63306]],
    (* content glyphs that live inside the FE structural band but are NOT markers
       (issue #37): keep them instead of dropping them with the box noise *)
    n === 16^^F603 || n === 16^^F604, "|",   (* Left/RightBracketingBar (Abs/Norm) *)
    n === 16^^F7D9, "=",                       (* LongEqual *)
    n === 16^^F39E, "+",                       (* ImplicitPlus *)
    n === 16^^F438, "lim",                     (* Limit *)
    57344 <= n <= 63487, "",                                   (* FE structural box markers -> drop *)
    True, FromCharacterCode[n]
]
normStr[s_String] := StringJoin[normCharCode /@ ToCharacterCode[s]]
stripStructPUA[s_String] := StringJoin @ DeleteCases[Characters[s],
    c_ /; With[{n = First @ ToCharacterCode[c]}, 57344 <= n <= 63487]]

(* === math-mode Greek -> TeX commands ===
   In math mode a raw Unicode Greek glyph or math operator is non-canonical TeX
   (KaTeX renders an italic glyph at best, fails entirely for an operator). Map
   on the math leaf (walkerMath / sigSub / mathDq), never in normStr, so the
   same glyph in prose is left as the readable Unicode character. *)
$mathTeX = Join[<|
    "\[Alpha]" -> "\\alpha ", "\[Beta]" -> "\\beta ", "\[Gamma]" -> "\\gamma ",
    "\[Delta]" -> "\\delta ", "\[Epsilon]" -> "\\epsilon ", "\[CurlyEpsilon]" -> "\\varepsilon ",
    "\[Zeta]" -> "\\zeta ", "\[Eta]" -> "\\eta ", "\[Theta]" -> "\\theta ",
    "\[CurlyTheta]" -> "\\vartheta ", "\[Iota]" -> "\\iota ", "\[Kappa]" -> "\\kappa ",
    "\[Lambda]" -> "\\lambda ", "\[Mu]" -> "\\mu ", "\[Nu]" -> "\\nu ", "\[Xi]" -> "\\xi ",
    "\[Pi]" -> "\\pi ", "\[Rho]" -> "\\rho ", "\[Sigma]" -> "\\sigma ", "\[FinalSigma]" -> "\\varsigma ",
    "\[Tau]" -> "\\tau ", "\[Upsilon]" -> "\\upsilon ", "\[Phi]" -> "\\phi ",
    "\[CurlyPhi]" -> "\\varphi ", "\[Chi]" -> "\\chi ", "\[Psi]" -> "\\psi ", "\[Omega]" -> "\\omega ",
    "\[CapitalGamma]" -> "\\Gamma ", "\[CapitalDelta]" -> "\\Delta ", "\[CapitalTheta]" -> "\\Theta ",
    "\[CapitalLambda]" -> "\\Lambda ", "\[CapitalXi]" -> "\\Xi ", "\[CapitalPi]" -> "\\Pi ",
    "\[CapitalSigma]" -> "\\Sigma ", "\[CapitalUpsilon]" -> "\\Upsilon ", "\[CapitalPhi]" -> "\\Phi ",
    "\[CapitalPsi]" -> "\\Psi ", "\[CapitalOmega]" -> "\\Omega ",
    "\[Dagger]" -> "\\dagger ", "\[CircleTimes]" -> "\\otimes ", "\[Ellipsis]" -> "\\ldots ",
    "\[Sum]" -> "\\sum ", "\[Product]" -> "\\prod ", "\[Integral]" -> "\\int ",
    "\[PartialD]" -> "\\partial ", "\[Del]" -> "\\nabla ", "\[Infinity]" -> "\\infty ",
    "\[Times]" -> "\\times ", "\[CenterDot]" -> "\\cdot ", "\[Divide]" -> "\\div ",
    (* operators that previously leaked as raw Unicode (issue #31); script /
       gothic / double-struck letters are handled by $mathAlphaTeX, merged below *)
    "\[CirclePlus]" -> "\\oplus ", "\[CircleMinus]" -> "\\ominus ", "\[CircleDot]" -> "\\odot ",
    "\[TildeTilde]" -> "\\approx ", "\[TildeEqual]" -> "\\simeq ", "\[Tilde]" -> "\\sim ",
    "\[Congruent]" -> "\\equiv ", "\[Proportional]" -> "\\propto ",
    "\[LeftAngleBracket]" -> "\\langle ", "\[RightAngleBracket]" -> "\\rangle ",
    "\[LessEqual]" -> "\\le ", "\[GreaterEqual]" -> "\\ge ", "\[NotEqual]" -> "\\ne ",
    "\[PlusMinus]" -> "\\pm ", "\[MinusPlus]" -> "\\mp ",
    "\[Element]" -> "\\in ", "\[NotElement]" -> "\\notin ",
    "\[Subset]" -> "\\subset ", "\[SubsetEqual]" -> "\\subseteq ",
    "\[Superset]" -> "\\supset ", "\[SupersetEqual]" -> "\\supseteq ",
    "\[Union]" -> "\\cup ", "\[Intersection]" -> "\\cap ", "\[EmptySet]" -> "\\emptyset ",
    "\[ForAll]" -> "\\forall ", "\[Exists]" -> "\\exists ",
    "\[And]" -> "\\wedge ", "\[Or]" -> "\\vee ", "\[Not]" -> "\\neg ",
    "\[LeftArrow]" -> "\\leftarrow ", "\[LeftRightArrow]" -> "\\leftrightarrow ",
    "\[Implies]" -> "\\implies ", "\[RightTeeArrow]" -> "\\mapsto ",
    "\[Angle]" -> "\\angle ", "\[Degree]" -> "^\\circ "
|>, $mathAlphaTeX, <|
    (* letterlike / operator glyphs that otherwise leak as raw Unicode (issue #32),
       keyed by codepoint so the source stays ASCII *)
    FromCharacterCode[16^^210F] -> "\\hbar ",
    FromCharacterCode[16^^226B] -> "\\gg ", FromCharacterCode[16^^226A] -> "\\ll ",
    FromCharacterCode[16^^2218] -> "\\circ ", FromCharacterCode[16^^25E6] -> "\\circ ",
    FromCharacterCode[16^^22C1] -> "\\bigvee ", FromCharacterCode[16^^22C0] -> "\\bigwedge ",
    (* the straight bars a tall Abs / Norm modulus is drawn with (issue #48); math
       leaf only, so a divides / parallel bar in prose is left as the Unicode glyph *)
    FromCharacterCode[16^^2502] -> "|", FromCharacterCode[16^^2225] -> "\\|",
    FromCharacterCode[16^^200B] -> ""    (* zero-width space -> drop *)
|>];

(* ASCII relational / arrow operators typed literally into TraditionalForm math
   (issue #32) - map to TeX, longest-first so "=!="/"===" beat "==" and "<->"
   beats "<="/"->". Applied before the single-glyph $mathTeX pass. *)
$mathAsciiOps = {
    WhitespaceCharacter ... ~~ "=!=" ~~ WhitespaceCharacter ... -> " \\not\\equiv ",
    WhitespaceCharacter ... ~~ "===" ~~ WhitespaceCharacter ... -> " \\equiv ",
    WhitespaceCharacter ... ~~ "<->" ~~ WhitespaceCharacter ... -> " \\leftrightarrow ",
    WhitespaceCharacter ... ~~ "<=" ~~ WhitespaceCharacter ... -> " \\le ",
    WhitespaceCharacter ... ~~ ">=" ~~ WhitespaceCharacter ... -> " \\ge ",
    WhitespaceCharacter ... ~~ "!=" ~~ WhitespaceCharacter ... -> " \\ne ",
    WhitespaceCharacter ... ~~ "->" ~~ WhitespaceCharacter ... -> " \\to ",
    WhitespaceCharacter ... ~~ "==" ~~ WhitespaceCharacter ... -> " = "};

(* === math-mode serializer ===
   walkerMath produces the body of a "$...$" span (or, for FormBox /
   TraditionalForm, a free-standing math expression). No outer "$" wrapper;
   that lives in the inlineMd dispatchers. *)
walkerMath["mod"] := "\\bmod "
walkerMath["div"] := "\\div "
walkerMath["gcd"] := "\\gcd "
walkerMath["lcm"] := "\\operatorname{lcm} "
(* Set-brace tokens: bare "{"/"}" in TeX is invisible grouping, so a real
   set brace has to be escaped (issue #9). These only catch brace tokens
   from the box tree - the "_{"/"}" grouping that subscript/superscript
   rules splice in are rule-body literals, never strings reaching this
   leaf. *)
walkerMath["{"] := "\\{"
walkerMath["}"] := "\\}"
(* Arrow operators live in PUA (\[Rule] = U+F522) and normStr would drop
   them as FE structural markers - catch as specific-token matches before
   the generic leaf (issue #9). *)
walkerMath["\[Rule]"] := "\\to "
walkerMath["\[RightArrow]"] := "\\to "
walkerMath[s_String /; s =!= "" && StringMatchQ[s, Whitespace]] := "\\, "
walkerMath[s_String] := StringReplace[StringReplace[normStr[s], $mathAsciiOps], Normal @ $mathTeX]
(* a multi-letter italic identifier in math (StyleBox[s, "TI"]) needs
   \mathit{} or TeX would render it as a product of single letters
   (output -> o u t p u t, issue #14). Single letters / Greek fall
   through to the generic rule below. *)
walkerMath[StyleBox[s_String, "TI", ___]] /; StringMatchQ[s, RegularExpression["[a-zA-Z]{2,}"]] :=
    "\\mathit{" <> s <> "}"
walkerMath[StyleBox[s_, ___]] := walkerMath[s]
(* every fixed-arity box rule carries a "___" option tail: the forward pipeline
   emits option-bearing script boxes inline (e.g. UnderscriptBox[sum, m,
   LimitsPositioning -> False]) and without the tail they skip every rule and dump
   the raw box tree into the $...$ span (issue #51). *)
(* \frac keeps the grouping unambiguous - "\tfrac{R}{n} g" as "R/ng" reads as a
   single denominator - and parses straight back through LaTeXMathParse *)
walkerMath[FractionBox[a_, b_, ___]] := "\\frac{" <> walkerMath[a] <> "}{" <> walkerMath[b] <> "}"
(* a script base with any trailing spacing glue (the "\," walkerMath emits for a
   whitespace leaf) stripped, so a script never lands on a glue node - KaTeX errors
   "Got group of unknown type: 'internal'" on "U\, ^{\dagger}" (issue #33). An
   empty base becomes "{}" so the script still has a valid base. *)
scriptBase[box_] := Replace[
    StringReplace[walkerMath[box], ("\\," | " ") .. ~~ EndOfString -> ""], "" -> "{}"]
walkerMath[SubscriptBox[a_, b_, ___]] := scriptBase[a] <> "_{" <> walkerMath[b] <> "}"
walkerMath[SuperscriptBox[a_, b_, ___]] := scriptBase[a] <> "^{" <> walkerMath[b] <> "}"
walkerMath[SubsuperscriptBox[a_, b_, c_, ___]] := scriptBase[a] <> "_{" <> walkerMath[b] <> "}^{" <> walkerMath[c] <> "}"
walkerMath[SqrtBox[a_, ___]] := "\\sqrt{" <> walkerMath[a] <> "}"
walkerMath[RadicalBox[a_, b_, ___]] := "\\sqrt[" <> walkerMath[b] <> "]{" <> walkerMath[a] <> "}"
walkerMath[UnderscriptBox[a_, b_, ___]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}"
walkerMath[OverscriptBox[a_, "^", ___]] := "\\hat{" <> walkerMath[a] <> "}"
walkerMath[OverscriptBox[a_, "_", ___]] := "\\overline{" <> walkerMath[a] <> "}"
(* vector / harpoon accent -> \vec (issue #33: a raw harpoon as \overset arg is
   untypesettable) *)
walkerMath[OverscriptBox[a_, "\[RightVector]" | "\[RightArrow]", ___]] := "\\vec{" <> walkerMath[a] <> "}"
walkerMath[OverscriptBox[a_, b_, ___]] := "\\overset{" <> walkerMath[b] <> "}{" <> walkerMath[a] <> "}"
walkerMath[UnderoverscriptBox[a_, b_, c_, ___]] := walkerMath[a] <> "_{" <> walkerMath[b] <> "}^{" <> walkerMath[c] <> "}"
walkerMath[ButtonBox[n_, ___]] := walkerMath[n]
(* GridBox -> a TeX matrix environment (issue #33: a bare grid hit the catch-all
   and dumped its box tree). The author's own delimiters sit OUTSIDE the grid as
   sibling RowBox tokens, so a wrapping ( ) / [ ] / | | promotes matrix ->
   pmatrix / bmatrix / vmatrix; a leading \[Piecewise] column -> cases. (These
   specific patterns auto-sort ahead of the generic GridBox / RowBox rules.) *)
gridRows[GridBox[rows_List, ___]] := StringRiffle[
    Function[row, StringRiffle[walkerMath /@ row, " & "]] /@ rows, " \\\\ "]
walkerMath[GridBox[{{"\[Piecewise]", inner_GridBox}}, ___]] :=
    "\\begin{cases}" <> gridRows[inner] <> "\\end{cases}"
walkerMath[RowBox[{"(", g_GridBox, ")"}]] := "\\begin{pmatrix}" <> gridRows[g] <> "\\end{pmatrix}"
walkerMath[RowBox[{"[", g_GridBox, "]"}]] := "\\begin{bmatrix}" <> gridRows[g] <> "\\end{bmatrix}"
walkerMath[RowBox[{"|", g_GridBox, "|"}]] := "\\begin{vmatrix}" <> gridRows[g] <> "\\end{vmatrix}"
walkerMath[g_GridBox] := "\\begin{matrix}" <> gridRows[g] <> "\\end{matrix}"
walkerMath[RowBox[xs_List]] := StringJoin[walkerMath /@ xs]
walkerMath[FormBox[box_, ___]] := walkerMath[box]
walkerMath[TagBox[x_, ___]] := walkerMath[x]
walkerMath[InterpretationBox[x_, ___]] := walkerMath[x]
walkerMath[Cell[BoxData[b_], ___]] := walkerMath[b]
walkerMath[Cell[c_, ___]] := walkerMath[c]
(* close-delimiters keep a trailing space so the next RowBox token can't fuse into
   the control word (issue #33: "\rangledt", "\dagger2") *)
walkerMath[tb : TemplateBox[{_, _String, ___}, "PackageLink" | "RefLink" | "RefLinkPlain", ___]] :=
    FirstCase[First[tb], s_String :> s, "", Infinity]
walkerMath[TemplateBox[{x_}, "Ket"]] := "|" <> walkerMath[x] <> "\\rangle "
walkerMath[TemplateBox[{x_}, "Bra"]] := "\\langle " <> walkerMath[x] <> "|"
walkerMath[TemplateBox[{x_, y_}, "Braket" | "BraKet"]] := "\\langle " <> walkerMath[x] <> "|" <> walkerMath[y] <> "\\rangle "
walkerMath[TemplateBox[{x_}, "SuperDagger" | "Dagger"]] := walkerMath[x] <> "^\\dagger "
walkerMath[TemplateBox[{x_}, "Conjugate"]] := walkerMath[x] <> "^*"
(* Norm / Abs templates -> \lVert..\rVert / \lvert..\rvert (issue #33: no rule, so
   the template was dumped by the catch-all) *)
walkerMath[TemplateBox[{x_}, "Norm"]] := "\\lVert " <> walkerMath[x] <> "\\rVert "
walkerMath[TemplateBox[{x_}, "Abs"]] := "\\lvert " <> walkerMath[x] <> "\\rvert "
walkerMath[other_] := ToString[other, InputForm]

(* === code-mode serializer ===
   Box-form WL code -> source string. A code cell's BoxData carries the user's
   surface form as a tree of RowBoxes whose leaves are tokens (operators,
   identifiers, literal whitespace); concatenating the leaves rebuilds the
   source verbatim, including the author's spacing and line breaks. That is
   simpler and more faithful than MakeExpression, which loses original spacing
   and (surprisingly) trips on multi-statement RowBoxes whose children include
   literal "\n" strings. The handful of 2D box types get one-dimensional
   surface equivalents - subscripts and superscripts have no surface form so we
   use the canonical functional one. *)
(* deactivate the four active PUA linear-syntax markers back to inert ASCII BEFORE
   normStr drops the whole PUA structural band - so a string-embedded box (a
   reactivated AssociationThread key, issue #44) round-trips md -> nb -> twin.md to
   the exact linear-syntax source instead of leaving broken SubscriptBox[...] text. *)
$linearSyntaxDeactivate = {
    FromCharacterCode[63425] -> "\\!", FromCharacterCode[63433] -> "\\(",
    FromCharacterCode[63432] -> "\\*", FromCharacterCode[63424] -> "\\)"};
boxToCode[s_String] := normStr @ StringReplace[s, $linearSyntaxDeactivate]
(* multi-statement Input cells store as BoxData[{b1, ";", "\n", b2, ...}] -
   a bare List of boxes. Without this rule the headless boxToCode fallback
   dumps the raw box tree via ToString[InputForm] (issue #16). *)
boxToCode[xs_List] := StringJoin[boxToCode /@ xs]
boxToCode[RowBox[xs_List]] := StringJoin[boxToCode /@ xs]
boxToCode[FractionBox[a_, b_, ___]] := boxToCode[a] <> "/" <> boxToCode[b]
boxToCode[SqrtBox[a_, ___]] := "Sqrt[" <> boxToCode[a] <> "]"
boxToCode[SubscriptBox[a_, b_, ___]] := "Subscript[" <> boxToCode[a] <> ", " <> boxToCode[b] <> "]"
boxToCode[SuperscriptBox[a_, b_, ___]] := boxToCode[a] <> "^" <> boxToCode[b]
boxToCode[SubsuperscriptBox[a_, b_, c_, ___]] := boxToCode[a] <> "_" <> boxToCode[b] <> "^" <> boxToCode[c]
boxToCode[OverscriptBox[a_, _, ___]] := boxToCode[a]
boxToCode[FormBox[b_, ___]] := walkerMath[b]
boxToCode[InterpretationBox[disp_, ___]] := boxToCode[disp]
boxToCode[TagBox[disp_, ___]] := boxToCode[disp]
boxToCode[StyleBox[disp_, ___]] := boxToCode[disp]
(* an auto-linked symbol in code / math is just its bare name *)
boxToCode[TemplateBox[{lbl_, ___}, "PackageLink" | "RefLink" | "RefLinkPlain", ___]] :=
    FirstCase[{lbl}, s_String :> s, "", Infinity]
boxToCode[TemplateBox[{x_}, "Ket"]] := "|" <> boxToCode[x] <> "\[RightAngleBracket]"
boxToCode[TemplateBox[{x_}, "Bra"]] := "\[LeftAngleBracket]" <> boxToCode[x] <> "|"
boxToCode[TemplateBox[{x_, y_}, "Braket" | "BraKet"]] :=
    "\[LeftAngleBracket]" <> boxToCode[x] <> "|" <> boxToCode[y] <> "\[RightAngleBracket]"
boxToCode[other_] := ToString[other, InputForm]

(* === inline emphasis wrapper ===
   wrap a markdown run in italic / bold asterisk markers, but NOT when it is
   punctuation / bracket only (italicising "]" gives a stray "*]*"), and NOT
   when it is already wrapped at the same level. *)
emWrap[s_String, mark_String] := Which[
    s === "" || StringMatchQ[s, (PunctuationCharacter | WhitespaceCharacter | "[" | "]" | "{" | "}" | "(" | ")") ..], s,
    (* match the literal mark; a bare "*" in a StringMatchQ pattern is the
       abbreviated-wildcard, which matches "" on both ends and reports every
       string as already-wrapped, dropping the marks (issue #54) *)
    StringMatchQ[s, Verbatim[mark] ~~ Except["*"] .. ~~ Verbatim[mark]], s,
    True, mark <> s <> mark
]

(* === string cleaner for inline captions ===
   A placeholder string in an authoring nb is stored as front-end linear syntax:
   "<PUA lead-in>StyleBox["x", "TI"]<PUA close>". The linear-syntax markers are
   private-use characters; convert StyleBox["x","TI"] -> *x*, SubscriptBox ->
   $_{}$ etc., then drop the PUA markers and map formal/script/etc. glyphs.
   Do NOT put the raw linear-syntax form in this source: Get would parse it
   back into boxes. *)
dq[s_String] := StringTrim[StringTrim[StringTrim[s], "\""], "()" | "(" | ")"]
mathDq[x_String] := StringReplace[dq[x], Normal @ $mathTeX]
(* normStr FIRST (not stripStructPUA): it maps the script/gothic/double-struck
   PUA letters to their Unicode glyphs and only then drops the remaining FE
   structural markers, so styled letters survive instead of being scrubbed with
   the markers (issue #31). *)
cleanStr[s_String] := normStr @ StringReplace[normStr[s], {
    "StyleBox[\"" ~~ Shortest[v__] ~~ "\", \"TI\"]" :> "*" <> v <> "*",
    "DisplayForm[StyleBox[" ~~ Shortest[v__] ~~ ", TI]]" :> "*" <> v <> "*",
    "StyleBox[" ~~ Shortest[v__] ~~ ", TI]" :> "*" <> v <> "*",
    "SubsuperscriptBox[" ~~ Shortest[a__] ~~ ", " ~~ Shortest[b__] ~~ ", " ~~ Shortest[c__] ~~ "]" :> "$" <> mathDq[a] <> "_{" <> mathDq[b] <> "}^{" <> mathDq[c] <> "}$",
    "SubscriptBox[" ~~ Shortest[a__] ~~ ", " ~~ Shortest[b__] ~~ "]" :> "$" <> mathDq[a] <> "_{" <> mathDq[b] <> "}$",
    "SuperscriptBox[" ~~ Shortest[a__] ~~ ", " ~~ Shortest[b__] ~~ "]" :> "$" <> mathDq[a] <> "^{" <> mathDq[b] <> "}$"
}]

(* === plain text extractor (titles, ObjectName, sectionTitle) === *)
cellPlain[s_String] := normStr[s]
cellPlain[TextData[xs_List]] := StringJoin[cellPlain /@ xs]
cellPlain[TextData[x_]] := cellPlain[x]
cellPlain[c_Cell] /; decorationCellQ[c] := ""
cellPlain[Cell[c_, ___]] := cellPlain[c]
cellPlain[BoxData[b_]] := boxToCode[b]
cellPlain[StyleBox[s_, ___]] := cellPlain[s]
cellPlain[ButtonBox[n_String, ___]] := n
cellPlain[_] := ""

(* === signature serialiser ===
   A Usage call box "Sym[...]" renders to <code>[Sym]()[*x*, *y*]</code>:
     - a Link ButtonBox -> [Name]()
     - the head bare identifier of a call -> [Name]() (linked)
     - an italic (TI) string arg -> *arg*
     - a subscript -> $base_{i}$ (canonical inline math, base INSIDE the math:
       MarkdownToNotebook's mathArgsToTemplate round-trips this to a clean
       subscript; the looser *base*$_i$ form round-trips broken)
     - operators / brackets / commas / arrows pass literally. *)
(* a documentation-link TemplateBox (PackageLink / RefLink / RefLinkPlain) that the
   front end auto-links into a signature head or an inline symbol mention. Recover
   the inferred-link markdown "[Name]()" (or "[Name](uri)" when the uri tail is not
   the name). Without this the raw box dumped into the output as ToString[..]. *)
$linkTemplates = "PackageLink" | "RefLink" | "RefLinkPlain";
linkBoxName[TemplateBox[{lbl_, ___}, $linkTemplates, ___]] := FirstCase[{lbl}, s_String :> s, "", Infinity]
linkBoxUri[TemplateBox[{_, uri_String, ___}, $linkTemplates, ___]] := uri
linkBoxUri[_] := ""
linkTemplateBoxQ[TemplateBox[{_, _String, ___}, $linkTemplates, ___]] := True
linkTemplateBoxQ[_] := False
inferredLinkMd[tb_] := With[{name = linkBoxName[tb], uri = linkBoxUri[tb]},
    Which[
        name === "", "",
        (* a single letter is a signature placeholder the front end over-linked into
           a bogus "paclet:ref/A" chip - render it as the italic placeholder it is,
           not a link (a real one-letter symbol reference is vanishingly rare) *)
        StringLength[name] === 1, "*" <> name <> "*",
        StringEndsQ[uri, "/" <> name], "[" <> name <> "]()",
        True, "[" <> name <> "](" <> uri <> ")"
    ]]

sig[s_String] := cleanStr[s]
sig[bb_ButtonBox] := "[" <> cellPlain[bb[[1]]] <> "]()"
sig[tb_TemplateBox] /; linkTemplateBoxQ[tb] := inferredLinkMd[tb]
sig[StyleBox[s_String, "TI", ___]] := emWrap[normStr[s], "*"]
sig[StyleBox[s_, ___]] := sig[s]
sig[SubscriptBox[a_, b_]] := "$" <> sigSub[a] <> "_{" <> sigSub[b] <> "}$"
sig[SuperscriptBox[a_, b_]] := "$" <> sigSub[a] <> "^{" <> sigSub[b] <> "}$"
sig[SubsuperscriptBox[a_, b_, c_]] := "$" <> sigSub[a] <> "_{" <> sigSub[b] <> "}^{" <> sigSub[c] <> "}$"
sig[FractionBox[a_, b_]] := sig[a] <> "/" <> sig[b]
sig[RowBox[xs_List]] := Which[
    MatchQ[xs, {_String, "[", ___}] && StringMatchQ[First[xs], LetterCharacter ~~ (WordCharacter | "$") ...],
        "[" <> First[xs] <> "]()" <> StringJoin[sig /@ Rest[xs]],
    (* an auto-linked head: "RicciTensor[m]" where RicciTensor is a link chip *)
    MatchQ[xs, {_?linkTemplateBoxQ, "[", ___}],
        inferredLinkMd[First[xs]] <> StringJoin[sig /@ Rest[xs]],
    True, StringJoin[sig /@ xs]]
sig[FormBox[b_, ___]] := sig[b]
sig[f_Symbol] := SymbolName[f]
sig[other_] := normStr @ boxToCode[other]
sigSub[StyleBox[s_, ___]] := sigSub[s]
sigSub[s_String] := StringReplace[normStr[s], Normal @ $mathTeX]
sigSub[RowBox[xs_List]] := StringJoin[sigSub /@ xs]
sigSub[x_] := walkerMath[x]
sigBox[x_] := sig[x]

(* a call-form rendered as inline math, for a narrative (non-doc) notebook
   (issue #38): the head goes upright via \mathrm so a multi-letter name is not an
   italic product, and the arguments walk as ordinary math. The <code>[Sym]()[...]
   signature DSL is kept only on a doc page (an ObjectName cell), where MTN's
   forward parser round-trips it. *)
callFormHead[s_String] := If[
    StringLength[s] > 1 && StringMatchQ[s, (LetterCharacter | DigitCharacter) ..],
    "\\mathrm{" <> s <> "}", walkerMath[s]]
callFormHead[StyleBox[s_, ___]] := callFormHead[s]
callFormHead[s_Symbol] := callFormHead[SymbolName[s]]
callFormHead[h_] := walkerMath[h]
callFormMath[FormBox[b_, ___]] := callFormMath[b]
callFormMath[RowBox[{h_, rest___}]] := callFormHead[h] <> StringJoin[walkerMath /@ {rest}]
callFormMath[other_] := walkerMath[other]

(* does a box tree carry 2D math structure (so it should render as $...$, not `code`)? *)
mathyQ[b_] := ! FreeQ[b, _SubscriptBox | _SuperscriptBox | _SubsuperscriptBox |
    _FractionBox | _SqrtBox | _RadicalBox | _OverscriptBox | _UnderscriptBox | _UnderoverscriptBox |
    _GridBox | _FormBox |
    TemplateBox[_, "Ket" | "Bra" | "Braket" | "BraKet" | "SuperDagger" | "Dagger" | "Conjugate" | "Abs" | "Norm"]]

(* a flat formula may have no 2D structure but still carry math-only glyphs -
   Greek (U+0370..03FF), letterlike script (U+2100..214F), the Mathematical
   Alphanumeric Symbols block (U+1D400..1D7FF, where \mathbb / \mathfrak / script
   letters land after normStr's PUA mapping, issue #52), or the Wolfram
   math-letter / constant PUA band (U+F6B2..F7E4). Treat those as math too,
   so the InlineFormula dispatch routes them to "$...$" rather than the code
   fallback (issue #15). *)
mathCharQ[c_String] := With[{n = First @ ToCharacterCode[c]},
    880 <= n <= 1023 || 8448 <= n <= 8527 || 119808 <= n <= 120831 || 63154 <= n <= 63460]
mathLikeQ[b_] := mathyQ[b] || ! FreeQ[b, s_String /; AnyTrue[Characters[s], mathCharQ]]

(* a non-Link call box (Sym[...], "name"[...], *circ*[...]) is a SIGNATURE, not
   a formula, so it should render as <code> even without a Link BaseStyle.
   Guard out heavy-math boxes so a functional-form formula (e.g. Tr[Sqrt[...]])
   stays $...$. A code signature is sometimes authored inside a TraditionalForm
   FormBox; unwrap so it still routes to <code> rather than $...$ math (where
   literal {} / [] would become invisible TeX grouping). *)
sigCallBoxQ[RowBox[{h_, "[", ___}] ? (FreeQ[#, SqrtBox | FractionBox | RadicalBox | UnderoverscriptBox] &)] :=
    MatchQ[h, _Symbol | _String | StyleBox[_, "TI", ___]] || linkTemplateBoxQ[h]
sigCallBoxQ[FormBox[b_, ___]] := sigCallBoxQ[b]
sigCallBoxQ[_] := False

(* === inline TextData -> markdown text ===
   Patterns mirror the forward parser's inlineTextData output so a round trip
   preserves formatting choices. *)
inlineMd[s_String] := cleanStr[s]
inlineMd[c_Cell] /; decorationCellQ[c] := ""

(* StyleBox: TI-wrapped subscript/superscript becomes canonical inline math
   (the most-specific cases win pattern dispatch); a TI / TB wrap becomes
   italic / bold; a "Code" wrap is a code span. *)
inlineMd[StyleBox[SubscriptBox[a_, b_], "TI", ___]] := "$" <> walkerMath[a] <> "_{" <> walkerMath[b] <> "}$"
inlineMd[StyleBox[SuperscriptBox[a_, b_], "TI", ___]] := "$" <> walkerMath[a] <> "^{" <> walkerMath[b] <> "}$"
inlineMd[StyleBox[s_, "TI", ___]] := emWrap[inlineMd[s], "*"]
inlineMd[StyleBox[s_, "Code", ___]] := "`" <> boxToCode[s] <> "`"
inlineMd[StyleBox[s_, opts___]] := With[{styles = {opts}, inner = inlineMd[s]},
    Which[
        MemberQ[styles, FontSlant -> "Italic"], emWrap[inner, "*"],
        MemberQ[styles, "TB"] || MemberQ[styles, FontWeight -> "Bold"], emWrap[inner, "**"],
        True, inner
    ]
]

(* paclet-link button -> [Name]() (the inferred form the forward parser knows). *)
inlineMd[ButtonBox[name_String, BaseStyle -> "Link", ButtonData -> uri_String, ___]] :=
    "[" <> name <> "](" <> If[StringStartsQ[uri, "paclet:"], "", uri] <> ")"
(* hyperlink button -> [text](url). *)
inlineMd[ButtonBox[name_String, BaseStyle -> "Hyperlink", ButtonData -> {URL[u_String], ___}, ___]] :=
    "[" <> name <> "](" <> u <> ")"
(* a generic ButtonBox - the FE often wraps the label in a StyleBox/RowBox and
   may give BaseStyle a Dynamic mouse-over. Treat it as an inferred symbol link. *)
inlineMd[bb_ButtonBox] := "[" <> cellPlain[bb[[1]]] <> "]()"

(* An InlineFormula cell wraps either a FormBox (typeset math from a "$...$"
   span), a Link/call box (a "`Symbol`" or call-form signature), a 2D math
   tree, or a plain WL box tree. Dispatch on the shape so a signature renders
   as <code>[Sym]()[...]</code>, real math as $math$, and a plain backticked
   code-span as `code`. *)
inlineMd[Cell[BoxData[FormBox[b_, ___]], "InlineFormula", ___]] := "$" <> walkerMath[b] <> "$"
inlineMd[Cell[BoxData[StyleBox[s_, "TI", ___]], "InlineFormula", ___]] :=
    (* a TI string inside an InlineFormula is a "*x*" signature placeholder ONLY on
       a doc page; in a narrative notebook it can only have come from a "$x$" span,
       so route it back to math (issue #53) *)
    If[mathLikeQ[s] || ! $docPageQ, "$" <> walkerMath[s] <> "$", "*" <> boxToCode[s] <> "*"]
inlineMd[Cell[BoxData[ButtonBox[a___]], "InlineFormula", ___]] := inlineMd[ButtonBox[a]]
inlineMd[Cell[BoxData[TagBox[bb_ButtonBox, ___]], "InlineFormula", ___]] := inlineMd[bb]
(* a typed documentation link (PackageLink / RefLink / RefLinkPlain TemplateBox) in
   prose walks back to the inferred-link form "[Name]()" when the URI's tail is the
   name itself (MarkdownToNotebook re-infers the target), and to an explicit
   "[Name](uri)" otherwise. Without this the chip fell through to a plain
   backtick code span, demoting every symbol link on the page. *)
inlineMd[Cell[BoxData[tb_TemplateBox], "InlineFormula", ___]] /; linkTemplateBoxQ[tb] := inferredLinkMd[tb]
(* an inferred link "[Manifold]()" builds to a BARE symbol name in an InlineFormula
   (the documentation build auto-links it later), indistinguishable from an authored
   code span. On a doc page the convention is that a bare CamelCase symbol mention
   IS a link, so walk it back to the inferred form rather than demoting to `code`. *)
inferredSymbolQ[s_String] := StringLength[s] >= 2 &&
    StringMatchQ[s, (_?UpperCaseQ) ~~ (WordCharacter | "$" | "`") ..]
inlineMd[c0 : Cell[BoxData[s_String], "InlineFormula", ___]] /;
    ! decorationCellQ[c0] && $docPageQ && inferredSymbolQ[s] := "[" <> s <> "]()"
(* a list / association literal ("{{A}}") on a doc page is inline WL code, written
   <code>...</code> like a call so the choice is consistent across code spans *)
docListBoxQ[RowBox[{"{" | "\[LeftAssociation]", ___}]] := True
docListBoxQ[_] := False
inlineMd[c0 : Cell[BoxData[b_], "InlineFormula", ___]] /; ! decorationCellQ[c0] := Which[
    ! FreeQ[b, BaseStyle -> "Link" | "Hyperlink"], "<code>" <> sigBox[b] <> "</code>",
    sigCallBoxQ[b] && ($docPageQ || MatchQ[b, _FormBox]), "<code>" <> sigBox[b] <> "</code>",
    $docPageQ && docListBoxQ[b], "<code>" <> sigBox[b] <> "</code>",
    sigCallBoxQ[b], "$" <> callFormMath[b] <> "$",
    (* narrative notebook (no signature DSL): TI content in an InlineFormula is a
       "$...$" span of italic letters, e.g. $cz$ -> RowBox of TI (issue #53) *)
    ! $docPageQ && ! FreeQ[b, StyleBox[_, "TI", ___]], "$" <> walkerMath[b] <> "$",
    mathLikeQ[b], "$" <> walkerMath[b] <> "$",
    True, With[{c = cleanStr[boxToCode[b]]},
        (* a styled-string placeholder ("name" with TI) cleans to contain *...*;
           emit as bare italic prose, not a backtick code span (asterisks don't
           render in code). *)
        If[StringContainsQ[c, "*"], c, "`" <> c <> "`"]]
]

(* a generic BoxData wrapper in a Cell: unwrap a nested Cell, route call-form
   to <code>, 2D math to $...$, otherwise emit as inline code. *)
inlineMd[c0 : Cell[BoxData[b_], ___]] /; ! decorationCellQ[c0] :=
    Which[
        MatchQ[b, _Cell], inlineMd[b],
        sigCallBoxQ[b] && ($docPageQ || MatchQ[b, _FormBox]), "<code>" <> sigBox[b] <> "</code>",
        sigCallBoxQ[b], "$" <> callFormMath[b] <> "$",
        mathLikeQ[b], "$" <> walkerMath[b] <> "$",
        True, "`" <> boxToCode[b] <> "`"
    ]
inlineMd[BoxData[b_]] := If[mathLikeQ[b], "$" <> walkerMath[b] <> "$", "`" <> boxToCode[b] <> "`"]

(* TraditionalForm / StandardForm math at the inline level. *)
inlineMd[FormBox[box_, TraditionalForm | StandardForm, ___]] :=
    "$" <> walkerMath[box] <> "$"
inlineMd[FractionBox[a_, b_]] := "$" <> walkerMath[a] <> "/" <> walkerMath[b] <> "$"
inlineMd[SubscriptBox[a_, b_]] := "$" <> walkerMath[a] <> "_" <> walkerMath[b] <> "$"
inlineMd[SuperscriptBox[a_, b_]] := "$" <> walkerMath[a] <> "^" <> walkerMath[b] <> "$"
inlineMd[SqrtBox[a_]] := "$\\sqrt{" <> walkerMath[a] <> "}$"
inlineMd[OverscriptBox[a_, "^"]] := "$\\hat{" <> walkerMath[a] <> "}$"

(* nested cells (a doc table cell can wrap its prose several Cells deep:
   Cell[TextData[Cell[BoxData[Cell[TextData[...],"TableText"]]]]]). Recurse into
   the content instead of letting boxToCode ToString-dump the inner Cell:
   a TEXT cell (TextData / String content) -> unwrap to its content. *)
inlineMd[c0 : Cell[content : (_TextData | _String), _String, ___]] /; ! decorationCellQ[c0] := inlineMd[content]

inlineMd[RowBox[xs_List]] := StringJoin[inlineMd /@ xs]
inlineMd[TextData[xs_List]] := StringJoin[inlineMd /@ xs]
inlineMd[TextData[x_]] := inlineMd[x]
inlineMd[TagBox[x_, ___]] := inlineMd[x]
inlineMd[InterpretationBox[x_, ___]] := inlineMd[x]
inlineMd[other_] := ToString[other, InputForm]

(* === faithful Input code via FE InputText, with a kernel-only fallback ===
   The front end's "InputText" export packet gives the verbatim typed source of
   a Cell, preserving subscripts (a_1), `@`, `//`, `[[…]]`, `%`, the author's
   spacing, and 2D box content as their linear-syntax equivalents - faithful to
   what the user typed. CallFrontEnd needs a live FE link, so the public entry
   wraps the whole walk in UsingFrontEnd. When that fails (no FE reachable,
   e.g. a minimal Notebook[] handed in directly with no kernel-FE link), fall
   back to a pure-kernel boxToCode tree walk so the walker still produces
   output, just less faithful for exotic 2D code shapes. *)
feInputText[bd_] := Module[{r},
    r = MathLink`CallFrontEnd[FrontEnd`ExportPacket[Cell[bd, "Input"], "InputText"]];
    StringTrim @ If[MatchQ[r, {_String, ___}], First[r], ToString[r]]
]
(* Strip a wrapping TagBox / InterpretationBox before handing the cell to
   the FE - InputText preserves these wrappers as their linear-syntax TagBox[...]
   box form (the FE thinks they're meaningful 2D structure) and
   surfaces them in the recovered fence as raw box source instead of the
   code the cell visually renders as. Every other walker (boxToCode,
   inlineMd, walkerMath) already unwraps these heads (issue #6). *)
codeText[BoxData[TagBox[b_, ___]]] := codeText[BoxData[b]]
codeText[BoxData[InterpretationBox[b_, ___]]] := codeText[BoxData[b]]
codeText[bd : BoxData[b_]] := Module[{r},
    r = Quiet @ Check[feInputText[bd], $Failed];
    If[StringQ[r] && r =!= "", r, boxToCode[b]]
]
codeText[c : Cell[BoxData[b_], ___]] := codeText[BoxData[b]]
(* String-content Input cells: re-escape any private-use-area glyph back to
   its canonical WL form (`\[ImaginaryI]` U+F74E -> `I`, `\[ExponentialE]`
   -> `E`, named-letter glyphs -> their `\[Name]` escape) so the fenced
   code block renders in a browser instead of carrying a missing-glyph
   box. The kernel's ASCII CharacterEncoding does the right thing - and
   notably keeps `\[ImaginaryI]` as `I` (the imaginary unit), unlike the
   prose normStr that lowercases it to `i` (issue #7). *)
codeText[s_String] := puaSafeCode[s]
codeText[other_] := boxToCode[other]

(* Full Unicode PUA: U+E000 (57344) - U+F8FF (63743). The formal-letter
   block (\[FormalA]..\[FormalZ], U+F800-U+F833) sits in the upper half,
   so the bound has to cover it. *)
puaSafeCode[s_String] := StringJoin @ Map[
    With[{n = First @ ToCharacterCode[#]},
        If[57344 <= n <= 63743, ToString[#, CharacterEncoding -> "ASCII"], #]
    ] &,
    Characters[s]
]

(* === per-cell builders === *)

(* clean caption whitespace (newlines -> space, collapse) *)
tidy[s_String] := StringTrim @ StringReplace[s, {"\n" -> " ", "\r" -> " ", Whitespace -> " "}]

(* the Usage cell: split the TextData on ModInfo separators - the doc template's
   actual statement boundaries - into one paragraph per usage statement. Splitting
   on ModInfo (not on every signature-like element) keeps an inline symbol
   reference inside a description from being mistaken for a new statement. *)
usageMd[TextData[xs_List]] := Module[{lines = {}, cur = {}},
    Do[
        Which[
            (* a ModInfo placeholder starts a new signature statement; a bare "\n"
               separates lines, so a FREE prose line (one with no ModInfo) still
               becomes its own paragraph instead of gluing onto the previous one *)
            MatchQ[e, Cell[_, "ModInfo", ___]] || e === "\n",
                If[cur =!= {}, AppendTo[lines, cur]]; cur = {},
            True,
                AppendTo[cur, e]
        ],
        {e, xs}
    ];
    If[cur =!= {}, AppendTo[lines, cur]];
    StringRiffle[tidy[StringJoin[inlineMd /@ #]] & /@ DeleteCases[lines, {}], "\n\n"]
]
usageMd[other_] := tidy @ inlineMd[other]

(* ExampleSection wraps its title in an InterpretationBox counter cell;
   ExampleSubsection / Subsubsection store the title string directly. *)
sectionTitle[content_] := Module[{inner},
    inner = FirstCase[content, Cell[t_, _String, ___] :> t, $noInner, Infinity];
    cellPlain @ If[inner === $noInner, content, inner]
]

(* GridBox rows -> pipe table; drop ModInfo spacer columns. The left "spec"
   column of a doc table is the literal thing you type, so a bare-string spec
   ("Bell") and a subscript-free call-form spec ("Graph"[g]) both render as
   inline code so the spec column is uniform. A spec carrying a 2D subscript
   ("Multiplexer"[op_1,...]) can't live in a code span (backticking would
   linearise op_1 to the literal text Subscript[op, 1]), so it renders as a
   signature with canonical $op_{1}$ math instead. *)
spacerQ[Cell[s_String, "ModInfo", ___]] := StringMatchQ[s, Whitespace | ""]
spacerQ[_] := False
gridCellMd[s_String] := "`" <> StringTrim[s] <> "`"
gridCellMd[Cell[t_, "TableText", ___]] := tidy @ inlineMd[t]
gridCellMd[b_ /; sigCallBoxQ[b] && FreeQ[b, SubscriptBox | SuperscriptBox | SubsuperscriptBox]] :=
    "`" <> boxToCode[b] <> "`"
gridCellMd[b_ /; sigCallBoxQ[b]] := tidy @ sig[b]
gridCellMd[c_] := tidy @ inlineMd[c]
gridTable[rows_List] := Module[{drows, ncol},
    drows = Function[r, gridCellMd /@ DeleteCases[r, _?spacerQ]] /@ rows;
    drows = DeleteCases[drows, {}];
    If[drows === {}, Return[""]];
    ncol = Max[Length /@ drows];
    drows = PadRight[#, ncol, ""] & /@ drows;
    StringRiffle[
        Join[
            {"| " <> StringRiffle[ConstantArray[" ", ncol], " | "] <> " |"},
            {"|" <> StringRiffle[ConstantArray["---", ncol], "|"] <> "|"},
            ("| " <> StringRiffle[#, " | "] <> " |") & /@ drows
        ],
        "\n"
    ]
]

(* Styles a walker should skip entirely:
     - evaluation artifacts (Output / Message / MSG / Print): regenerate on re-run
     - template metadata cells (Categorization, Keywords, SeeAlso, MoreAbout,
       ...): the frontmatter recovery (below) reads these directly; emitting
       them as prose would duplicate the YAML
     - template decoration (MoreInfoText / DockedCell / *CellLabel / *Flag):
       inserted by the front end for the resource authoring UI, never in source *)
$dropStyles = {
    "Output", "Message", "MSG", "Print", "ExampleInitialization",
    "ModInfo", "MoreInfoText", "MoreInfoTextOuter",
    "DockedCell",
    "ExcludedCellLabel", "HiddenMaterialCellLabel",
    "FutureFlag", "ExcisedFlag", "ObsoleteFlag", "TemporaryFlag", "PreviewFlag", "InternalFlag",
    "Categorization", "CategorizationSection",
    "Keywords", "KeywordsSection", "MetadataSection",
    (* guide-page metadata recovered into the frontmatter (RelatedGuides / Links)
       and empty template section headers *)
    "GuideTutorialsSection", "GuideMoreAboutSection", "GuideMoreAbout",
    "GuideRelatedLinksSection", "GuideRelatedLinks",
    "Template", "TemplatesSection",
    "History", "HistoryData",
    "TechNotesSection", "Tutorials",
    "RelatedDemonstrations", "RelatedDemonstrationsSection",
    "RelatedLinks", "RelatedLinksSection",
    "SeeAlso", "SeeAlsoSection",
    "MoreAbout", "MoreAboutSection",
    "ExtendedExamplesSection", "ExamplesInitializationSection"
}

(* ====================================================================== *)
(* Round-trip metadata emission (mirrors MarkdownToNotebook's read side).   *)
(*                                                                          *)
(*   "Metadata":                                                            *)
(*     Automatic (default) - emit "#| style:"/"#| tags:" only for cells     *)
(*       that are NOT a doc template's own default/scaffolding cells, so a   *)
(*       built template notebook recovers cleanly while a hand-authored     *)
(*       custom style/tag still round-trips. Comment carrier.               *)
(*     "Comment" - ALWAYS emit (every non-standard style + every real tag); *)
(*       directives written as "<!-- #| k: v -->" (GitHub-invisible).       *)
(*     "Inline"  - ALWAYS emit; directives as bare "#| k: v" lines.         *)
(*     None      - never emit cell metadata.                                *)
(*   One directive per line (the reader splits a line on its first colon).  *)
(* ====================================================================== *)
Options[NotebookToMarkdown] = {
    "Metadata" -> Automatic,        (* Automatic | "Comment" | "Inline" | None *)
    "PreserveOutputs" -> False,     (* emit Output cells (else dropped, regenerated on re-run) *)
    "OutputInlineLimit" -> 2048,    (* WXF bytes: <= inline "#| boxes", > spill to a ".wxf" sidecar *)
    "OutputCommentLimit" -> 400     (* chars: an example result longer than this is marked
                                       "#| screenshot: true" instead of a "<!-- => v -->" comment;
                                       comfortably above a typical list result (the FE can render
                                       the same boxes slightly longer than a fresh expression) *)
};

$metadataCarrier  = Automatic;
$preserveOutputs  = False;
$outputInlineLimit = 2048;
$outputCommentLimit = 400;
$n2mAssetDir   = None;   (* directory for ".wxf" sidecars; None (in-memory) forces inline *)
$n2mAssetBase  = "cell";
$n2mOutCounter = 0;
$n2mFigCounter = 0;      (* authored-figure ".png" counter (issue #34) *)

(* styles whose markdown form round-trips to the same style - no "#| style:" *)
$knownBlockStyles = {
    "Title", "Section", "Subsection", "Subsubsection", "ObjectName",
    "Usage", "UsageDescription", "UsageLine", "Notes",
    "GuideTitle", "GuideAbstract", "GuideFunctionsSection",
    "GuideFunctionsSubsection", "GuideText", "GuideDelimiter", "GuideTOCLink",
    "2ColumnTableMod", "3ColumnTableMod", "TableNotes",
    "Text", "Quote", "Caption", "ExampleText", "CodeText",
    "Item", "Item1", "Item2", "Bullet", "ItemNumbered", "ItemNumbered1",
    "Input", "Code", "ExampleInput", "Program",
    "PrimaryExamplesSection", "ExampleSection", "ExampleSubsection",
    "ExampleSubsubsection", "ExampleDelimiter", "InlineFormula",
    (* "$$...$$" display math (issue #40) *)
    "DisplayFormula",
    (* Chapter back-matter sections + their content, all round-tripping to
       "## Title" / list / prose (issue #50) *)
    "SummarySection", "VocabularySection", "KeyConceptsSection", "ExerciseSection",
    "QASection", "TechNoteSection", "MoreExploreSection", "ReferenceSection",
    "ResourcesSection", "TakeawaysSection", "VocabularySubsection",
    "SummaryList", "Reference", "TechNoteItem", "MoreExploreItem", "ResourceItem",
    "TakeawaysList", "KeyConceptsList", "SummaryNote", "VocabularyText",
    "ExerciseNote", "ExerciseSectionNote", "TechNote", "QANote"
};
(* DocumentationTools scaffolding a template fills in by default: a cell with such
   a style / tag is a template default cell, skipped under Automatic (not authored
   content) but force-emitted under "Comment"/"Inline". *)
$templateStyles = {"UsageInputs", "InlineCode", "RelatedSymbol", "TableText"};
(* M2N-managed markers never emitted as #| tags: "DefaultContent" is the scraper
   marker; "TextAnnotation" rides the dedicated "#| annotation:" directive. *)
$internalTags = {"DefaultContent", "TextAnnotation", "MTNScreenshot", "MTNUnfilled"};
allCellTags[opts_List] := Flatten[Cases[opts, (CellTags -> t_) :> Flatten[{t}]]]

(* structural template markers - a cell carrying any of these is part of the doc
   template's own scaffolding (section groups, metadata cells, MoreInfo/
   Compatibility fields), so none of its style/tags are authored content. *)
templateMarkerQ[tag_String] :=
    StringStartsQ[tag, "Template"] || StringStartsQ[tag, "SectionMoreInfo"] ||
    StringStartsQ[tag, "Compatibility"] ||
    MemberQ[{"Name", "Title", "Description", "Documentation", "ScrapeDefault",
             "TabNext", "Source & Additional Information"}, tag]
templateDefaultCellQ[style_, opts_List] :=
    MemberQ[$templateStyles, style] || AnyTrue[allCellTags[opts], templateMarkerQ]

directiveOne[k_, v_] := If[$metadataCarrier === "Inline",
    "#| " <> k <> ": " <> v,
    "<!-- #| " <> k <> ": " <> v <> " -->"]
directiveBlock[dirs_List] := StringRiffle[directiveOne @@@ dirs, "\n"]

(* the note text of an "Annotate" annotation: the first string in the cell's
   bottom-right "TextAnnotation" CellFrameLabels (the rest of that frame label is
   the Edit/Delete chrome). Returns Missing[] for an un-annotated cell. *)
annotationNoteOf[opts_List] := FirstCase[opts,
    (CellFrameLabels -> {{_, _}, {_, Cell[TextData[{note_String, ___}], "TextAnnotation", ___]}}) :>
        StringTrim[note],
    Missing[]]

(* prepend a cell's style/tags/annotation directives (when needed) to its
   rendered body. Automatic skips a template's own default cells whole;
   "Comment"/"Inline" force-include. A non-standard style emits "#| style:";
   CellTags (minus M2N-managed markers) emit "#| tags:"; an Annotate annotation
   emits "#| annotation:". An annotation is always authored content, so it is
   emitted even on a template-default cell (which contributes no style/tags). *)
withCellMeta[body_, style_, opts_List] := Module[
    {mode = $metadataCarrier, dirs = {}, tags, note = annotationNoteOf[opts], isDefault,
     shot = MemberQ[allCellTags[opts], "MTNScreenshot"]},
    If[body === "" || mode === None, Return[body]];
    isDefault = (mode === Automatic && templateDefaultCellQ[style, opts]);
    (* an annotation or a screenshot mark is authored intent, emitted even on an
       otherwise template-default cell *)
    If[isDefault && MissingQ[note] && ! shot, Return[body]];
    If[shot, AppendTo[dirs, {"screenshot", "true"}]];
    If[! isDefault,
        If[! MemberQ[$knownBlockStyles, style] && ! MemberQ[$dropStyles, style],
            AppendTo[dirs, {"style", style}]];
        tags = DeleteCases[allCellTags[opts], Alternatives @@ $internalTags];
        If[tags =!= {}, AppendTo[dirs, {"tags", StringRiffle[tags, ", "]}]]
    ];
    If[! MissingQ[note],
        AppendTo[dirs, {"annotation", StringReplace[note, ("\r" | "\n") .. -> " "]}]];
    If[dirs === {}, body, directiveBlock[dirs] <> "\n" <> body]
]

(* a preserved Output cell: serialize its BoxData. Small (<= limit) inlines the
   boxes as "#| boxes: <InputForm>"; large spills to a ".wxf" sidecar referenced
   by "#| file:". Graphics/raster outputs are left to the image-twin path. *)
boxOneLine[boxes_] := ToString[boxes, InputForm, PageWidth -> Infinity]
preserveOutputBlock[BoxData[boxes_]] := preserveOutputBlock[boxes]
preserveOutputBlock[boxes_] := Module[{ba, ref},
    ba = Quiet @ ExportByteArray[boxes, "WXF"];
    If[ $n2mAssetDir =!= None && ByteArrayQ[ba] && Length[ba] > $outputInlineLimit,
        $n2mOutCounter += 1;
        ref = $n2mAssetBase <> "-out-" <> ToString[$n2mOutCounter] <> ".wxf";
        Quiet @ Export[FileNameJoin[{$n2mAssetDir, ref}], boxes, "WXF"];
        directiveBlock[{{"style", "Output"}, {"file", ref}}],
        directiveBlock[{{"style", "Output"}, {"boxes", boxOneLine[boxes]}}]
    ]
]

ClearAll[blockFor]
(* A preserved Output cell ("PreserveOutputs" -> True) round-trips its boxes via
   #| directives; defined first so it wins for Output cells. Graphics/raster
   outputs fall through to the drop below (the twin renders them as images). *)
blockFor["Output", c_] /; ($preserveOutputs && FreeQ[c, GraphicsBox | Graphics3DBox | RasterBox]) :=
    preserveOutputBlock[c]

(* On a doc/resource page a non-graphic Output cell is an example result; emit it
   as the "<!-- => value -->" annotation the source uses (MarkdownToNotebook drops
   that comment and re-evaluates, so it round-trips). Graphic outputs are the
   image-twin's job and carry no such comment. *)
blockFor["Output", c_] /; (! $preserveOutputs && $docPageQ && FreeQ[c, GraphicsBox | Graphics3DBox | RasterBox]) :=
    With[{t = tidy @ codeText[c]}, If[t === "", "", "<!-- => " <> t <> " -->"]]

(* A standalone graphic whose cell IS the graphic (BoxData holds only the
   GraphicsBox, not code) and whose style is an Input/Code cell is an AUTHORED
   figure - a hand-pasted picture, not regenerable output. Export it to a ".png"
   beside the ".md" and emit ![]() instead of dropping it (issue #34). With no
   asset dir (in-memory conversion) there is nowhere to write it, so fall back to
   the drop. These specific (style + graphic) rules out-sort the generic drops. *)
figureMd[g_] := If[$n2mAssetDir === None, "",
    Module[{ref},
        $n2mFigCounter += 1;
        ref = $n2mAssetBase <> "-fig-" <> ToString[$n2mFigCounter] <> ".png";
        Quiet @ Export[FileNameJoin[{$n2mAssetDir, ref}], RawBoxes[g], "PNG"];
        "![](" <> ref <> ")"]]
blockFor["Input" | "Code" | "ExampleInput" | "Program",
    BoxData[g : (GraphicsBox | Graphics3DBox | RasterBox)[___]]] := figureMd[g]
blockFor["Input" | "Code" | "ExampleInput" | "Program",
    BoxData[TagBox[g : (GraphicsBox | Graphics3DBox | RasterBox)[___], ___]]] := figureMd[g]

(* Image cells (raster or vector graphics in BoxData) are evaluation output, not
   source - the markdown twin embeds them as ![]() but the source markdown that
   produced them is the WL Input cell that evaluated to them. Drop. The TagBox
   wrapping covers the FE's "Image Placeholder" cell, which the resource
   templates inject under "Hero Image" / similar slots and is not authored. *)
blockFor[_, BoxData[(GraphicsBox | Graphics3DBox | RasterBox)[___]]] := ""
blockFor[_, BoxData[TagBox[(GraphicsBox | Graphics3DBox | RasterBox)[___], ___]]] := ""

(* Top-level headings. A doc template puts the function name in an ObjectName
   cell; frontmatter recovery emits it as `Name:`, so the cell itself drops. *)
(* An explicit "Details & Options" heading (the resource template makes it a real
   Subsection, promoted to a Section for the flat body) also satisfies the Notes
   slot, so mark it done - otherwise the Notes handler below emits a second one.
   The template titles that use "&" walk back to the "and" form the markdown
   sources author (both spellings rebuild to the same slot). *)
$andFormTitles = <|"Properties & Relations" -> "Properties and Relations",
    "Generalizations & Extensions" -> "Generalizations and Extensions"|>;
andFormTitle[t_String] := Lookup[$andFormTitles, t, t]
headingMd[level_, c_] := With[{t = cellPlain[c]},
    If[t === "Details & Options", $detailsHeadingDone = True];
    StringRepeat["#", level] <> " " <> andFormTitle[t]]
blockFor["Title", c_] := headingMd[1, c]
blockFor["Section", c_] := headingMd[2, c]
blockFor["Subsection", c_] := headingMd[3, c]
blockFor["Subsubsection", c_] := headingMd[4, c]
blockFor["ObjectName", _] := ""

(* Usage / Notes / property tables - the doc template's headings are implicit,
   so we emit the corresponding `##` / `- ` markers ourselves. The "## Details
   & Options" header fires once before the first Notes block so the section
   round-trips through MarkdownToNotebook (which maps that heading back to the
   Notes slot). *)
blockFor["Usage", c_] := "## Usage\n\n" <> usageMd[c]
blockFor["UsageDescription", c_] := tidy @ inlineMd[c]
blockFor["Notes", c_] := With[{b = "- " <> tidy @ inlineMd[c]},
    If[TrueQ[$detailsHeadingDone], b,
        $detailsHeadingDone = True; "## Details & Options\n\n" <> b]]
blockFor["2ColumnTableMod" | "3ColumnTableMod" | "TableNotes", BoxData[GridBox[rows_List, ___]]] := gridTable[rows]
blockFor["2ColumnTableMod" | "3ColumnTableMod", c_] := tidy @ inlineMd[c]

(* Prose styles. *)
blockFor["Text" | "Quote", c_] := tidy @ inlineMd[c]
blockFor["Caption", c_] := tidy @ inlineMd[c]
blockFor["ExampleText" | "CodeText", c_] := tidy @ inlineMd[c]

(* Lists. *)
blockFor["Item" | "Item1" | "Item2" | "Bullet", c_] := "- " <> tidy @ inlineMd[c]
blockFor["ItemNumbered" | "ItemNumbered1", c_] := "1. " <> tidy @ inlineMd[c]

(* Code cells: verbatim Input source via FE InputText (with kernel fallback).
   The fence length is one greater than the longest run of backticks in the
   cell body so an example showing ` ``` ` fences inside its source doesn't
   break the surrounding fence. Program cells emit with NO language tag - the
   .nb has no record of the original fence language (a `text` / `ebnf` / etc.
   fence becomes Program-styled the same as a `#| eval: false` wl cell), so we
   stay neutral: a no-lang fence round-trips back through MTN as Program. *)
codeFence[text_String] := Module[{maxRun = 2},
    Scan[(If[StringLength[#] > maxRun, maxRun = StringLength[#]]) &,
        StringCases[text, "`" ..]];
    StringRepeat["`", Max[3, maxRun + 1]]
]
fencedCode[txt_String, lang_String] := With[{f = codeFence[txt]},
    f <> lang <> "\n" <> txt <> "\n" <> f]
blockFor["Input" | "Code" | "ExampleInput", c_] := fencedCode[codeText[c], "wl"]
blockFor["Program", c_] := fencedCode[codeText[c], ""]

(* Example-section scaffold (the resource template's nested example structure). *)
blockFor["PrimaryExamplesSection", _] := "## Basic Examples"
blockFor["ExampleSection", c_] := "## " <> andFormTitle @ sectionTitle[c]
blockFor["ExampleSubsection", c_] := "### " <> andFormTitle @ sectionTitle[c]
blockFor["ExampleSubsubsection", c_] := "#### " <> sectionTitle[c]
blockFor["ExampleDelimiter", _] := "---"

(* InlineFormula at block level (rare; normally inlined). *)
blockFor["InlineFormula", c_] := "`" <> tidy @ inlineMd[c] <> "`"

(* Display math: a "$$...$$" block builds to a DisplayFormula cell wrapping the math
   in a centering PaneBox; unwrap it back to a "$$...$$" block (issue #40). *)
blockFor["DisplayFormula", BoxData[PaneBox[b_, ___]]] := "$$" <> walkerMath[b] <> "$$"
blockFor["DisplayFormula", BoxData[b_]] := "$$" <> walkerMath[b] <> "$$"

(* Chapter (Wolfram Book Tools) reserved back-matter sections: the H2 heading cell
   and its list / note content round-trip back to "## Title" + items (issue #50). *)
blockFor[("SummarySection" | "VocabularySection" | "KeyConceptsSection" |
    "ExerciseSection" | "QASection" | "TechNoteSection" | "MoreExploreSection" |
    "ReferenceSection" | "ResourcesSection" | "TakeawaysSection"), c_] := "## " <> sectionTitle[c]
blockFor["VocabularySubsection", c_] := "### " <> sectionTitle[c]
blockFor[("SummaryList" | "Reference" | "TechNoteItem" | "MoreExploreItem" |
    "ResourceItem" | "TakeawaysList" | "KeyConceptsList"), c_] := "- " <> tidy @ inlineMd[c]
blockFor[("SummaryNote" | "VocabularyText" | "ExerciseNote" | "ExerciseSectionNote" |
    "TechNote" | "QANote"), c_] := tidy @ inlineMd[c]

(* === Guide-page body (the inverse of MarkdownToNotebook's guideNotebook) ===
   The title / categorization / keywords / related guides live in the frontmatter;
   the body walks back to "## Abstract", "## Functions" with "- `Sym` desc" items
   (a built-in chip - one whose link is the system "paclet:ref/Sym" - re-emits the
   italic *`Sym`* form), "###" subsections, "---" delimiters, and the "## Guides"
   index. *)
guideChipMd[TemplateBox[{lbl_, uri_String, ___}, _, ___]] := With[
    {name = FirstCase[{lbl}, s_String :> s, "", Infinity]},
    If[StringStartsQ[uri, "paclet:ref/"], "*`" <> name <> "`*", "`" <> name <> "`"]]
guideItemPart[Cell[BoxData[tb_TemplateBox], "InlineGuideFunction", ___]] := guideChipMd[tb]
(* a navigation ButtonBox (a "## Guides" index entry) -> a markdown link *)
guideItemPart[Cell[BoxData[ButtonBox[l_String, ___, ButtonData -> u_String, ___]], "InlineFormula", ___]] :=
    "[" <> l <> "](" <> u <> ")"
guideItemPart[s_String] /; StringTrim[s] === "\[LongDash]" := " "
guideItemPart[s_String] := s
guideItemPart[other_] := inlineMd[other]
guideItemMd[TextData[xs_List]] := StringReplace[tidy @ StringJoin[guideItemPart /@ xs], " ," -> ","]
guideItemMd[TextData[x_]] := guideItemMd[TextData[{x}]]
guideItemMd[other_] := tidy @ inlineMd[other]

blockFor["GuideTitle", _] := ""                       (* the frontmatter Title *)
blockFor["GuideAbstract", c_] := "## Abstract\n\n" <> tidy @ inlineMd[c]
blockFor["GuideFunctionsSection", _] := "## Functions"
blockFor["GuideFunctionsSubsection", c_] := Which[
    (* the "Guides" divider heads the sub-guide index *)
    cellPlain[c] === "Guides", "## Guides",
    (* a whole-heading guide link: "### [Sub](paclet:.../guide/Sub)" *)
    MatchQ[c, BoxData[ButtonBox[_String, ___, ButtonData -> _String, ___]]],
        Replace[c, BoxData[ButtonBox[l_String, ___, ButtonData -> u_String, ___]] :>
            "### [" <> l <> "](" <> u <> ")"],
    True, "### " <> cellPlain[c]
]
blockFor["GuideText", c_] := "- " <> guideItemMd[c]
blockFor["GuideDelimiter", _] := "---"
blockFor["GuideTOCLink", c_] := "- " <> guideItemMd[c]

(* Drop known-decoration / evaluation / metadata styles. *)
blockFor[s_String, _] /; MemberQ[$dropStyles, s] := ""

(* Generic fallback: any unknown style is treated as prose. *)
blockFor[_String, c_] := tidy @ inlineMd[c]

(* === tree walk === *)
walkCell[Cell[CellGroupData[inner_List, ___]]] := walkCells[inner]
walkCell[Cell[content_, style_String, opts___]] := withCellMeta[blockFor[style, content], style, {opts}]
walkCell[_] := ""
walkCells[cells_List] := DeleteCases[Flatten[{walkCell /@ cells}], "" | Null]

(* === frontmatter recovery ===
   For doc-page notebooks (Symbol / Guide / TechNote authoring templates), the
   metadata that would have been YAML frontmatter lives in dedicated cells the
   walker drops as content (Categorization / Keywords / SeeAlso / MoreAbout).
   Recover it as a leading `---` block so the markdown twin is rebuildable.
   When the notebook has no Categorization cells (it isn't a doc template), the
   block is omitted and the walker emits a bare body, matching the historical
   behaviour for arbitrary notebooks. *)
catList[nb_] := Flatten @ Cases[nb, Cell[c_, "Categorization", ___] :> Cases[{c}, _String, Infinity], Infinity]
linkNames[nb_, style_] := Cases[
    FirstCase[nb, Cell[td_, style, ___] :> td, TextData[{}], Infinity],
    ButtonBox[n_String, ___] :> n, Infinity]
guideIds[nb_, style_] := Cases[
    FirstCase[nb, Cell[td_, style, ___] :> td, TextData[{}], Infinity],
    ButtonBox[_, ___, ButtonData -> d_String, ___] :> Last[StringSplit[d, "/"]], Infinity]
keywordList[nb_] := Flatten @ Cases[nb, Cell[c_, "Keywords", ___] :> Cases[{c}, _String, Infinity], Infinity]

(* Symbol-page templates carry an ObjectName cell (the function name) and a
   Categorization cell (entity type / paclet / context / URI). When both are
   present we emit a Symbol-template frontmatter the forward path can rebuild
   the doc-tools authoring notebook from. The resource-system family
   (FunctionResource, Data, Example, Prompt, Demonstration) is handled by
   resourceFrontmatter below, which reads the slot-tagged definition cells.
   Anything else emits no frontmatter, so the recovered .md round-trips as a
   generic body and the forward path is told the template by a hand-added block. *)
hasObjectNameQ[nb_] := ! FreeQ[nb, Cell[_, "ObjectName", ___]]
(* a documentation / resource notebook - where the <code>[Sym]()[...] signature DSL
   round-trips through MTN - as opposed to a free-form narrative notebook. An
   ObjectName cell marks a Symbol/Guide page; a resource or other template-built doc
   carries doc metadata in its TaggingRules ("Metadata" / "TemplateGroupName"). A
   bare narrative notebook has neither, so its call-forms render as real inline math
   (issue #38). *)
docNotebookQ[nb_] := hasObjectNameQ[nb] || AnyTrue[
    Cases[nb, (TaggingRules -> v_) :> v, {1}],
    ! FreeQ[Keys[#], "Metadata" | "ResourceType" | "DefinitionNotebookFramework"] &]
(* set per-notebook in markdownOfNb; defaults True so a direct inlineMd call keeps
   the signature DSL. *)
$docPageQ = True

(* === FunctionResource-family frontmatter recovery ===
   A resource definition notebook (Function / Prompt / Data / Example /
   Demonstration) keeps its metadata in template cells tagged by slot name: the
   Title is tagged "Name", the summary "Description", and the Source & Additional
   Information section groups the "Contributed By" / "Keywords" / "Related Symbols"
   / "Links" subsections. Reconstruct the canonical YAML the forward path reads
   (Name, Description, ContributedBy, Keywords, SeeAlso, Links) from those cells.
   Categories live in a checkbox widget whose *checked* state doesn't survive as
   text, so that slot is dropped; ShortName / RelatedResources are legacy keys the
   current schema folds into Name / (nothing). *)
$resourceTypeTemplate = <|"Function" -> "FunctionResource"|>;
templateForResourceType[rt_String] := Lookup[$resourceTypeTemplate, rt, rt]
resourceTypeOf[nb_] := FirstCase[Cases[nb, (TaggingRules -> v_) :> v, {1}],
    tr_ :> FirstCase[tr, (Rule | RuleDelayed)[ResourceType | "ResourceType", v_] :> ToString[v], Missing[]],
    Missing[], {1}]
cellHasTagQ[Cell[___, CellTags -> t_, ___], tag_] := MemberQ[Flatten[{t}], tag]
cellHasTagQ[_, _] := False
taggedCellText[nb_, tag_] := cellPlain @ FirstCase[nb, c : Cell[body_, ___] /; cellHasTagQ[c, tag] :> body, "", Infinity]
resourceLinkMd[c_] := Module[
    {b = FirstCase[c, ButtonBox[l_String, ___, ButtonData -> {URL[u_String], ___}, ___] :> {l, u}, Missing[], Infinity]},
    If[MissingQ[b], cellPlain[c], "[" <> First[b] <> "](" <> Last[b] <> ")"]]
(* Scoped to the families whose body-to-slot mapping is implemented. Recovering a
   family's frontmatter also makes MarkdownToNotebook rebuild through that family's
   template on the return trip, which only round-trips if the body cells map back to
   the template's slots - Function and Paclet emit the section names their slots are
   filled from, but Data / Example / Demonstration keep their own content-section
   names (e.g. "Data Definitions" -> ContentElements) that still need a per-family
   body transform. Until each is taught, they stay on the plain walker (no
   frontmatter), which round-trips as a generic document. *)
$resourceFamilies = {"Function", "Paclet"};
resourceDefNotebookQ[nb_] := MemberQ[$resourceFamilies, resourceTypeOf[nb]] &&
    ! FreeQ[nb, c_Cell /; cellHasTagQ[c, "Name"]]

(* === resource body normalization ===
   The resource definition notebook nests the authored content inside template
   scaffolding: a Title/Description carrying the frontmatter, "Documentation" and
   "Examples" wrapper sections whose subsections are the real content, and a
   "Source & Additional Information" section that is pure metadata (now in the
   frontmatter). Cell GROUPING is unreliable: a fresh MarkdownToNotebook expression
   nests each section in explicit CellGroupData, but the front end regroups an open
   notebook (NotebookGet returns one Title-rooted group), so the transform must not
   pattern-match on group shape. Instead: flatten every group away, then walk the
   flat cell list sectionally - a heading cell owns everything up to the next
   heading of the same or shallower level - dropping metadata sections by heading
   tag, bare wrapper labels, and unfilled template placeholders, then promoting the
   surviving subsections to `## Section`. Empty leftovers are removed afterwards by
   dropEmptySections. *)
(* Metadata / scaffolding sections recovered into the frontmatter (or pure template
   chrome) - dropped from the body across the resource families. The tag set is the
   union over Function / Data / Example / Demonstration / Paclet; a tag a given
   family lacks is simply never matched. "Author Notes" is NOT here: it is
   authorable from markdown, so it is kept when filled and disappears via the
   placeholder drop when untouched. *)
$resourceDropTags = {
    "Contributed By", "ContributorInformation", "Author Names", "AuthorNames",
    "Keywords", "Categories",
    "Related Symbols", "See Also", "SeeAlso", "Related Documentation Pages",
    "Related Resource Objects", "Related Demonstrations",
    "Source/Reference Citation", "Citation", "Detailed Source Information",
    "SourceControlURL", "Source Control Repository", "LicensingInformation",
    "Disclosures", "Links", "External Links", "Compatibility",
    "Content Types", "ContentTypes", "Submission Notes",
    (* Paclet chrome regenerated from the frontmatter on rebuild *)
    "PacletManifest", "Paclet Manifest", "PrimaryContext", "Primary Context",
    "MainGuidePage", "Main Guide Page",
    "ExampleInitialization", "Initialization for Examples"};
(* wrapper headings whose label is dropped and whose children ARE the body;
   "Source & Additional Information" keeps its code-bearing child (Tests). An
   "Author Notes" section is neither: kept whole when authored, and reduced to a
   bare heading by the placeholder drop (then removed by dropEmptySections) when
   untouched. *)
$resourceCommonFlattenTags = {"Source & Additional Information"};
$functionFlattenTags       = {"Documentation", "Examples"};
$pacletFlattenTags         = {"WebContent", "Web Content"};
promoteHeadings[expr_] := expr /. Cell[c_, s : ("Subsection" | "Subsubsection"), o___] :>
    Cell[c, Replace[s, {"Subsection" -> "Section", "Subsubsection" -> "Subsection"}], o]

(* The resource template splits a usage statement into a "UsageInputs" signature
   cell and a following "UsageDescription" cell; the Symbol form keeps them on one
   "<code>[f]()[..]</code> desc" line. Merge each adjacent pair into a single line
   (the signature routed through InlineFormula so it renders as <code>). *)
usageDescParts[TextData[xs_List]] := xs
usageDescParts[TextData[x_]] := {x}
usageDescParts[s_] := {s}
mergeUsageLines[cells_] := cells //.
    {a___, Cell[ui_, "UsageInputs", ___], Cell[ud_, "UsageDescription", ___], b___} :>
        {a, Cell[TextData[Flatten[{Cell[ui, "InlineFormula"], " ", usageDescParts[ud]}]], "UsageLine"], b}
blockFor["UsageLine", TextData[xs_List]] := tidy @ StringJoin[inlineMd /@ xs]

(* flatten every CellGroupData wrapper into the bare cell sequence; grouping carries
   no information the walker needs, and the FE's regrouping makes it unreliable. *)
flattenCellGroups[cells_List] := cells //. Cell[CellGroupData[inner_List, ___], ___] :> Splice[inner]
$headingLevels = <|"Title" -> 1, "Section" -> 2, "Subsection" -> 3, "Subsubsection" -> 4|>;
headingLevelOf[Cell[_, s_String, ___]] := Lookup[$headingLevels, s, Infinity]
headingLevelOf[_] := Infinity
(* the span a heading cell owns in a flat list: itself through everything up to the
   next heading of the same or shallower level. *)
sectionSpanEnd[cells_, i_] := Module[{lvl = headingLevelOf[cells[[i]]], j = i + 1},
    While[j <= Length[cells] && headingLevelOf[cells[[j]]] > lvl, j++]; j - 1]
normalizeResourceCells[cells0_List, flattenTags_] := Module[{cells = flattenCellGroups[cells0], out = {}, i = 1, cell},
    While[i <= Length[cells],
        cell = cells[[i]];
        Which[
            (* frontmatter carriers and unfilled template placeholders *)
            cellHasTagQ[cell, "Name"] || cellHasTagQ[cell, "Description"] || cellHasTagQ[cell, "MTNUnfilled"],
                i++,
            (* metadata section: drop the heading and everything it owns *)
            headingLevelOf[cell] < Infinity && AnyTrue[$resourceDropTags, cellHasTagQ[cell, #] &],
                i = sectionSpanEnd[cells, i] + 1,
            (* wrapper label: drop just the heading, keep its children *)
            AnyTrue[flattenTags, cellHasTagQ[cell, #] &],
                i++,
            True,
                AppendTo[out, cell]; i++
        ]
    ];
    out
]
(* Tests is the code-bearing survivor of the Source wrapper; promote it to a Section
   so "## Tests" maps back to the VerificationTests slot. Function promotes the whole
   body (its content is flat ## sections); the other families keep their own content
   sections at their native levels and only re-home Tests. *)
promoteTests[cells_] := cells /.
    Cell[c_, "Subsection", o___] /; cellHasTagQ[Cell[c, "Subsection", o], "VerificationTests"] :> Cell[c, "Section", o]
(* The Paclet template renders some slots under its own labels; rename the heading
   back to the markdown section name its slot is filled from ("Basic Description" /
   LongDescription <- "## Usage", "Details" <- "## Details & Options", "Headline
   Image" / HeroImage <- "## Hero Image"), so the recovered markdown rebuilds. *)
$pacletHeadingNames = {"LongDescription" -> "Usage", "Details" -> "Details & Options", "HeroImage" -> "Hero Image"};
renamePacletHeadings[cells_] := Map[
    Function[cell,
        If[headingLevelOf[cell] < Infinity,
            With[{new = SelectFirst[$pacletHeadingNames, cellHasTagQ[cell, First[#]] &, None]},
                If[new === None, cell, Cell[Last[new], cell[[2]]]]],
            cell]],
    cells]
prepResourceBody[cells_List, family_String] := Switch[family,
    "Function",
        mergeUsageLines[promoteHeadings /@
            normalizeResourceCells[cells, Join[$resourceCommonFlattenTags, $functionFlattenTags]]],
    "Paclet",
        promoteHeadings /@ renamePacletHeadings @
            normalizeResourceCells[cells, Join[$resourceCommonFlattenTags, $functionFlattenTags, $pacletFlattenTags]],
    _,
        promoteTests @ normalizeResourceCells[cells, $resourceCommonFlattenTags]
]

fmField[key_, val_] := If[StringTrim[val] === "", "", key <> ": " <> val <> "\n"]
fmList[key_, items_] := If[items === {}, "", key <> ": [" <> StringRiffle[items, ", "] <> "]\n"]
(* items that may contain commas or markdown links are quoted so the YAML-ish
   parser keeps each element whole *)
fmQuotedList[key_, items_] := If[items === {}, "",
    key <> ": [" <> StringRiffle[("\"" <> # <> "\"" &) /@ items, ", "] <> "]\n"]

(* Paclet-only fields, each read from its widget / text cell: the license id is the
   string following the "RadioButtonValue" marker in the License radio widget; the
   main guide is the unique ".nb" path in the Main Guide Page chooser. *)
resourceLicense[nb_] := Module[
    {strs = Cases[resourceSectionKidsAny[nb, {"LicensingInformation"}], _String, Infinity], i},
    i = FirstPosition[strs, "RadioButtonValue", Missing[], {1}];
    If[MissingQ[i] || First[i] + 1 > Length[strs], "", strs[[First[i] + 1]]]]
resourceMainGuide[nb_] := FirstCase[
    resourceSectionKidsAny[nb, {"MainGuidePage", "Main Guide Page"}],
    s_String /; StringEndsQ[s, ".nb"], "", Infinity]

(* children of the first subsection matching ANY of the tag aliases a family may use
   (one subsection can carry several of them, so match once, not per-tag). Works on
   the flattened cell list so it is immune to the FE's regrouping: the children are
   the heading's sectional span. *)
resourceSectionKidsAny[nb_, tags_List] := Module[
    {cells = flattenCellGroups[First[nb]], i},
    i = FirstPosition[cells,
        h_ /; headingLevelOf[h] < Infinity && AnyTrue[tags, cellHasTagQ[h, #] &],
        Missing[], {1}, Heads -> False];
    If[MissingQ[i], Return[{}]];
    i = First[i];
    cells[[i + 1 ;; sectionSpanEnd[cells, i]]]
]
(* the authored (non-placeholder) Item contents; an unfilled slot keeps a
   "DefaultContent"-tagged placeholder Item, which is not a real value. *)
resourceContentItems[nb_, tags_List] := Cases[resourceSectionKidsAny[nb, tags],
    cell : Cell[content_, "Item", ___] /; ! cellHasTagQ[cell, "DefaultContent"] :> content]
resourceSubsectionText[nb_, tags_List] := StringRiffle[
    cellPlain /@ Cases[resourceSectionKidsAny[nb, tags], Cell[c_, "Text", ___] :> c], ", "]
resourceFrontmatter[nb_] := Module[
    {rt = resourceTypeOf[nb], pacletQ, name, desc, contrib, kw, sa, rr, links, sources},
    If[! resourceDefNotebookQ[nb], Return[""]];
    pacletQ = rt === "Paclet";
    name    = taggedCellText[nb, "Name"];
    desc    = taggedCellText[nb, "Description"];
    contrib = resourceSubsectionText[nb, {"Contributed By", "ContributorInformation", "Author Names", "AuthorNames"}];
    kw      = cellPlain /@ resourceContentItems[nb, {"Keywords"}];
    (* SeeAlso: Function stores it as RelatedSymbol cells, the other families as a
       "See Also" / "Related Symbols" / "Related Documentation Pages" list. *)
    sa      = DeleteDuplicates @ Join[
        Cases[nb, Cell[c_, "RelatedSymbol", ___] :> cellPlain[c], Infinity],
        cellPlain /@ resourceContentItems[nb, {"See Also", "Related Symbols", "Related Documentation Pages"}]];
    rr      = cellPlain /@ resourceContentItems[nb, {"Related Resource Objects", "Related Demonstrations"}];
    sources = cellPlain /@ resourceContentItems[nb, {"Source/Reference Citation"}];
    links   = resourceLinkMd /@ resourceContentItems[nb, {"Links", "External Links"}];
    StringJoin[
        "---\n",
        "Template: ", templateForResourceType[rt], "\n",
        "ResourceType: ", rt, "\n",
        fmField["Name", name],
        If[pacletQ, StringJoin[
            fmField["Context", resourceSubsectionText[nb, {"PrimaryContext", "Primary Context"}]],
            (* a repository paclet's resource name IS the paclet name *)
            fmField["Paclet", name]], ""],
        fmField["Description", desc],
        fmField["ContributedBy", contrib],
        fmList["Keywords", kw],
        If[pacletQ, StringJoin[
            fmField["MainGuide", resourceMainGuide[nb]],
            fmField["License", resourceLicense[nb]],
            fmField["WolframVersion", resourceSubsectionText[nb, {"CompatibilityWolframLanguageVersionRequired", "Wolfram Language Version"}]],
            fmField["SourceControlURL", resourceSubsectionText[nb, {"SourceControlURL", "Source Control Repository"}]]], ""],
        fmQuotedList["Sources", sources],
        fmList["SeeAlso", sa],
        fmList["RelatedResources", rr],
        (* each Links item is already a markdown link; quote it so the YAML element
           is a string the forward parser unquotes *)
        fmQuotedList["Links", links],
        "---\n\n"
    ]
]

(* === Guide-page frontmatter recovery ===
   A guide built by MarkdownToNotebook carries its metadata in TaggingRules
   ("Metadata" -> {"title" -> Name, "context", "summary", "paclet", "uri",
   "keywords", "type" -> "Guide"}); the human Title is the GuideTitle cell, the
   RelatedGuides are the GuideMoreAbout links, and Links the GuideRelatedLinks. *)
docMetaOf[nb_] := FirstCase[
    Cases[nb, (TaggingRules -> v_) :> v, {1}],
    tr_List /; ! FreeQ[Keys[tr], "Metadata"] :> Association["Metadata" /. tr],
    <||>, {1}]
guideFrontmatter[nb_] := Module[{md = docMetaOf[nb], title, rg, links},
    If[Lookup[md, "type", ""] =!= "Guide", Return[""]];
    title = cellPlain @ FirstCase[nb, Cell[t_, "GuideTitle", ___] :> t, "", Infinity];
    rg = DeleteCases[
        Cases[nb, Cell[c_, "GuideMoreAbout", ___] :> FirstCase[{c}, s_String :> s, "", Infinity], Infinity],
        ""];
    links = resourceLinkMd /@ Cases[nb, Cell[c_, "GuideRelatedLinks", ___] :> c, Infinity];
    StringJoin[
        "---\n",
        "Template: Guide\n",
        fmField["Name", Lookup[md, "title", ""]],
        fmField["Title", title],
        fmField["Context", Lookup[md, "context", ""]],
        fmField["Paclet", Lookup[md, "paclet", ""]],
        fmField["URI", Lookup[md, "uri", ""]],
        fmField["Description", Lookup[md, "summary", ""]],
        fmList["Keywords", Lookup[md, "keywords", {}]],
        fmList["RelatedGuides", rg],
        fmQuotedList["Links", links],
        "---\n\n"
    ]
]

frontmatter[nb_, name_] := Module[{cat, paclet, ctx, uri, kw, sa, rg, res},
    res = guideFrontmatter[nb];
    If[res =!= "", Return[res]];
    res = resourceFrontmatter[nb];
    If[res =!= "", Return[res]];
    If[! hasObjectNameQ[nb], Return[""]];
    (* a MarkdownToNotebook-built page stashes the metadata in TaggingRules;
       the Categorization / Keywords cells are the fallback for hand-built pages *)
    With[{md = docMetaOf[nb]},
        cat = catList[nb];
        paclet = Lookup[md, "paclet", If[Length[cat] >= 2, cat[[2]], ""]];
        ctx = Lookup[md, "context", If[Length[cat] >= 3, cat[[3]], ""]];
        uri = Lookup[md, "uri", If[Length[cat] >= 4, cat[[4]], ""]];
        kw = Replace[Lookup[md, "keywords", {}], {} :> keywordList[nb]];
    ];
    (* SeeAlso chips are typed-link TemplateBoxes on a built page, ButtonBoxes on a
       hand-authored one *)
    sa = DeleteDuplicates @ Join[
        Cases[FirstCase[nb, Cell[td_, "SeeAlso", ___] :> td, TextData[{}], Infinity],
            TemplateBox[{Cell[TextData[n_String]], _String, ___}, _, ___] :> n, Infinity],
        linkNames[nb, "SeeAlso"]];
    rg = guideIds[nb, "MoreAbout"];
    StringJoin[
        "---\n",
        "Template: Symbol\n",
        "Name: ", name, "\n",
        "Context: ", ctx, "\n",
        "Paclet: ", paclet, "\n",
        "URI: ", uri, "\n",
        "Keywords: [", StringRiffle[kw, ", "], "]\n",
        "SeeAlso: [", StringRiffle[sa, ", "], "]\n",
        "RelatedGuides: [", StringRiffle[rg, ", "], "]\n",
        "---\n\n"
    ]
]

(* === post-process: drop empty heading-only sections ===
   A heading-only block is "## Title" on a single line. A block that bakes
   content after its heading (e.g. "## Usage\n\n<sig>...") contains a newline
   and is NOT heading-only, so dropEmptySections never mistakes it for an empty
   section. A heading is empty only if the next block is a heading of the same
   or higher level (a sibling / parent section), or end of document; a deeper
   following subsection is content. *)
headingQ[s_String] := StringMatchQ[s, ("#" ..) ~~ " " ~~ Except["\n"] ...]
headingLevel[s_String] := StringLength @ First @ StringCases[s, StartOfString ~~ h : ("#" ..) :> h]
dropEmptySections[blocks_List] := Module[{i, out = {}},
    Do[
        If[ headingQ[blocks[[i]]] &&
            (i == Length[blocks] ||
                (headingQ[blocks[[i + 1]]] && headingLevel[blocks[[i + 1]]] <= headingLevel[blocks[[i]]])),
            Null,
            AppendTo[out, blocks[[i]]]
        ],
        {i, Length[blocks]}
    ];
    out
]

(* consecutive single-item list blocks (each cell walks to its own "- item")
   join into ONE tight list, matching how the lists are authored; blocks are
   riffled with blank lines, which would otherwise render a loose list. A block
   that bakes its section heading onto the first item ("## Details & Options
   <blank> - first note", the Notes handler's shape) is split first so the run
   merges whole; an example's "<!-- => value -->" annotation re-attaches
   directly under its code fence, where the source style puts it. *)
listItemBlockQ[s_String] := StringMatchQ[s, ("- " | "1. ") ~~ __] && StringFreeQ[s, "\n\n"]
splitHeadingItem[s_String] := Replace[
    StringCases[s, StartOfString ~~ h : (("#" ..) ~~ " " ~~ Except["\n"] ..) ~~ "\n\n" ~~ r__ ~~ EndOfString :> {h, r}, 1],
    {{{h_, r_}} /; listItemBlockQ[r] :> Splice[{h, r}], _ :> s}]
mergeListRuns[blocks0_List] := Module[{blocks = Flatten[splitHeadingItem /@ blocks0]},
    blocks = Map[
        If[MatchQ[#, {__String}] && listItemBlockQ[First[#]], StringRiffle[#, "\n"], Splice[#]] &,
        Split[blocks, listItemBlockQ[#1] && listItemBlockQ[#2] &]
    ];
    (* hug the output annotation to its fence *)
    blocks //. {a___, code_String /; StringEndsQ[code, "```"], out_String /; StringStartsQ[out, "<!-- => "], b___} :>
        {a, code <> "\n" <> out, b}
]

(* === core: a Notebook -> faithful literate markdown ===
   Doc-page templates (recognised by the presence of Categorization cells)
   carry a fixed sequence of placeholder sections; their unused sections show
   up as bare `## Title` blocks with no following content, which we drop.
   For an arbitrary notebook a trailing heading IS authored content, so the
   drop pass only runs when a doc-page frontmatter is being emitted. *)
(* On a doc page, fold an example's oversized result into a "#| screenshot: true"
   mark on its input cell and drop the giant Output, so it round-trips as a rendered
   image rather than a wall-of-text "<!-- => v -->" comment. Threshold is the
   OutputCommentLimit option; graphic outputs are left for the code to regenerate.
   Operates on the flat cell list (groups already flattened): each Output belongs to
   the nearest preceding Input. *)
outputCommentTooLongQ[boxes_] := FreeQ[boxes, GraphicsBox | Graphics3DBox | RasterBox] &&
    StringLength[tidy @ codeText[boxes]] > $outputCommentLimit
withScreenshotTag[Cell[c_, s_, o___]] := If[FreeQ[{o}, CellTags -> _],
    Cell[c, s, o, CellTags -> {"MTNScreenshot"}],
    Replace[Cell[c, s, o], (CellTags -> t_) :> (CellTags -> DeleteDuplicates @ Append[Flatten[{t}], "MTNScreenshot"]), {1}]]
applyOutputScreenshots[cells_List] := Module[{drop = {}, marks = {}, lastIn = 0},
    Do[
        Which[
            MatchQ[cells[[i]], Cell[_, "Input" | "Code" | "ExampleInput", ___]],
                lastIn = i,
            MatchQ[cells[[i]], Cell[oc_BoxData, "Output", ___] /; outputCommentTooLongQ[oc]],
                AppendTo[drop, i]; If[lastIn > 0, AppendTo[marks, lastIn]]
        ],
        {i, Length[cells]}];
    marks = DeleteDuplicates[marks];
    Delete[
        MapIndexed[If[MemberQ[marks, First[#2]], withScreenshotTag[#1], #1] &, cells],
        List /@ drop]
]

(* When a "PackageLink" / "RefLink" / "RefLinkPlain" template has no display
   definition in the session, the front end serializes the whole TemplateBox into
   its literal box InputForm - RowBox[{ButtonBox["TemplateBox",..], "[", <the
   template's args as boxes>, "]"}] - which otherwise dumps into the markdown as a
   wall of box language. Recover the intended link box: its symbol name is the first
   bare-symbol quoted token inside, and the target is re-inferred, so the normal
   link rules take over. *)
demangleName[inner_] := FirstCase[
    StringTrim[#, "\""] & /@ Cases[inner, s_String /; StringMatchQ[s, "\"" ~~ Except["\""] ... ~~ "\""], Infinity],
    n_String /; StringMatchQ[n, LetterCharacter ~~ WordCharacter ...], "", 1]
demangleLinkBoxes[expr_] := expr //.
    RowBox[{ButtonBox["TemplateBox", ___], "[", inner_, "]"}] /;
        (! FreeQ[inner, s_String /; StringContainsQ[s, "PackageLink" | "RefLink"]] && demangleName[inner] =!= "") :>
        With[{name = demangleName[inner]},
            TemplateBox[{Cell[TextData[name]], "paclet:ref/" <> name}, "RefLinkPlain", BaseStyle -> "InlineFormula"]]

markdownOfNb[nb0 : Notebook[_List, ___], opts : OptionsPattern[NotebookToMarkdown]] := Block[
    {nb = demangleLinkBoxes[nb0], name, blocks, fm, cells, $detailsHeadingDone = False,
     $metadataCarrier    = OptionValue[NotebookToMarkdown, {opts}, "Metadata"],
     $preserveOutputs    = TrueQ @ OptionValue[NotebookToMarkdown, {opts}, "PreserveOutputs"],
     $outputInlineLimit  = OptionValue[NotebookToMarkdown, {opts}, "OutputInlineLimit"],
     $outputCommentLimit = OptionValue[NotebookToMarkdown, {opts}, "OutputCommentLimit"],
     $docPageQ           = docNotebookQ[nb0]},
    name = cellPlain @ FirstCase[nb, Cell[t_, "ObjectName", ___] :> t, "", Infinity];
    cells = If[resourceDefNotebookQ[nb], prepResourceBody[First[nb], resourceTypeOf[nb]], First[nb]];
    (* the walker is grouping-agnostic, so doc pages run on the flat cell list; the
       screenshot pre-pass relies on it (Output follows its Input) *)
    If[$docPageQ, cells = applyOutputScreenshots[flattenCellGroups[cells]]];
    blocks = walkCells[cells];
    fm = frontmatter[nb, name];
    If[fm =!= "", blocks = mergeListRuns @ dropEmptySections[blocks]];
    fm <> StringRiffle[blocks, "\n\n"] <> "\n"
]

(* === public entry ===
   Wrapping each entry in UsingFrontEnd would be friendlier for headless
   callers (the FE link feInput needs gets spawned automatically), but it
   trips the Function Repository scrape - the scraper inspects the
   EntrySymbol's right-hand side and stumbles when the outermost head is
   `UsingFrontEnd` rather than the function's own code. Keep the public
   entries plain; the feInput call site itself catches a missing FE and
   falls back to boxToCode, so a no-FE session degrades gracefully without
   needing the wrap here. *)
NotebookToMarkdown[nb : Notebook[_List, ___], opts : OptionsPattern[]] := markdownOfNb[nb, opts]
NotebookToMarkdown[nbo_NotebookObject, opts : OptionsPattern[]] := markdownOfNb[NotebookGet[nbo], opts]
NotebookToMarkdown[file_String /; FileExistsQ[file] && StringEndsQ[ToLowerCase[file], ".nb"], opts : OptionsPattern[]] :=
    markdownOfNb[Get[file], opts]
NotebookToMarkdown[source_, "String", opts : OptionsPattern[]] := NotebookToMarkdown[source, opts]
(* The ".md" target entry also fixes the sidecar directory for ".wxf" outputs
   (siblings of the .md, named "<base>-out-N.wxf"); the nested conversion sees it
   via dynamic scope. In-memory conversions leave $n2mAssetDir = None, so output
   preservation there always inlines the boxes (no file is written). *)
NotebookToMarkdown[source_, target_String /; StringEndsQ[ToLowerCase[target], ".md"], opts : OptionsPattern[]] := Block[
    {$n2mAssetDir = Replace[DirectoryName[target], "" -> Directory[]],
     $n2mAssetBase = FileBaseName[target], $n2mOutCounter = 0, $n2mFigCounter = 0},
    With[{md = NotebookToMarkdown[source, opts]},
        Export[target, md, "Text"];
        target
    ]
]
