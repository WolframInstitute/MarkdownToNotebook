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

// Resolve the kernel launcher to an absolute path. VS Code launched from the
// Dock inherits a minimal PATH (/usr/bin:/bin:...), so a bare "wl" would fail
// with ENOENT even though the terminal finds it; probe the usual install dirs.
const WL_DIRS = ['/usr/local/bin', '/opt/homebrew/bin', path.join(os.homedir(), 'bin')];
function resolveWl(cmd) {
  if (cmd.includes(path.sep)) return cmd; // explicit path in settings wins
  for (const dir of WL_DIRS) {
    const cand = path.join(dir, cmd);
    if (fs.existsSync(cand)) return cand;
  }
  return cmd; // on PATH (terminal-launched VS Code) or let ENOENT surface
}

function runBuilder(wl, builder, env) {
  return new Promise((resolve, reject) => {
    const child = cp.spawn(resolveWl(wl), ['-t', '300', '-f', builder], {
      env: Object.assign({}, process.env, env, {
        PATH: [process.env.PATH || '', ...WL_DIRS].join(path.delimiter)
      })
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

    const builder = path.join(context.extensionPath, 'open-as-notebook.wls');
    const hash = crypto.createHash('sha1').update(mdPath).digest('hex').slice(0, 10);
    const outNb = path.join(os.tmpdir(), `mtn-${path.basename(mdPath, '.md')}-${hash}.nb`);

    try {
      const nbPath = await vscode.window.withProgress(
        {
          location: vscode.ProgressLocation.Notification,
          title: `Opening ${path.basename(mdPath)} as a Wolfram notebook…`
        },
        () => runBuilder(wl, builder, { MTN_MD_PATH: mdPath, MTN_OUT_NB: outNb })
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
