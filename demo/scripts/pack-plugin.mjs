/* eslint-disable no-console */
// Installs the plugin THIS checkout holds into the demo, as npm would ship it. `cordova plugin add ..` copies the parent
// directory, which contains the demo itself, and fails (or installs nothing) in the recursion; `npm pack` takes only
// the files listed in package.json, so the copy is the plugin and nothing else.
import { execFileSync } from 'node:child_process';
import { mkdirSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const demo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const root = resolve(demo, '..');
const out = join(demo, '.plugin');
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const tarball = execFileSync('npm', ['pack', '--silent', '--pack-destination', out], { cwd: root, encoding: 'utf8' }).trim().split('\n').pop();
execFileSync('tar', ['-xzf', join(out, tarball), '-C', out, '--strip-components=1']);
rmSync(join(out, tarball));
const id = JSON.parse(execFileSync('node', ['-e', `console.log(JSON.stringify(require('${join(root, 'package.json')}').cordova))`], { encoding: 'utf8' })).id;
try {
  execFileSync('cordova', ['plugin', 'rm', id, '--nosave'], { cwd: demo, stdio: 'ignore' });
} catch {
  // not installed yet
}
// The plugin is created when the app starts, so the Bluetooth permission prompt comes at launch and not in the middle of the
// first call (see IOS_INIT_ON_LOAD in the README).
execFileSync('cordova', ['plugin', 'add', out, '--nosave', '--variable', 'IOS_INIT_ON_LOAD=true'], { cwd: demo, stdio: 'inherit' });
try {
  execFileSync('cordova', ['plugin', 'rm', 'io.github.maximbelov.btclassic.demo.nativeprobe', '--nosave'], { cwd: demo, stdio: 'ignore' });
} catch {
  // not installed yet
}
// The demo-only probe, straight from this directory: it has no dependencies and lives inside the project tree.
execFileSync('cordova', ['plugin', 'add', join(demo, 'native-probe'), '--nosave'], { cwd: demo, stdio: 'inherit' });
console.log(`installed ${id} from ${out}`);
