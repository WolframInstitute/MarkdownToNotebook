---
Template: Guide
Name: DocPageExamples
Title: Documentation Page Examples
Context: WolframInstitute`DocPageExamples`
Paclet: WolframInstitute/DocPageExamples
URI: WolframInstitute/DocPageExamples/guide/DocPageExamples
Description: One markdown-authored documentation page of every reference page type, each backed by real registered code
Keywords: [documentation, page types, format, service connection, device, interpreter, entity, character, message, program, workflow]
RelatedTutorials: []
Links: ["[MarkdownToNotebook](https://github.com/WolframInstitute/MarkdownToNotebook)"]
---

# Documentation Page Examples

## Abstract

The Wolfram documentation system has many reference page types beyond symbol,
guide, and tech note pages. This paclet carries one page of each, authored in
plain markdown and built with `MarkdownToNotebook`. Every page is backed by
code the paclet actually registers on load, so each example evaluates for real
rather than illustrating a hypothetical.

## Functions

### Symbols

- MazeGenerate - generate a random perfect maze as a character matrix in the MAZE format
- MazeParse - parse MAZE-format lines into a character matrix, padding ragged lines with walls

### Reference Pages

- [MAZE](paclet:WolframInstitute/DocPageExamples/ref/format/MAZE) - a *format* page: the registered `.maze` import and export converters
- [Lorem](paclet:WolframInstitute/DocPageExamples/ref/service/Lorem) - a *service connection* page: a placeholder-text service that runs locally
- [RandomSignal](paclet:WolframInstitute/DocPageExamples/ref/device/RandomSignal) - a *device* page: a simulated noise source registered with the device framework
- [Integer](paclet:WolframInstitute/DocPageExamples/ref/interpreter/Integer) - an *interpreter* page: the built-in integer interpreter type
- [WallpaperGroup](paclet:WolframInstitute/DocPageExamples/ref/entity/WallpaperGroup) - an *entity* page: an in-kernel entity store of plane symmetry groups
- [CirclePlus](paclet:WolframInstitute/DocPageExamples/ref/character/CirclePlus) - a *character* page: the named character and its aliases
- [MazeParse::ragged](paclet:WolframInstitute/DocPageExamples/ref/message/MazeParse/ragged) - a *message* page: the warning `MazeParse` issues on uneven input
- [mazegen](paclet:WolframInstitute/DocPageExamples/ref/program/mazegen) - a *program* page: the command-line maze generator the paclet ships

### Workflows

- [Filter a Dataset](paclet:WolframInstitute/DocPageExamples/workflow/FilterADataset) - a *workflow* page: numbered steps that each evaluate
- [Data Wrangling](paclet:WolframInstitute/DocPageExamples/workflowguide/DataWrangling) - a *workflow guide* page: a curated index of workflows
