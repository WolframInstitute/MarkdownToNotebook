---
Template: Entity
Name: WallpaperGroup
Context: WolframInstitute`DocPageExamples`
Paclet: WolframInstitute/DocPageExamples
URI: WolframInstitute/DocPageExamples/ref/entity/WallpaperGroup
Description: Wallpaper groups, the 17 plane crystallographic symmetry groups.
Keywords: [wallpaper group, plane symmetry, crystallography, lattice, point group]
SeeAlso: [Entity, EntityStore, EntityValue, EntityClass, EntityList]
---

# WallpaperGroup

"WallpaperGroup" entities represent the plane crystallographic groups: the symmetry groups of two-dimensional periodic patterns. There are exactly 17 such groups, and they are conventionally named by their IUC short symbols such as "p1", "pm" and "p4m".

## Sample Entities

- `p1` - the translation-only group, on the oblique lattice
- `p2` - twofold rotations only, on the oblique lattice
- `pm` - a single family of mirror lines, on the rectangular lattice
- `p4` - fourfold rotations without reflections, on the square lattice
- `p4m` - the full symmetry group of the square grid
- `p6m` - the full symmetry group of the hexagonal grid

## Properties

|   |   |
| --- | --- |
| `"Label"` | short human-readable name of the group |
| `"LatticeType"` | lattice class supporting the group ("Oblique", "Rectangular", "Square", "Hexagonal", ...) |
| `"PointGroupOrder"` | order of the point group, the quotient of the group by its translation subgroup |

## Details

- Entities are canonically named by IUC short symbol strings such as `"p1"` and `"p4m"`; canonical names are case sensitive.
- All property values are literal strings or integers; no property takes qualifiers or date specifications.
- `"PointGroupOrder"` ranges from 1 (for `p1`) to 12 (for `p6m`) across the full type.
- The full entity type covers all 17 wallpaper groups; the store registered by the WolframInstitute/DocPageExamples paclet includes the 6 representative groups `p1`, `p2`, `pm`, `p4`, `p4m` and `p6m`.
- Implicit entity classes are formed by property restriction, as in `EntityClass["WallpaperGroup", "LatticeType" -> "Square"]`.

## Examples

### Basic Examples

Loading the paclet registers the "WallpaperGroup" entity type from an in-kernel [EntityStore]():

```wl
Needs["WolframInstitute`DocPageExamples`"]
```

Look up a property of a single group:

```wl
Entity["WallpaperGroup", "p4m"]["PointGroupOrder"]
```

List the registered entities:

```wl
EntityList["WallpaperGroup"]
```

Restrict to an implicit entity class by property value:

```wl
EntityList[EntityClass["WallpaperGroup", "LatticeType" -> "Square"]]
```

Tabulate all properties across the registered groups:

```wl
EntityValue["WallpaperGroup", {"Label", "LatticeType", "PointGroupOrder"}, "Dataset"]
```
