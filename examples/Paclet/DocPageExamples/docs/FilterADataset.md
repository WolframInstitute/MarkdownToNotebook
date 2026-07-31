---
Template: Workflow
Name: FilterADataset
Title: Filter a Dataset
Context: WolframInstitute`DocPageExamples`
Paclet: WolframInstitute/DocPageExamples
URI: WolframInstitute/DocPageExamples/workflow/FilterADataset
Description: Pick out the rows of a Dataset that satisfy a condition, order them, and save the result to a file.
Keywords: [dataset, filter, select, sort, export, csv]
RelatedFunctions: [Dataset, Select, SortBy, Export]
SeeAlso: [ImportData]
---

# Filter a Dataset

A [Dataset]() behaves like a queryable table: applying a function such as
[Select]() or [SortBy]() inside the query brackets transforms the rows while
keeping the result a `Dataset`. This workflow builds a small dataset, keeps only
the rows that match a condition, orders them, and writes the result to a CSV
file.

### Build a dataset

Make a dataset from a list of associations; each association is one row, and
its keys become the column names:

```wl
ds = Dataset[{
    <|"Name" -> "Ada", "Subject" -> "Computing", "Score" -> 91|>,
    <|"Name" -> "Boole", "Subject" -> "Logic", "Score" -> 78|>,
    <|"Name" -> "Curie", "Subject" -> "Physics", "Score" -> 96|>,
    <|"Name" -> "Darwin", "Subject" -> "Biology", "Score" -> 64|>,
    <|"Name" -> "Euler", "Subject" -> "Analysis", "Score" -> 99|>,
    <|"Name" -> "Faraday", "Subject" -> "Physics", "Score" -> 82|>
}]
```

### Select the rows you want

Apply [Select]() inside the query brackets; the slot `#Score` refers to the
`"Score"` entry of each row:

```wl
filtered = ds[Select[#Score >= 80 &]]
```

> The condition is applied per row.

### Sort the result

Order the surviving rows with [SortBy](); here the rows are arranged by
ascending score:

```wl
sorted = filtered[SortBy[#Score &]]
```

### Export the result

Write the sorted dataset to a CSV file in the temporary directory; [Export]()
returns the path of the file it created:

```wl
file = Export[FileNameJoin[{$TemporaryDirectory, "filtered.csv"}], sorted]
```

Read the file back to confirm the contents, including the header row that
`Export` generated from the column names:

```wl
FilePrint[file]
```
