---
Template: ServiceConnection
Name: Lorem
Context: WolframInstitute`DocPageExamples`
Paclet: WolframInstitute/DocPageExamples
URI: WolframInstitute/DocPageExamples/ref/service/Lorem
Description: Generate placeholder text with the Lorem service
Keywords: [lorem ipsum, placeholder text, filler text, mockup, text generation]
SeeAlso: [ServiceConnect, ServiceExecute, ServiceObject, ServiceDisconnect]
---

# Lorem

Connect to the Lorem service to generate reproducible placeholder text - sentences and word lists - for mocking up documents and interfaces.

## Connecting & Authenticating

- `ServiceConnect["Lorem"]` creates a connection to the Lorem service. If a previous connection is available, it will be used.
- The Lorem service runs entirely inside the local Wolfram Language session; no account, API key, or network access is required, and no credential dialog appears.
- Loading the WolframInstitute/DocPageExamples paclet registers the service connection.

## Requests

- `ServiceExecute["Lorem", "request", params]` sends a request to the Lorem service.
- All requests accept the parameter `"Seed"`; giving the same integer seed always returns the same text. With the default `"Seed" -> Automatic`, output draws from the current random state.

### "Sentence"

- Returns a single placeholder sentence as a string, capitalized and ending with a period.

|   |   |   |
| --- | --- | --- |
| "Words" | 8 | number of words in the sentence |
| "Seed" | Automatic | integer seed for reproducible output |

### "WordList"

- Returns a list of lowercase placeholder words.

|   |   |   |
| --- | --- | --- |
| "Words" | 12 | number of words in the list |
| "Seed" | Automatic | integer seed for reproducible output |

## Examples

### Basic Examples

Loading the paclet registers the Lorem service connection:

```wl
Needs["WolframInstitute`DocPageExamples`"]
```

Create a connection to the Lorem service; the service is local, so no credentials are needed:

```wl
lorem = ServiceConnect["Lorem"]
```

Request a reproducible five-word sentence:

```wl
ServiceExecute[lorem, "Sentence", {"Words" -> 5, "Seed" -> 42}]
```

Request a list of placeholder words:

```wl
ServiceExecute[lorem, "WordList", {"Words" -> 4, "Seed" -> 7}]
```

The same seed always produces the same text:

```wl
SameQ @@ Table[ServiceExecute[lorem, "Sentence", {"Words" -> 5, "Seed" -> 42}], 2]
```
