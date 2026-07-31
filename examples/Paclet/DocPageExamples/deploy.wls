#!/usr/bin/env wolframscript
(* Deploy the DocPageExamples paclet resource publicly to the Wolfram Cloud -
   the scripted equivalent of the definition notebook's "Deploy -> Publicly in
   the cloud" button, so the resource page (and the documentation it bundles)
   can be viewed online without submitting to the Paclet Repository.

   Run build.wls first: this deploys DocPageExamples/ResourceDefinition.nb and
   the built Documentation/ beside it.

       wl -f deploy.wls            (or:  wolframscript -f deploy.wls)

   Prints the public resource-page URL. *)

rootDir = DirectoryName[$InputFileName]
pacletDir = FileNameJoin[{rootDir, "DocPageExamples"}]
defNb = FileNameJoin[{pacletDir, "ResourceDefinition.nb"}]
pacletName = "WolframInstitute/DocPageExamples"

If[ ! FileExistsQ[defNb],
    Print["FATAL: ", defNb, " does not exist - run build.wls first."];
    Exit[1]
]

PacletDirectoryLoad[pacletDir]
Needs["DefinitionNotebookClient`"]
Needs["PacletResource`DefinitionNotebook`"]
Needs["ResourceSystemClient`"]
(* PacletTools MUST be loaded before the scrape: it computes the relative paths
   of the Documentation extension via PacletTools`PacletExtensionFiles, and if
   that context is not loaded the call stays unevaluated (FileNameSplit::fstr)
   and a $Failed lands in the scraped file listing. *)
Needs["PacletTools`"]

If[ ! TrueQ[$CloudConnected], CloudConnect[] ]
If[ ! TrueQ[$CloudConnected],
    Print["FATAL: not cloud connected - CloudConnect[] with your Wolfram ID first."];
    Exit[1]
]
Print["deploying ", pacletName, " as ", $WolframID]

(* Scrape + deploy exactly where the notebook's Deploy button computes:
   <account>/DeployedResources/Paclet/<Publisher>/<Name>, with the slash kept
   as a path separator - that location is what makes the resource shingle and
   the bundled documentation pages serve and resolve anonymously. A freshly
   opened definition notebook resolves its paclet only after PacletObject and
   ScrapePacletDirectory have each run once, so warm both before scraping. *)
result = UsingFrontEnd @ Block[{nbo, res, co},
    nbo = NotebookOpen[defNb, Visible -> False];
    PacletObject[pacletName];
    Quiet[PacletResource`DefinitionNotebook`ScrapePacletDirectory[nbo]];
    (* "FailureCondition" -> None: a markdown-built definition notebook always
       raises the Error-level "NoPacletInfoFileCell" hint, because it carries no
       interactive file-manager cell listing PacletInfo.wl. The paclet is instead
       attached through the PacletDirectory the scrape resolves from this
       notebook's own location, so the resource is complete without it. *)
    res = DefinitionNotebookClient`ScrapeResource["Paclet", nbo,
        Interactive -> False, "FailureCondition" -> None];
    NotebookClose[nbo];
    If[ ! MatchQ[res, _ResourceObject],
        Print["FATAL: scraping the resource failed: ", ToString[Short[res, 8], InputForm]];
        Exit[1]
    ];
    ResourceSystemClient`Private`loadDeployResourceShingle[];
    co = Replace[
        DeployedResourceShingle`Private`defaultCloudObjectLocation["Paclet", res["Name"]],
        Except[_CloudObject] :> CloudObject[]
    ];
    CloudDeploy[res, co, Permissions -> "Public"]
]

Print["=== RESULT ==="]
Print["head : ", Head[result]]
If[ MatchQ[result, _CloudObject],
    Print["deployed: ", First[result]],
    Print["value: ", ToString[Short[result, 20], InputForm]];
    Exit[1]
]
