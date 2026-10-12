#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * probe-demo.mjs over a list of cloud devices, a few at a time, with a table at the end.
 *
 *   node test/appium/run-cloud.mjs upload   <testingbot|browserstack> path/to/demo.ipa      # prints the app url (tb://... or bs://...)
 *   node test/appium/run-cloud.mjs run      <testingbot|browserstack> <app url> [--parallel N] [--only "iPhone 14"] [--os 17] [--wait-ms 90000]
 *
 * The devices are in devices.json, one list per vendor. Keys come from the environment (see probe-demo.mjs) and are never printed.
 * Results: test/appium/results/<vendor>/<device>-<os>.{json,log} and screenshots next to them.
 *
 * Facts about the two clouds that shape this (2026-10):
 *   - TestingBot (Automated Pro): ONE session at a time, the hub holds a request while the device is busy, and old devices (an iPhone 8)
 *     are slow to give a session and slow to answer. A device that gives no session within --wait-ms is skipped, not retried.
 *   - BrowserStack (Free): five sessions, majors only ("17"), and Bluetooth is OFF on most iPhones there, so the picker gives no verdict
 *     (the probe says why); it is ON on the iPad 10th generation / 16 and the iPhone 15 / 27 at the time of writing. A real iOS version
 *     is read from the app (`systemVersion` in the result), not from the name asked for.
 * Stopping: Ctrl-C ends the sessions that are running (each probe deletes its own session on a signal), and starts no more.
 */
import { spawn } from 'node:child_process';
import { createWriteStream, mkdirSync, readFileSync, readdirSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = fileURLToPath(new URL('.', import.meta.url));
const [command, vendor, third, ...rest] = process.argv.slice(2);
const E = process.env;
const vendors = ['testingbot', 'browserstack'];
if (!['upload', 'run'].includes(command) || !vendors.includes(vendor) || !third) {
  console.error('usage: run-cloud.mjs upload <testingbot|browserstack> <ipa>\n       run-cloud.mjs run <testingbot|browserstack> <app url> [--parallel N] [--only "<device>"] [--os <os>] [--wait-ms N]');
  process.exit(2);
}

if (command === 'upload') {
  const auth = vendor === 'testingbot' ? `${E.TESTINGBOT_KEY}:${E.TESTINGBOT_SECRET}` : `${E.BROWSERSTACK_USERNAME}:${E.BROWSERSTACK_ACCESS_KEY}`;
  const url = vendor === 'testingbot' ? 'https://api.testingbot.com/v1/storage' : 'https://api-cloud.browserstack.com/app-automate/upload';
  await new Promise((resolve) => {
    const curl = spawn('curl', ['-s', '-u', auth, '-X', 'POST', url, '-F', `file=@${third}`], { stdio: ['ignore', 'pipe', 'inherit'] });
    let body = '';
    curl.stdout.on('data', (chunk) => (body += chunk));
    curl.on('close', () => {
      const parsed = JSON.parse(body || '{}');
      console.log(parsed.app_url ?? JSON.stringify(parsed));
      resolve();
    });
  });
  process.exit(0);
}

const option = (name, fallback) => {
  const at = rest.indexOf(name);
  return at >= 0 ? rest[at + 1] : fallback;
};
const parallel = Number(option('--parallel', vendor === 'testingbot' ? 1 : 3));
const only = option('--only');
const onlyOs = option('--os');
const waitMs = option('--wait-ms', '90000');
const devices = JSON.parse(readFileSync(join(here, 'devices.json'), 'utf8'))[vendor].filter((d) => (!only || d.device === only) && (!onlyOs || d.os === onlyOs));
const results = join(here, 'results', vendor);
mkdirSync(results, { recursive: true });

const running = new Set();
let stopping = false;
process.on('SIGINT', () => {
  stopping = true;
  for (const child of running) child.kill('SIGTERM');
});

const runOne = ({ device, os }) =>
  new Promise((resolve) => {
    if (stopping) return resolve();
    const name = `${device.replace(/\W+/g, '_')}-${os}`;
    const log = createWriteStream(join(results, `${name}.log`));
    const child = spawn(process.execPath, [join(here, 'probe-demo.mjs')], {
      env: { ...E, TARGET: vendor, DEVICE: device, OS_VERSION: os, APP_URL: third, SESSION_WAIT_MS: waitMs, OUT: join(results, name) },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    running.add(child);
    child.stdout.pipe(log);
    child.stderr.pipe(log);
    child.on('close', () => {
      running.delete(child);
      console.log(`finished ${device} ${os}`);
      resolve();
    });
  });

const queue = [...devices];
await Promise.all(Array.from({ length: Math.min(parallel, queue.length) }, async () => {
  while (queue.length && !stopping) await runOne(queue.shift());
}));

console.log('\n| Device | iOS (real) | Bluetooth | alert | confirm | picker |\n| --- | --- | --- | --- | --- | --- |');
// only this run's devices: older logs stay in the folder
const thisRun = new Set(devices.map(({ device, os }) => `${device.replace(/\W+/g, '_')}-${os}.log`));
for (const file of readdirSync(results).filter((f) => thisRun.has(f)).sort()) {
  const line = readFileSync(join(results, file), 'utf8').split('\n').filter((l) => l.startsWith('RESULT')).pop();
  const name = basename(file, '.log');
  if (!line) {
    console.log(`| ${name} | | | | | no result |`);
    continue;
  }
  const r = JSON.parse(line.slice(7));
  if (r.error) {
    console.log(`| ${name} | | | | | ${r.error.includes('request failed') || r.error.includes('busy') ? 'no session' : r.error.slice(0, 60)} |`);
    continue;
  }
  const [alert, confirm] = r.dialogs.map((d) => d.verdict);
  console.log(`| ${name} | ${r.systemVersion ?? '?'} | ${r.bluetooth ?? '?'} | ${alert} | ${confirm} | ${r.picker.verdict} |`);
}
