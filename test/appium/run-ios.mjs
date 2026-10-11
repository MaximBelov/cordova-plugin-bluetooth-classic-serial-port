#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Runs the picker probe on a phone with an Appium server of its own, so nothing has to be started by hand:
 *
 *   HW_IOS_UDID=<udid> XCODE_ORG_ID=<team id> npm run test:appium:ios
 *
 * It takes a free port, starts `appium server` there (the `appium` command and its xcuitest driver must be installed), waits until
 * the server answers, runs probe-accessory-picker.mjs against it and stops the server again, whatever the probe's outcome.
 * To use a server that is already running, run the probe directly with APPIUM_URL set.
 */
import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { setTimeout as sleep } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

const probe = fileURLToPath(new URL('./probe-accessory-picker.mjs', import.meta.url));

const freePort = () =>
  new Promise((resolve, reject) => {
    const server = createServer();
    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close(() => resolve(port));
    });
  });

const port = await freePort();
const url = `http://127.0.0.1:${port}`;
// Its own process group, so the whole server (and what it started) can be stopped with one signal.
const appium = spawn('appium', ['server', '--port', String(port)], { stdio: 'ignore', detached: true });
let startFailure = null;
appium.on('error', (error) => {
  startFailure = error;
});
const stopAppium = () => {
  try {
    process.kill(-appium.pid, 'SIGTERM');
  } catch {
    // already gone
  }
};
process.on('SIGINT', () => {
  stopAppium();
  process.exit(130);
});

let code = 1;
try {
  let ready = false;
  for (const end = Date.now() + 60000; !ready && Date.now() < end && !startFailure; await sleep(300)) {
    ready = await fetch(`${url}/status`).then((response) => response.ok, () => false);
  }
  if (startFailure) throw new Error(`could not start appium: ${startFailure.message} (is it installed? npm i -g appium)`);
  if (!ready) throw new Error(`appium did not answer on ${url} within 60 s`);
  code = await new Promise((resolve) => {
    spawn(process.execPath, [probe], { stdio: 'inherit', env: { ...process.env, APPIUM_URL: url } }).on('close', (status) => resolve(status ?? 1));
  });
} catch (error) {
  console.error(error.message);
} finally {
  stopAppium();
}
process.exit(code);
