// tests/ is what cordova-paramedic runs on a phone (cordova-plugin-test-framework, Jasmine). A phone is slow and not always at hand, so
// the same `defineAutoTests` also runs here, on Node, against the real JavaScript of the plugin and a native that answers the way each
// platform does: a test that is wrong, or a plugin that drifted away from it, fails here first.
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const require = createRequire(import.meta.url);
const Module = require('node:module');
const pkg = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));

// --- the test plugin is declared the way cordova-paramedic needs it ---------------------------------------------------------

// The test plugin is private and never published, so its version is not tied to the plugin's: a release does not touch it.
test('tests/plugin.xml is the plugin id with "-tests", and loads tests.js', () => {
  const xml = readFileSync(join(root, 'tests', 'plugin.xml'), 'utf8');
  assert.match(xml, new RegExp(`<plugin[^>]*\\sid="${pkg.cordova.id}-tests"`));
  assert.match(xml, /<js-module src="tests\.js" name="tests"/);
  assert.ok(existsSync(join(root, 'tests', 'tests.js')));
});

test('tests/package.json (cordova plugin add needs one) names the same id', () => {
  const testsPkg = JSON.parse(readFileSync(join(root, 'tests', 'package.json'), 'utf8'));
  assert.equal(testsPkg.name, `${pkg.cordova.id}-tests`);
  assert.equal(testsPkg.cordova.id, `${pkg.cordova.id}-tests`);
});

test('tests/ is not published', () => {
  assert.ok(!pkg.files.includes('tests'), 'package.json "files" must leave tests/ out');
});

// --- the automatic tests, on Node -------------------------------------------------------------------------------------------

const STATE = { authorization: 'allowedAlways', supportedProtocols: [], connectedAccessories: 0, systemVersion: '26.0' };

/** What native answers, per platform and action. A device nothing is connected to is refused, as both platforms do. */
const native = (platform, authorization = 'allowedAlways') => (success, failure, _service, action) => {
  const answers = {
    getBluetoothState: () => success({ ...STATE, authorization }),
    list: () => success([]),
    isEnabled: () => success(true),
    isConnected: () => failure('Not connected'),
    write: () => failure('Not connected'),
  };
  // Anything else (a listener being set or cleared) has no answer to wait for.
  answers[action]?.();
};

/** A Jasmine-sized runner: describe, it (with or without `done`), `fail`, `pending` and the few matchers the tests use. */
async function run(platform, exec) {
  globalThis.cordova = { platformId: platform };
  const original = Module._load;
  Module._load = function (request, ...rest) {
    return request === 'cordova/exec' ? exec : original.call(this, request, ...rest);
  };
  const wrapper = join(root, 'www', 'bluetoothClassicSerial.js');
  try {
    delete require.cache[wrapper];
    globalThis.window = { bluetoothClassicSerial: require(wrapper) };
  } finally {
    Module._load = original;
  }

  const specs = [];
  let suite = '';
  globalThis.describe = (name, body) => {
    suite = name;
    body();
  };
  globalThis.it = (name, body) => specs.push({ name: `${suite} ${name}`, body });
  class Pending extends Error {}
  globalThis.pending = (reason) => {
    throw new Pending(reason);
  };
  let failures;
  globalThis.fail = (what) => failures.push(String(what));
  globalThis.expect = (actual) => {
    const check = (ok, what) => ok || failures.push(what);
    return {
      toBe: (expected) => check(Object.is(actual, expected), `expected ${String(actual)} to be ${String(expected)}`),
      toBeDefined: () => check(actual !== undefined, 'expected a value'),
      toContain: (part) => check(actual.includes(part), `expected ${String(actual)} to contain ${String(part)}`),
      toThrow: () => {
        try {
          actual();
          failures.push('expected a throw');
        } catch {
          // thrown, as expected
        }
      },
    };
  };

  require(join(root, 'tests', 'tests.js')).defineAutoTests();

  const results = [];
  for (const spec of specs) {
    failures = [];
    try {
      await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('timed out')), 2000);
        const finish = () => {
          clearTimeout(timer);
          resolve();
        };
        if (spec.body.length > 0) spec.body(finish);
        else {
          spec.body();
          finish();
        }
      });
      results.push({ name: spec.name, state: failures.length ? 'failed' : 'passed', failures: [...failures] });
    } catch (error) {
      results.push({ name: spec.name, state: error instanceof Pending ? 'pending' : 'failed', failures: [String(error)] });
    }
  }
  return results;
}

const failed = (results) => results.filter((r) => r.state === 'failed').map((r) => `${r.name}: ${r.failures}`);
const pendingNames = (results) => results.filter((r) => r.state === 'pending').map((r) => r.name);

test('Android: every automatic test passes, and only the iOS one is pending', async () => {
  const results = await run('android', native('android'));
  assert.deepEqual(failed(results), []);
  assert.deepEqual(pendingNames(results), ['getBluetoothState (iOS) says what iOS knows, and raises no permission prompt']);
  assert.ok(results.filter((r) => r.state === 'passed').length >= 7);
});

test('iOS: every automatic test passes when the Bluetooth permission is decided', async () => {
  const results = await run('ios', native('ios'));
  assert.deepEqual(failed(results), []);
  assert.deepEqual(pendingNames(results), []);
});

test('iOS: isEnabled is left out while the permission is undecided, because its prompt would block an unattended run', async () => {
  const results = await run('ios', native('ios', 'notDetermined'));
  assert.deepEqual(failed(results), []);
  assert.equal(pendingNames(results).length, 1);
  assert.match(pendingNames(results)[0], /^isEnabled /);
});

test('a test that is wrong is caught: a write that native accepts fails the run', async () => {
  const accepting = (success, failure, service, action, args) =>
    action === 'write' ? success() : native('ios')(success, failure, service, action, args);
  const results = await run('ios', accepting);
  assert.equal(failed(results).length, 1);
  assert.match(failed(results)[0], /write to it is refused/);
});
