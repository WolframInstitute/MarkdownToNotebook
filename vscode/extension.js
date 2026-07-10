// Markdown <-> Wolfram Notebook -- VS Code extension.
//
// Adds an "Open as Wolfram Notebook" button next to the Markdown preview button.
// Clicking it runs MarkdownToNotebook on the .md, writes a temp .nb carrying a docked
// "Save to Markdown" toolbar (which calls NotebookToMarkdown back onto the same file),
// and opens that notebook in the Wolfram desktop front end.

const vscode = require('vscode');
const cp = require('child_process');
const path = require('path');
const os = require('os');
const fs = require('fs');
const crypto = require('crypto');

// Find the folder holding MarkdownToNotebook.wl / NotebookToMarkdown.wl.
// Precedence: explicit setting -> ancestors of the .md -> open workspace folders.
function hasPackages(dir) {
  try {
    return fs.existsSync(path.join(dir, 'MarkdownToNotebook.wl')) &&
           fs.existsSync(path.join(dir, 'NotebookToMarkdown.wl'));
  } catch (_) {
    return false;
  }
}

function resolvePkgDir(configured, mdPath) {
  if (configured && configured.trim()) {
    const dir = configured.trim();
    return hasPackages(dir) ? dir : null; // honor an explicit (possibly wrong) setting loudly
  }
  // walk up from the markdown file
  let dir = path.dirname(mdPath);
  for (let i = 0; i < 40; i++) {
    if (hasPackages(dir)) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  // then the open workspace folders
  for (const wf of vscode.workspace.workspaceFolders || []) {
    if (hasPackages(wf.uri.fsPath)) return wf.uri.fsPath;
  }
  return null;
}

function runBuilder(wl, builder, env) {
  return new Promise((resolve, reject) => {
    const child = cp.spawn(wl, ['-t', '300', '-f', builder], {
      env: Object.assign({}, process.env, env)
    });
    let out = '';
    let err = '';
    child.stdout.on('data', (d) => (out += d.toString()));
    child.stderr.on('data', (d) => (err += d.toString()));
    child.on('error', (e) =>
      reject(new Error(`could not run "${wl}" (${e.message}). Set "mtn.wlCommand".`))
    );
    child.on('close', (code) => {
      const lines = out.split(/\r?\n/).filter((l) => l.trim());
      const errLine = lines.find((l) => l.startsWith('ERROR:'));
      if (code !== 0 || errLine) {
        reject(new Error(errLine || err.trim() || `builder exited with code ${code}`));
        return;
      }
      const nb = lines[lines.length - 1];
      if (!nb || !fs.existsSync(nb)) {
        reject(new Error('builder did not produce a notebook'));
        return;
      }
      resolve(nb);
    });
  });
}

function openNotebook(nbPath, openWith) {
  const args = openWith && openWith.trim() ? ['-a', openWith.trim(), nbPath] : [nbPath];
  cp.spawn('open', args, { detached: true, stdio: 'ignore' }).unref();
}

function activate(context) {
  const cmd = vscode.commands.registerCommand('mtn.openAsNotebook', async (uri) => {
    let mdPath = uri && uri.fsPath ? uri.fsPath : undefined;
    if (!mdPath && vscode.window.activeTextEditor) {
      mdPath = vscode.window.activeTextEditor.document.uri.fsPath;
    }
    if (!mdPath) {
      vscode.window.showErrorMessage('Open as Wolfram Notebook: no Markdown file is active.');
      return;
    }
    if (!mdPath.toLowerCase().endsWith('.md')) {
      vscode.window.showErrorMessage(`Open as Wolfram Notebook: not a .md file (${path.basename(mdPath)}).`);
      return;
    }

    // flush unsaved edits so the conversion sees current content
    const doc = vscode.workspace.textDocuments.find((d) => d.uri.fsPath === mdPath);
    if (doc && doc.isDirty) {
      await doc.save();
    }

    const cfg = vscode.workspace.getConfiguration('mtn');
    const wl = cfg.get('wlCommand') || 'wl';
    const openWith = cfg.get('openWith') || '';

    const pkgDir = resolvePkgDir(cfg.get('packageDirectory'), mdPath);
    if (!pkgDir) {
      vscode.window.showErrorMessage(
        'Open as Wolfram Notebook: could not find MarkdownToNotebook.wl / NotebookToMarkdown.wl. ' +
          'Set "mtn.packageDirectory" in Settings.'
      );
      return;
    }

    const builder = path.join(context.extensionPath, 'open-as-notebook.wls');
    const hash = crypto.createHash('sha1').update(mdPath).digest('hex').slice(0, 10);
    const outNb = path.join(os.tmpdir(), `mtn-${path.basename(mdPath, '.md')}-${hash}.nb`);

    try {
      const nbPath = await vscode.window.withProgress(
        {
          location: vscode.ProgressLocation.Notification,
          title: `Opening ${path.basename(mdPath)} as a Wolfram notebook…`
        },
        () => runBuilder(wl, builder, { MTN_PKG_DIR: pkgDir, MTN_MD_PATH: mdPath, MTN_OUT_NB: outNb })
      );
      openNotebook(nbPath, openWith);
    } catch (e) {
      vscode.window.showErrorMessage(`Open as Wolfram Notebook: ${e.message}`);
    }
  });

  context.subscriptions.push(cmd);
}

function deactivate() {}

module.exports = { activate, deactivate };
