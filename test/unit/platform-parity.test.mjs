// The same API on two platforms, and what each one lacks, written down once: the JavaScript methods, the actions the Android plugin
// handles, the methods the iOS plugin has, and the README that documents them have to agree with it. Adding a method to one side
// without the other, or without its documentation, fails here.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const read = (path) => readFileSync(join(root, path), 'utf8');

// What one platform has and the other does not. A call to such a method fails on Android (an invalid action error reaches the failure
// callback) and is never answered on iOS (Cordova only logs that the method is not defined).
const ANDROID_ONLY = ['available', 'connectInsecure', 'enable', 'showBluetoothSettings'];
const IOS_ONLY = ['getBluetoothState'];

const js = read('www/bluetoothClassicSerial.js');
/** JavaScript method name -> the native action it sends. */
const actionOf = Object.fromEntries(
  [...js.matchAll(/^ {2}(\w+):\s*function[\s\S]*?(?=^ {2}\w+:\s*function|\n\};?\s*$)/gm)].map((match) => [
    match[1],
    /"BluetoothClassicSerial",\s*"(\w+)"/.exec(match[0])?.[1],
  ]),
);
const methods = Object.keys(actionOf);

const androidSource = read('src/android/nz/co/soltius/cordova/BluetoothClassicSerial.java');
const constants = Object.fromEntries([...androidSource.matchAll(/private static final String (\w+)\s*=\s*"(\w+)"/g)].map((m) => [m[1], m[2]]));
const androidActions = new Set([...androidSource.matchAll(/action\.equals\((\w+)\)/g)].map((m) => constants[m[1]]));

const iosActions = new Set(
  [...read('src/ios/BluetoothClassicSerial.m').matchAll(/^- \(void\)(\w+):\s*\(CDVInvokedUrlCommand\s*\*\)\s*command/gm)].map((m) => m[1]),
);

test('every JavaScript method sends an action, and the two platforms handle the same ones but for what is written down above', () => {
  assert.deepEqual(methods.filter((name) => !actionOf[name]), [], 'every method sends an action');
  const actions = methods.map((name) => actionOf[name]);

  const missingOnAndroid = actions.filter((action) => !androidActions.has(action)).sort();
  const missingOnIos = actions.filter((action) => !iosActions.has(action)).sort();
  assert.deepEqual(missingOnAndroid, [...IOS_ONLY].sort(), 'what Android lacks');
  assert.deepEqual(missingOnIos, [...ANDROID_ONLY].sort(), 'what iOS lacks');
});

test('neither plugin handles an action the JavaScript never sends', () => {
  const sent = new Set(methods.map((name) => actionOf[name]));
  assert.deepEqual([...androidActions].filter((action) => !sent.has(action)), []);
  assert.deepEqual([...iosActions].filter((action) => !sent.has(action)), []);
});

const readme = read('README.md');

test('the README has a section and an index entry for every method, and every index link finds its section', () => {
  const sections = [...readme.matchAll(/^## (\w+)\s*$/gm)].map((m) => m[1]);
  const index = [...readme.matchAll(/^- \[bluetoothClassicSerial\.(\w+)\]\(#(\w+)\)/gm)].map((m) => [m[1], m[2]]);

  assert.deepEqual(methods.filter((name) => !sections.includes(name)), [], 'a section for every method');
  assert.deepEqual(methods.filter((name) => !index.some(([indexed]) => indexed === name)), [], 'an index entry for every method');
  assert.deepEqual(
    index.filter(([, anchor]) => !sections.some((section) => section.toLowerCase() === anchor.toLowerCase())),
    [],
    'every index link finds its section',
  );
});

test('the README says what each platform lacks, in its table and in the section of the method', () => {
  for (const name of [...ANDROID_ONLY, ...IOS_ONLY]) {
    assert.match(readme, new RegExp(`\`${name}\``), `the table names ${name}`);
    const section = new RegExp(`^## ${name}\\s*$([\\s\\S]*?)(?=^## )`, 'm').exec(readme)?.[1] ?? '';
    const platform = ANDROID_ONLY.includes(name) ? 'iOS' : 'Android';
    assert.match(section, new RegExp(`#### ${platform}[\\s\\S]*not supported`, 'i'), `${name} says it is not supported on ${platform}`);
  }
});
