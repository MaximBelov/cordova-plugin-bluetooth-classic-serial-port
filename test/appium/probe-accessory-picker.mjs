#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Is the system accessory picker SHOWN? Only the screen can say: from JavaScript a picker that never appeared and one that is
 * waiting for the user look the same (`discoverUnpaired` has not answered). This presses "Pair new device" in the demo on an iPhone and
 * looks for iOS's own alert ("Select An Accessory", button Cancel); it then presses Cancel and expects the call to answer "Cancelled".
 *
 *   APPIUM_URL=<server> node test/appium/probe-accessory-picker.mjs   # against a server that is running; `npm run test:appium:ios` starts its own
 * On a clean install the launch permission prompt is answered first, then the FIRST call must show the picker.
 *
 * What it caught: on cordova-ios 8 (CDVAppDelegate.window is nil in an app on scenes) the picker was never shown and the call never answered.
 * The demo installs the plugin with IOS_INIT_ON_LOAD=true, so the Bluetooth permission prompt comes at launch and not in the middle of the call.
 *
* Environment: HW_IOS_UDID (required; `xcrun xctrace list devices`), XCODE_ORG_ID (required: your Apple team id, WebDriverAgent is signed with it), APPIUM_URL (default http://127.0.0.1:4723, needs the usual
 * XCUITest setup), APP_BUNDLE (default io.github.maximbelov.btclassic.demo).
 */
import { setTimeout as sleep } from 'node:timers/promises';

const appium = process.env.APPIUM_URL ?? 'http://127.0.0.1:4723';
const udid = process.env.HW_IOS_UDID;
const bundleId = process.env.APP_BUNDLE ?? 'io.github.maximbelov.btclassic.demo';
if (!udid || !process.env.XCODE_ORG_ID) {
  console.error('HW_IOS_UDID (xcrun xctrace list devices) and XCODE_ORG_ID (your Apple team id) are required');
  process.exit(2);
}

const call = async (method, path, body) => {
  const response = await fetch(`${appium}${path}`, { method, headers: { 'content-type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  return response.json();
};
const created = await call('POST', '/session', {
  capabilities: {
    alwaysMatch: {
      platformName: 'iOS',
      'appium:automationName': 'XCUITest',
      'appium:udid': udid,
      'appium:bundleId': bundleId,
      'appium:wdaLocalPort': 8110,
      // The team WebDriverAgent is signed with: Appium builds and starts the runner itself (needs "Enable UI Automation" on the phone).
      'appium:xcodeOrgId': process.env.XCODE_ORG_ID,
      'appium:xcodeSigningId': 'Apple Development',
      // The first start of the runner can take longer than Appium's 60 s default.
      'appium:wdaLaunchTimeout': 240000,
      'appium:noReset': true,
      'appium:waitForIdleTimeout': 0,
    },
  },
});
const id = created.value?.sessionId;
if (!id) {
  console.error('no session:', JSON.stringify(created.value).slice(0, 300));
  process.exit(2);
}
const s = (method, path, body) => call(method, `/session/${id}${path}`, body);
const execute = (script) => s('POST', '/execute/sync', { script, args: [] }).then((r) => r.value);
const webContext = async () => {
  for (let i = 0; i < 10; i++) {
    const contexts = (await s('GET', '/contexts')).value ?? [];
    const web = contexts.find((c) => String(c).startsWith('WEBVIEW'));
    if (web) {
      await s('POST', '/context', { name: web });
      if ((await execute('return 1')) === 1) return web;
    }
    await sleep(1000);
  }
  throw new Error('no web view: is the demo a DEBUG build?');
};
const alertButtons = async () => {
  await s('POST', '/context', { name: 'NATIVE_APP' });
  const answer = await s('POST', '/execute/sync', { script: 'mobile: alert', args: [{ action: 'getButtons' }] });
  return Array.isArray(answer.value) ? answer.value : null;
};

// With IOS_INIT_ON_LOAD the Bluetooth permission prompt comes when the app starts: answer it first, by label ("Don't Allow"
// contains "Allow", so the match is a whole word).
const answerLaunchPrompt = async () => {
  for (let i = 0; i < 8; i++) {
    const buttons = await alertButtons();
    const allow = buttons?.find((b) => /^allow$/i.test(b.trim()));
    if (allow) {
      await s('POST', '/execute/sync', { script: 'mobile: alert', args: [{ action: 'accept', buttonLabel: allow }] });
      console.log('answered the launch permission prompt:', JSON.stringify(buttons));
      return;
    }
    await sleep(1000);
  }
};

let failed = null;
try {
  await answerLaunchPrompt();
  await webContext();
  await execute("window.results = []; document.getElementById('pair').click(); return 1");
  let buttons = null;
  for (let i = 0; i < 12 && !buttons; i++) {
    await sleep(1000);
    buttons = await alertButtons();
  }
  console.log('system alert after "Pair new device":', JSON.stringify(buttons));
  if (!buttons) throw new Error('the system accessory picker was never shown (and the call did not answer)');
  if (buttons.some((b) => /allow/i.test(b))) {
    throw new Error(`a permission prompt came instead of the picker: ${JSON.stringify(buttons)} - the launch prompt should have been answered before the call`);
  }
  if (!buttons.includes('Cancel')) throw new Error(`not the accessory picker: ${JSON.stringify(buttons)}`);
  await s('POST', '/execute/sync', { script: 'mobile: alert', args: [{ action: 'accept', buttonLabel: 'Cancel' }] });
  await sleep(1500);
  await webContext();
  const results = await execute("return JSON.stringify(window.results.map(function (r) { return r.call + ':' + r.kind + ' ' + JSON.stringify(r.value); }))");
  console.log('results after Cancel:', results);
  if (!JSON.parse(results).includes('discoverUnpaired:fail "Cancelled"')) throw new Error('Cancel did not answer "Cancelled"');
  console.log('OK: the picker was shown, and Cancel answered "Cancelled"');
} catch (error) {
  failed = error;
  console.error('FAIL:', error.message);
}
await s('DELETE', '');
process.exit(failed ? 1 : 0);
