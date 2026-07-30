---
Template: Interpreter
Name: Integer
Paclet: WolframInstitute/DocPageExamples
URI: WolframInstitute/DocPageExamples/ref/interpreter/Integer
Description: An integer of any size, in decimal notation.
Keywords: [integer, number, parsing, form field, validation]
SeeAlso: [Interpreter, Restricted, SemanticInterpretation, FormFunction]
---

# Integer

An integer of any size, in decimal notation.

## Allowed Forms

| `"42"` | plain decimal digits |
|---|---|
| `"-7"` | an optionally signed integer |
| `"12345678901234567890"` | an integer of arbitrary size |

## Restriction Specifications

| `Restricted["Integer", max]` | an integer between 0 and max |
|---|---|
| `Restricted["Integer", {min, max}]` | an integer between min and max |
| `Restricted["Integer", {min, max, step}]` | an integer from min to max in steps of step |

## Interpretation

- `Interpreter["Integer"]` yields an expression with head [Integer]().
- The result is always exact; no precision is lost, however many digits are supplied.
- Strings containing decimal points, exponents, or nondecimal characters are not accepted; a [Failure]() object is returned instead.
- "Integer" is a built-in interpreter type; it is interpreted locally in the Wolfram Language kernel, with no cloud or network access involved.

## Examples

### Basic Examples

Interpret a string as an integer:

```wl
Interpreter["Integer"]["42"]
```

A leading sign is allowed:

```wl
Interpreter["Integer"]["-7"]
```

Integers of any size are accepted:

```wl
Interpreter["Integer"]["12345678901234567890"]
```

---

Strings that are not integers in decimal notation yield a [Failure]() object:

```wl
Interpreter["Integer"]["3.14"]
```

### Scope

An interpreter applied to a list interprets each element:

```wl
Interpreter["Integer"][{"1", "-2", "30"}]
```

The result is a machine-checkable [Integer]() expression:

```wl
Interpreter["Integer"]["99"] // Head
```

---

Use [Restricted]() to accept only integers in a given range:

```wl
Interpreter[Restricted["Integer", {1, 100}]]["42"]
```

Out-of-range input fails with a [Failure]() object:

```wl
Interpreter[Restricted["Integer", {1, 100}]]["365"]
```
