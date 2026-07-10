# Markdown ↔ Wolfram Notebook (VS Code)

Adds an **Open as Wolfram Notebook** button next to the Markdown *Open Preview*
button in the editor title bar (and on the right-click menu of any `.md` file).

Clicking it:

1. runs [`MarkdownToNotebook`](../MarkdownToNotebook.wl) on the current `.md`,
2. writes a temporary `.nb` carrying a docked **↓ Save to Markdown** toolbar, and
3. opens that notebook in the Wolfram desktop front end.

Editing the notebook and pressing **Save to Markdown** runs
[`NotebookToMarkdown`](../NotebookToMarkdown.wl) straight back onto the original
`.md`, so it is a live, two-way editing surface — VS Code reloads the `.md` the
moment the notebook writes it.

## Requirements

- A Wolfram kernel launcher on `PATH` named `wl` (or set `mtn.wlCommand`).
- A desktop front end to open `.nb` files (macOS `open`).
- The converters are the [deployed resource
  functions](https://www.wolframcloud.com/obj/nikm/DeployedResources/Function/MarkdownToNotebook)
  on the Wolfram Cloud — the same ones the build scripts use — so the button
  works on any `.md` with no local checkout. Redeploy them (build.wls) to pick
  up converter changes.

## Settings

| Setting                 | Default | Meaning                                                        |
| ----------------------- | ------- | -------------------------------------------------------------- |
| `mtn.wlCommand`         | `"wl"`  | Kernel launcher accepting `-f FILE`.                           |
| `mtn.openWith`          | `""`    | App for `open -a` (empty = default `.nb` handler).             |

## Install

```sh
npx @vscode/vsce package        # -> mtn-open-as-notebook-0.1.0.vsix
code --install-extension mtn-open-as-notebook-0.1.0.vsix
```

Then reload the window. The button appears on any `.md` editor.
