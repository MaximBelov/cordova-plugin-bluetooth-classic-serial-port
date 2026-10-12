#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * The demo on ONE iPhone or iPad, driven natively: JavaScript `alert`, `confirm` and the system accessory picker. Nothing is read from
 * JavaScript (the web context is the slow and fragile part on a simulator and on a slow cloud device): the demo's buttons are found by
 * label in the native tree, pressed, and what is on the screen is read back, a dialog from `/alert/text` and the page log from the tree.
 *
 *   TARGET=local        APPIUM_URL (default http://127.0.0.1:4723), IOS_UDID, XCODE_ORG_ID (a real phone only; a simulator needs none),
 *                       APP_BUNDLE (default io.github.maximbelov.btclassic.demo); the app is already installed
 *   TARGET=testingbot   TESTINGBOT_KEY, TESTINGBOT_SECRET, DEVICE ("iPhone 14"), OS_VERSION ("17.6"), APP_URL (tb://...)
 *   TARGET=browserstack BROWSERSTACK_USERNAME, BROWSERSTACK_ACCESS_KEY, DEVICE, OS_VERSION (major only: "17"), APP_URL (bs://...)
 *   OUT=<dir> for screenshots, SESSION_WAIT_MS how long a cloud device may take to give a session (default 90000)
 *
 * What counts as a verdict (a negative one cost hours to get wrong before these rules):
 *   - a dialog is NOT SHOWN only when the page log says the call started and no dialog is on screen; a button that was never pressed
 *     (a click lost on a slow device) is "no verdict";
 *   - the picker is NOT SHOWN only when Bluetooth is on (`isEnabled` answered ok true), the call started and no picker is on screen;
 *     a device with Bluetooth off, and every simulator, gives "no verdict".
 * Prints one line `RESULT {json}`. Exit code: 0 both dialogs shown and the picker shown or no verdict, 1 a dialog gave no good verdict or the picker was not shown, 2 no session.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

const E = process.env;
const target = E.TARGET ?? 'local';
const out = E.OUT ?? join(process.cwd(), 'probe-demo-out');
mkdirSync(out, { recursive: true });
const headers = { 'content-type': 'application/json' };
const t0 = Date.now();
const log = (...a) => console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s]`, ...a);

const need = (...names) => {
  const missing = names.filter((n) => !E[n]);
  if (missing.length) {
    console.error(`missing environment: ${missing.join(', ')}`);
    process.exit(2);
  }
};
const setups = {
  local: () => {
    need('IOS_UDID');
    return {
      base: E.APPIUM_URL ?? 'http://127.0.0.1:4723',
      caps: {
        platformName: 'iOS', 'appium:automationName': 'XCUITest', 'appium:udid': E.IOS_UDID, 'appium:bundleId': E.APP_BUNDLE ?? 'io.github.maximbelov.btclassic.demo',
        'appium:noReset': true, 'appium:wdaLocalPort': 8110, 'appium:wdaLaunchTimeout': 240000,
        ...(E.XCODE_ORG_ID ? { 'appium:xcodeOrgId': E.XCODE_ORG_ID, 'appium:xcodeSigningId': 'Apple Development' } : {}),
      },
    };
  },
  testingbot: () => {
    need('TESTINGBOT_KEY', 'TESTINGBOT_SECRET', 'DEVICE', 'OS_VERSION', 'APP_URL');
    return {
      base: 'https://hub.testingbot.com/wd/hub',
      caps: {
        platformName: 'ios', 'appium:automationName': 'XCUITest', 'appium:deviceName': E.DEVICE, 'appium:platformVersion': E.OS_VERSION, 'tb:phoneOnly': true, 'appium:app': E.APP_URL,
        'appium:newCommandTimeout': 900, 'tb:options': { key: E.TESTINGBOT_KEY, secret: E.TESTINGBOT_SECRET, realDevice: true, build: 'demo probe', name: `${E.DEVICE} ${E.OS_VERSION}`, idletimeout: 130 },
      },
    };
  },
  browserstack: () => {
    need('BROWSERSTACK_USERNAME', 'BROWSERSTACK_ACCESS_KEY', 'DEVICE', 'OS_VERSION', 'APP_URL');
    return {
      base: 'https://hub-cloud.browserstack.com/wd/hub',
      caps: {
        platformName: 'ios', 'appium:automationName': 'XCUITest', 'appium:deviceName': E.DEVICE, 'appium:platformVersion': E.OS_VERSION, 'appium:app': E.APP_URL, 'appium:noReset': false,
        'bstack:options': { userName: E.BROWSERSTACK_USERNAME, accessKey: E.BROWSERSTACK_ACCESS_KEY, projectName: 'demo probe', buildName: 'demo probe', sessionName: `${E.DEVICE} ${E.OS_VERSION}`, idleTimeout: 120 },
      },
    };
  },
};
if (!setups[target]) {
  console.error(`TARGET must be one of ${Object.keys(setups).join(', ')}`);
  process.exit(2);
}
const { base, caps } = setups[target]();
Object.assign(caps, { 'appium:autoAcceptAlerts': false, 'appium:waitForIdleTimeout': 0 });

const call = async (method, path, body, ms = 40000) => {
  try {
    const response = await fetch(`${base}${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(ms) });
    return await response.json().catch(() => ({}));
  } catch (error) {
    return { value: { error: `request failed: ${error.name}` } };
  }
};

const created = await call('POST', '/session', { capabilities: { alwaysMatch: caps } }, Number(E.SESSION_WAIT_MS ?? 90000));
const id = created?.value?.sessionId ?? created?.sessionId;
const result = { target, device: E.DEVICE ?? E.IOS_UDID, os: E.OS_VERSION ?? null, dialogs: [] };
if (!id) {
  result.error = `no session: ${JSON.stringify(created?.value ?? created).slice(0, 240)}`;
  console.log('RESULT', JSON.stringify(result));
  process.exit(2);
}
const s = (method, path, body, ms) => call(method, `/session/${id}${path}`, body, ms);
const endSession = async () => {
  await call('DELETE', `/session/${id}`, undefined, 30000);
};
// A cloud session is paid for by the minute: leave it on a signal too.
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, async () => {
    await endSession();
    process.exit(130);
  });
}
log('session', id);

const shot = async (name) => {
  const r = await s('GET', '/screenshot');
  if (r.value) writeFileSync(join(out, name), Buffer.from(r.value, 'base64'));
};
const alertText = async () => {
  const r = await s('GET', '/alert/text', undefined, 8000);
  return typeof r.value === 'string' ? r.value : null;
};
const alertButtons = async () => (await s('POST', '/execute/sync', { script: 'mobile: alert', args: [{ action: 'getButtons' }] })).value ?? [];
const answer = (buttonLabel) => s('POST', '/execute/sync', { script: 'mobile: alert', args: [{ action: 'accept', buttonLabel }] });
// the page log as the native tree shows it, with the entities decoded
const pageText = async () => ((await s('GET', '/source', undefined, 90000)).value ?? '').replace(/&quot;/g, '"').replace(/&#10;/g, ' ');
const press = async (label) => {
  const found = await s('POST', '/element', { using: '-ios predicate string', value: `label == "${label}" OR name == "${label}"` });
  const ref = found.value && (found.value['element-6066-11e4-a52e-4f735466cecf'] ?? Object.values(found.value)[0]);
  if (!ref || typeof ref !== 'string') return false;
  await s('POST', `/element/${ref}/click`);
  return true;
};
const waitFor = async (read, seconds, step = 1000) => {
  for (let i = 0; i < seconds * (1000 / step); i++) {
    const value = await read();
    if (value) return value;
    await sleep(step);
  }
  return null;
};

// 1. A launch permission prompt, if the device raises one (the demo creates the plugin at launch). "Don't Allow" contains "Allow":
// the match is a whole word.
await sleep(2000);
for (let i = 0; i < 6; i++) {
  const text = await waitFor(alertText, i === 0 ? 6 : 1);
  if (!text) break;
  const buttons = await alertButtons();
  const label = buttons.find((b) => /^(allow|ok)$/i.test(String(b).replace(/\W/g, '')));
  log('prompt', JSON.stringify(text.slice(0, 80)), JSON.stringify(buttons), '->', label);
  if (!label) break;
  await answer(label);
  result.prompt = { text: text.slice(0, 100), answered: label };
  await sleep(1000);
}

// 2. The exact iOS version (a cloud names the major one) and whether Bluetooth is on at all.
const readState = async (button, pattern) => {
  if (!(await press(button))) return null;
  return waitFor(async () => (await pageText()).match(pattern)?.[1] ?? null, 6);
};
result.systemVersion = await readState('Bluetooth state (plugin)', /systemVersion"?\s*:\s*"?([0-9.]+)/);
result.bluetooth = await readState('Is Bluetooth enabled', /isEnabled: (ok [a-z]+|fail [^ \n<]*)/);
log('iOS', result.systemVersion, '| Bluetooth', result.bluetooth);

// 3. alert and confirm.
for (const [kind, label] of [['alert', 'JavaScript alert'], ['confirm', 'JavaScript confirm']]) {
  const entry = { kind, verdict: 'no verdict: the button was never pressed' };
  for (let attempt = 1; attempt <= 3 && entry.verdict.startsWith('no verdict'); attempt++) {
    const started = Date.now();
    if (!(await press(label))) { await sleep(2000); continue; }
    const dialog = await waitFor(alertText, 8);
    await shot(`${kind}.png`);
    if (dialog) {
      entry.dialog = dialog;
      entry.appearedAfterMs = Date.now() - started;
      await answer('OK');
      await sleep(800);
      entry.verdict = (await pageText()).includes(`${kind}: ok`) ? 'shown' : 'shown, but the call did not return';
    } else if ((await pageText()).includes(`${kind}: started`)) {
      entry.verdict = 'NOT SHOWN';
    }
  }
  log(kind, entry.verdict);
  result.dialogs.push(entry);
}

// 4. The system accessory picker. Where it works it appears within about four seconds. Another system alert can come instead (with
// Bluetooth off iOS asks to turn it on, in the picker's own name): it is not the picker, and the page log may not be readable behind it.
const picker = { verdict: 'no verdict' };
if (await press('Pair new device (system picker)')) {
  const started = Date.now();
  const seen = await waitFor(async () => {
    const text = await alertText();
    if (text) return /select an accessory/i.test(text) ? 'picker' : text;
    return /select an accessory/i.test(await pageText()) ? 'picker' : null;
  }, 12, 2000);
  await shot('picker.png');
  if (seen === 'picker') {
    picker.verdict = 'shown';
    picker.appearedAfterMs = Date.now() - started;
    await press('Cancel');
  } else if (seen) {
    picker.systemAlert = seen.slice(0, 160);
    const buttons = await alertButtons();
    await answer(buttons.find((b) => /^(close|ok|cancel)$/i.test(String(b))) ?? buttons[0]);
    await sleep(1000);
    picker.verdict = /bluetooth/i.test(seen) ? 'no verdict: the system asked to turn Bluetooth on, so it is off' : `no verdict: another system alert came: ${picker.systemAlert}`;
  } else if (!(await pageText()).includes('discoverUnpaired: started')) {
    picker.verdict = 'no verdict: the call did not start';
  } else if (result.bluetooth !== 'ok true') {
    picker.verdict = `no verdict: Bluetooth is not on (${result.bluetooth})`;
  } else {
    picker.verdict = 'NOT SHOWN';
  }
}
log('picker', picker.verdict);
result.picker = picker;

await endSession();
console.log('RESULT', JSON.stringify(result));
process.exit(result.dialogs.some((d) => d.verdict !== 'shown') || picker.verdict === 'NOT SHOWN' ? 1 : 0);
