---
Template: NotebookTemplate
Name: Wolfram Model Report
Slots:
  Rule: {{x, y}, {x, z}} -> {{x, z}, {x, w}, {y, w}, {z, w}}
  InitialCondition: {{0, 0}, {0, 0}}
  EvolutionSteps: 10
  ShownSteps: 3
---

<!-- #| behavior: ExcludeCell -->
**Authoring note.** This cell and the next are dropped from every generated report. Every slot has a default from the frontmatter's `Slots:` mapping, so the toolbar's *Generate* fills the template as is; the call below overrides any of them.

```wl
#| behavior: ExcludeCell
GenerateDocument["WolframModelReport.nb", <|"Rule" -> rule, "InitialCondition" -> init, "EvolutionSteps" -> 10|>]
```

# Wolfram Model Report

Evolution of the rule `TemplateSlot["Rule"]` from the initial condition `TemplateSlot["InitialCondition"]`, generated on `TemplateExpression[DateString["ISODate"]]`.

## Basic Evolution

The first few generations:

```wl
ResourceFunction["HypergraphPlot"] /@ ResourceFunction["WolframModel"][TemplateSlot["Rule"], TemplateSlot["InitialCondition"], TemplateSlot["ShownSteps"], "StatesList"]
```

The evolution object for `TemplateSlot["EvolutionSteps"]` generations:

```wl
obj = ResourceFunction["WolframModel"][TemplateSlot["Rule"], TemplateSlot["InitialCondition"], TemplateSlot["EvolutionSteps"]]
```

Vertex and edge counts per generation:

```wl
{obj["VertexCountList"], obj["EdgeCountList"]}
```

The final state:

```wl
ResourceFunction["HypergraphPlot"][obj["FinalState"]]
```

## Causal Graph

```wl
obj["LayeredCausalGraph"]
```

Causal graph distance matrix:

```wl
MatrixPlot[GraphDistanceMatrix[obj["CausalGraph"]]]
```

## Final State Properties

Vertex degree distribution:

```wl
Histogram[Values[Counts[Catenate[Union /@ obj["FinalState"]]]]]
```

Distribution of graph distances in the final state:

```wl
Histogram[Flatten[GraphDistanceMatrix[UndirectedGraph[ResourceFunction["HypergraphToGraph"][obj["FinalState"]]]]]]
```

## Multiway Evolution

The first three generations of the multiway system:

```wl
ResourceFunction["MultiwaySystem"]["WolframModel" -> TemplateSlot["Rule"], {TemplateSlot["InitialCondition"]}, 3, "StatesGraph"]
```
