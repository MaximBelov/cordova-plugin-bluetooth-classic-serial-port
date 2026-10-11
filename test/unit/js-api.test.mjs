// The JavaScript half of the plugin, run on Node with `cordova/exec` replaced by a recorder: every call has to reach native under the
// service, action and arguments native reads them by. Nothing here says whether native answers - that is tests/ and test/appium.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const Module = require('node:module');
const wrapper = fileURLToPath(new URL('../../www/bluetoothClassicSerial.js', import.meta.url));

/** The plugin's JavaScript, with a recorder where `cordova/exec` is; `calls` is what native would have been sent. */
function load() {
  const calls = [];
  const exec = (success, failure, service, action, args) => calls.push({ success, failure, service, action, args });
  const original = Module._load;
  Module._load = function (request, ...rest) {
    return request === 'cordova/exec' ? exec : original.call(this, request, ...rest);
  };
  try {
    delete require.cache[wrapper];
    return { api: require(wrapper), calls };
  } finally {
    Module._load = original;
  }
}

const ok = () => {};
const bad = () => {};

test('every method sends its action to the BluetoothClassicSerial service, with the arguments native reads', () => {
  const { api, calls } = load();
  const cases = [
    ['connect', ['dev', ['p']], 'connect', ['dev', ['p']]],
    ['connectInsecure', ['dev', ['p']], 'connectInsecure', ['dev', ['p']]],
    ['disconnect', ['dev', 'p'], 'disconnect', ['dev', 'p']],
    ['disconnectAll', [], 'disconnectAll', []],
    ['list', [], 'list', []],
    ['isEnabled', [], 'isEnabled', []],
    ['isConnected', ['dev', 'p'], 'isConnected', ['dev', 'p']],
    ['available', ['dev', 'p'], 'available', ['dev', 'p']],
    ['read', ['dev', 'p'], 'read', ['dev', 'p']],
    ['readUntil', ['dev', 'p', '\n'], 'readUntil', ['dev', 'p', '\n']],
    ['subscribe', ['dev', 'p', '\n'], 'subscribe', ['dev', 'p', '\n']],
    ['unsubscribe', ['dev', 'p'], 'unsubscribe', ['dev', 'p']],
    ['subscribeRawData', ['dev', 'p'], 'subscribeRaw', ['dev', 'p']],
    ['unsubscribeRawData', ['dev', 'p'], 'unsubscribeRaw', ['dev', 'p']],
    ['clear', ['dev', 'p'], 'clear', ['dev', 'p']],
    ['showBluetoothSettings', [], 'showBluetoothSettings', []],
    ['enable', [], 'enable', []],
    ['discoverUnpaired', [], 'discoverUnpaired', []],
    ['getBluetoothState', [], 'getBluetoothState', []],
  ];
  for (const [method, args, action, nativeArgs] of cases) {
    calls.length = 0;
    api[method](...args, ok, bad);
    assert.equal(calls.length, 1, `${method} reaches native once`);
    assert.equal(calls[0].service, 'BluetoothClassicSerial', `${method}: service`);
    assert.equal(calls[0].action, action, `${method}: action`);
    assert.deepEqual(calls[0].args, nativeArgs, `${method}: arguments`);
    if (method !== 'subscribeRawData') {
      assert.equal(calls[0].success, ok, `${method}: the caller's success callback`);
    }
    assert.equal(calls[0].failure, bad, `${method}: the caller's failure callback`);
  }
});

test('connect and connectInsecure take one protocol as a string and send it as a list', () => {
  const { api, calls } = load();
  api.connect('dev', 'com.acme.proto', ok, bad);
  api.connectInsecure('dev', 'com.acme.proto', ok, bad);
  assert.deepEqual(calls[0].args, ['dev', ['com.acme.proto']]);
  assert.deepEqual(calls[1].args, ['dev', ['com.acme.proto']]);
});

test('write turns a string, an integer array and a Uint8Array into an ArrayBuffer', () => {
  const { api, calls } = load();
  api.write('dev', 'p', 'AB', ok, bad);
  api.write('dev', 'p', [65, 66], ok, bad);
  api.write('dev', 'p', new Uint8Array([65, 66]), ok, bad);
  for (const call of calls) {
    assert.ok(call.args[2] instanceof ArrayBuffer, 'an ArrayBuffer');
    assert.deepEqual([...new Uint8Array(call.args[2])], [65, 66]);
  }
});

test('write hands an ArrayBuffer to native as it is', () => {
  const { api, calls } = load();
  const buffer = new Uint8Array([1, 2, 3]).buffer;
  api.write('dev', 'p', buffer, ok, bad);
  assert.equal(calls[0].args[2], buffer);
});

test('subscribeRawData passes the data on to the caller, and leaks no global', () => {
  const { api, calls } = load();
  let received;
  api.subscribeRawData('dev', 'p', (data) => (received = data), bad);
  calls[0].success({ bytes: 3 });
  assert.deepEqual(received, { bytes: 3 });
  assert.equal(globalThis.successWrapper, undefined, 'successWrapper is not a global');
});

test('setDeviceDiscoveredListener needs a function and has no failure callback', () => {
  const { api, calls } = load();
  assert.throws(() => api.setDeviceDiscoveredListener('nope'), /Callback not a function/);
  const notify = () => {};
  api.setDeviceDiscoveredListener(notify);
  assert.equal(calls[0].action, 'setDeviceDiscoveredListener');
  assert.equal(calls[0].success, notify);
  assert.equal(calls[0].failure, null);
});

test('clearDeviceDiscoveredListener sends no callbacks', () => {
  const { api, calls } = load();
  api.clearDeviceDiscoveredListener();
  assert.equal(calls[0].action, 'clearDeviceDiscoveredListener');
  assert.equal(calls[0].success, null);
  assert.equal(calls[0].failure, null);
});

test('the API is the one the README and the Ionic Native wrapper list', () => {
  const { api } = load();
  assert.deepEqual(Object.keys(api).sort(), [
    'available', 'clear', 'clearDeviceDiscoveredListener', 'connect', 'connectInsecure', 'disconnect', 'disconnectAll',
    'discoverUnpaired', 'enable', 'getBluetoothState', 'isConnected', 'isEnabled', 'list', 'read', 'readUntil',
    'setDeviceDiscoveredListener', 'showBluetoothSettings', 'subscribe', 'subscribeRawData', 'unsubscribe',
    'unsubscribeRawData', 'write',
  ]);
});
