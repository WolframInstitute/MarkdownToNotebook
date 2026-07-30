---
Template: Character
Name: CirclePlus
Character: "⊕"
Paclet: WolframInstitute/DocPageExamples
URI: WolframInstitute/DocPageExamples/ref/character/CirclePlus
Description: Named character U+2295, the circled plus infix operator
Keywords: [circled plus, direct sum, infix operator, named character]
SeeAlso: [CircleTimes, CircleMinus]
---

# CirclePlus

- Unicode: 2295.
- Alias: Esc c+ Esc.
- Infix operator with built-in evaluation rules.
- `x ⊕ y` is by default interpreted as `CirclePlus[x, y]`.
- Not the same as `\[OPlus]`, which renders similarly but is a letter-like form with no operator interpretation.

## Examples

### Basic Examples

Enter the operator with the alias Esc c+ Esc, or as the long name `\[CirclePlus]`; the input stays symbolic and displays in operator form:

```wl
x \[CirclePlus] y
```

The full form of the operator is [CirclePlus]():

```wl
FullForm[x \[CirclePlus] y]
```

The operator chains as a single n-ary expression:

```wl
FullForm[a \[CirclePlus] b \[CirclePlus] c]
```
