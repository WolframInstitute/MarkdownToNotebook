# Authoring examples: one demonstration per cell

Every Wolfram resource type (`FunctionResource`, `Symbol`, `Guide`,
`TechNote`, `Paclet`, `Example`, `Data`, `Prompt`, `Demonstration`) shares
one example-authoring rule: **one demonstration per `wl` cell**, lead each
with a one-sentence caption ending in `:`, separate siblings with a `---`
delimiter, and never bundle several distinct ideas into one cell.

This page is the single source of truth that every per-template skill
points at. If a rule below conflicts with anything else in the docs, this
page wins.

## The rule

A reference page (or Examples section of a resource) is a sequence of
*demonstrations*. Each demonstration is:

1. **One short prose caption** - a complete sentence ending with `:`,
   written as the markdown paragraph *immediately* before the `wl` cell.
   The converter promotes it to the `ExampleText` / `CodeText` cell the
   docs style expects.
2. **One `wl` cell** that evaluates to the result the caption is about.
3. *(Optional)* a `<!-- => expected -->` HTML comment right after the
   cell, documenting the expected output (stripped from the published
   page but useful in code review).

Sibling demonstrations are separated by a `---` line (a markdown
thematic break). The converter turns it into an `ExampleDelimiter` cell
and resets the `In[]` / `Out[]` counter, so each demonstration reads as
its own captioned, independent computation.

## Good

```
## Basic Examples

The 7-adic valuation of $98 = 2 \cdot 7^2$:

\```wl
PAdicValuation[98, 7]
\```

<!-- => 2 -->

---

The 7-adic absolute value of the same integer:

\```wl
PAdicNorm[98, 7]
\```

<!-- => 1/49 -->
```

Two captioned demonstrations, each one computation, separated by `---`.
Each renders independently as `In[1]` / `Out[1]`.

## Bad: bundling several things into one cell

```
## Basic Examples

The 7-adic valuation and norm of $98 = 2 \cdot 7^2$:

\```wl
{PAdicValuation[98, 7], PAdicNorm[98, 7]}
\```
```

The output is one list, one `Out[1]`; the reader has to mentally pair
the list elements with the underlying operations. The give-away is the
caption's "X *and* Y" - that "and" joins two separate ideas. Split them:

```
The 7-adic valuation of $98 = 2 \cdot 7^2$:

\```wl
PAdicValuation[98, 7]
\```

---

The 7-adic absolute value of the same integer:

\```wl
PAdicNorm[98, 7]
\```
```

**Nuance**: a list IS fine when the list *is* the demonstration -
comparing related quantities side-by-side, sweeping a parameter, or
asserting an identity. The test is whether the list shape carries
information the reader needs to *see*:

```
(* Good - the list IS the demonstration ("sweep across primes") *)
\```wl
{PAdicValuation[2520, 2], PAdicValuation[2520, 3], PAdicValuation[2520, 5], PAdicValuation[2520, 7]}
\```

(* Good - the list IS the demonstration (LHS vs RHS of an identity) *)
\```wl
{PAdicValuation[7 + 49, 7], Min[PAdicValuation[7, 7], PAdicValuation[49, 7]]}
\```
```

The rule is "one *demonstration* per cell", not "one *number* per
cell".

## Bad: multiple statements stacked in one cell

```
\```wl
PAdicValuation[98, 7]
PAdicNorm[98, 7]
PAdicDigits[100, 7, 4]
\```
```

Three separate computations crammed into one `Input` cell. The
notebook shows three `Out[]`s under one `In[]`, the reader cannot
copy any one of them into their own session, and the scraper has no
caption to attach to anything. Split each into its own captioned
example with a `---` between.

## Bad: no caption

```
\```wl
PAdicValuation[98, 7]
\```
```

A cell with no preceding caption still becomes an Input/Output pair,
but the rendered docs page has nothing introducing it. The submission
Check flags this with `ExampleTextLastCharacter` (caption must end with
`:`) or `FoundUnformattedCode` (the cell looked unframed).

## What the delimiter does

A `---` line (a markdown thematic break) on its own:

- becomes an `ExampleDelimiter` cell in the notebook (the dashed
  separator the FE shows between subsections of an example group),
- resets the `In[]` / `Out[]` counter to 1 for the next demonstration,
- visually marks the boundary so the reader sees each example as a
  unit.

A `### Heading` inside an example section is a heavier separator -
it becomes an `ExampleSubsection` (one per option / sub-topic, as on
real reference pages in the wild). Use `###` when you want a named
sub-section (`### Common Options`, `### Edge cases`); use `---` for
unnamed sibling demonstrations.

## Where the rule applies

| Section | Where this rule binds |
|---|---|
| `## Basic Examples` | always |
| `## Scope`, `## Options`, `## Applications`, `## Properties and Relations`, `## Possible Issues`, `## Neat Examples` | always |
| `## Generalizations & Extensions`, `## Requirements` | always |
| `## Hero Image` (Paclet) | the *one* hero cell - no siblings, the rule is just "one demonstration" |
| `## Manipulate`, `## Snapshots` (Demonstration) | one cell per Manipulate / per snapshot |
| `## Tests` (FunctionResource) | one `VerificationTest[…]` per cell - the `VerificationTests` slot expects that |
| `## Chat Examples`, `## Basic Examples` (Prompt) | one chat or one programmatic call per cell |

The Guide page's `## Functions` listing is the only exception: each
list item there is a `Symbol description` shorthand, not a runnable
example, and so does *not* take a `wl` cell.

## What the submission Check looks for

- `ExampleTextLastCharacter` - the caption preceding a `wl` cell must
  end in `:`. The converter promotes a `:`-terminated one-line paragraph
  to `ExampleText` / `CodeText` automatically; multi-line paragraphs and
  prose that does not end in `:` stay as ordinary `Text`.
- `FoundUnformattedCode` - a bare WL symbol in prose without `[Symbol]()`
  or backticks. Wrap stray symbol names.
- `LargeCellBounds` / `CellHeight` - the rasterised output of a cell
  exceeds the size budget. Crop with `#| tear: h` or shrink the source.
- `RasterizeDynamics` - a Manipulate / Dynamic snapshot's output is
  evaluated at scrape time; mark it with `SaveDefinitions -> True` (and
  for Demonstrations, use the parameterised-helper snapshot pattern from
  [the demonstration skill](../skills/wolfram-demonstration/SKILL.md)).
