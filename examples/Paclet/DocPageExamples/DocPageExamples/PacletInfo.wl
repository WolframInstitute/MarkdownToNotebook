(* ::Package:: *)

PacletObject[<|
    "Name" -> "WolframInstitute/DocPageExamples",
    "Description" -> "A minimal real paclet backing one documentation page of every reference subtype: a Format, a ServiceConnection, a Device, an Interpreter, an Entity, a Character, a Message, a Program, a Workflow, and a WorkflowGuide page",
    "Creator" -> "Nikolay Murzin, Claude (Anthropic)",
    "PublisherID" -> "WolframInstitute",
    "License" -> "MIT",
    "Version" -> "1.0.0",
    "WolframVersion" -> "14.3+",
    "PrimaryContext" -> "WolframInstitute`DocPageExamples`",
    "Extensions" -> {
        {
            "Kernel",
            "Root" -> "Kernel",
            "Context" -> {"WolframInstitute`DocPageExamples`"},
            "Symbols" -> {
                "WolframInstitute`DocPageExamples`MazeGenerate",
                "WolframInstitute`DocPageExamples`MazeParse"
            }
        },
        {
            "ServiceConnection",
            "Name" -> "Lorem",
            "Context" -> {"WolframInstitute`DocPageExamples`"}
        },
        {
            "Asset",
            "Root" -> "Scripts",
            "Assets" -> {{"mazegen", "mazegen.wls"}}
        },
        {
            "Documentation",
            "Language" -> "English"
        }
    }
|>]
