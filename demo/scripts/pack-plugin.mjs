/* eslint-disable no-console */
// Installs the plugin THIS checkout holds into the demo, as npm would ship it. `cordova plugin add ..` copies the parent
// directory, which contains the demo itself, and fails (or installs nothing) in the recursion; `npm pack` takes only
// the files listed in package.json, so the copy is the plugin and nothing else.
import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// cordova installs a plugin from a folder with `npm install <folder>`, which also installs the devDependencies of that package (a local
// cordova among them) into the demo and breaks the next cordova call. A plugin needs its plugin.xml and sources only.
function dropDevelopmentFields(dir) {
  const manifestPath = join(dir, 'package.json');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  delete manifest.devDependencies;
  delete manifest.scripts;
  writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
}

const demo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const root = resolve(demo, '..');
const out = join(demo, '.plugin');
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const tarball = execFileSync('npm', ['pack', '--silent', '--pack-destination', out], { cwd: root, encoding: 'utf8' }).trim().split('\n').pop();
execFileSync('tar', ['-xzf', join(out, tarball), '-C', out, '--strip-components=1']);
rmSync(join(out, tarball));
dropDevelopmentFields(out);
const id = JSON.parse(execFileSync('node', ['-e', `console.log(JSON.stringify(require('${join(root, 'package.json')}').cordova))`], { encoding: 'utf8' })).id;
try {
  execFileSync('cordova', ['plugin', 'rm', id, '--nosave'], { cwd: demo, stdio: 'ignore' });
} catch {
  // not installed yet
}
// The plugin is created when the app starts, so the Bluetooth permission prompt comes at launch and not in the middle of the
// first call (see IOS_INIT_ON_LOAD in the README).
execFileSync('cordova', ['plugin', 'add', out, '--nosave', '--variable', 'IOS_INIT_ON_LOAD=true'], { cwd: demo, stdio: 'inherit' });
// The web view the demo runs on: the ionic web view plugin. It presents alert, confirm and prompt from the application delegate's window,
// which is empty in an app on scenes, so without the fix in patches/ those dialogs never show and the page stays blocked. Its plugin.xml also
// sets an iOS deployment target of 11.0, which is commented out so that the app keeps the platform's own. The package is fetched, the patches applied to the copy,
// and the copy installed: cordova cannot add a plugin from inside node_modules, and adding one removes it from there.
const WEB_VIEW = 'cordova-plugin-ionic-webview@5.0.1';
const webView = join(demo, '.web-view-plugin');
rmSync(webView, { recursive: true, force: true });
mkdirSync(webView, { recursive: true });
const webViewTarball = execFileSync('npm', ['pack', '--silent', '--pack-destination', webView, WEB_VIEW], { cwd: demo, encoding: 'utf8' }).trim().split('\n').pop();
execFileSync('tar', ['-xzf', join(webView, webViewTarball), '-C', webView, '--strip-components=1']);
rmSync(join(webView, webViewTarball));
// the patches are diffs of node_modules/<package>/..., three path components above the file
for (const name of ['webview-dialogs.patch', 'webview-deployment-target.patch']) {
  execFileSync('patch', ['-p3', '-d', webView, '-i', join(demo, 'patches', name)], { stdio: 'inherit' });
}
dropDevelopmentFields(webView);
try {
  execFileSync('cordova', ['plugin', 'rm', 'cordova-plugin-ionic-webview', '--nosave'], { cwd: demo, stdio: 'ignore' });
} catch {
  // not installed yet
}
execFileSync('cordova', ['plugin', 'add', webView, '--nosave'], { cwd: demo, stdio: 'inherit' });
try {
  execFileSync('cordova', ['plugin', 'rm', 'io.github.maximbelov.btclassic.demo.nativeprobe', '--nosave'], { cwd: demo, stdio: 'ignore' });
} catch {
  // not installed yet
}
// The demo-only probe, straight from this directory: it has no dependencies and lives inside the project tree.
execFileSync('cordova', ['plugin', 'add', join(demo, 'native-probe'), '--nosave'], { cwd: demo, stdio: 'inherit' });
console.log(`installed ${id} from ${out}`);
