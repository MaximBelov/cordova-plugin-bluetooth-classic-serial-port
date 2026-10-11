/* eslint-disable */
// What a phone can answer WITHOUT a person: the API is there, and the calls that raise no system dialog answer what they should.
// Two things stay out on purpose. The system accessory picker (iOS `discoverUnpaired`) is a dialog an automatic test cannot answer, and
// whether it is SHOWN is native's to say, not JavaScript's: test/appium/probe-accessory-picker.mjs watches the screen for it. And the Bluetooth
// permission prompt (raised when the plugin is created, which `IOS_INIT_ON_LOAD` moves to launch) would block an unattended run, so `isEnabled`
// runs only when the permission is already decided. Written for Jasmine 2 as cordova-plugin-test-framework runs it, in plain ES5.

exports.defineAutoTests = function () {
  var api = window.bluetoothClassicSerial;
  var platform = cordova.platformId;

  function failWith(done) {
    return function (error) {
      fail('the call was refused: ' + JSON.stringify(error));
      done();
    };
  }

  describe('bluetoothClassicSerial (window.bluetoothClassicSerial)', function () {
    it('is defined, with the whole API', function () {
      expect(api).toBeDefined();
      [
        'connect', 'connectInsecure', 'disconnect', 'disconnectAll', 'list', 'isEnabled', 'isConnected', 'available', 'read',
        'readUntil', 'write', 'subscribe', 'unsubscribe', 'subscribeRawData', 'unsubscribeRawData', 'clear',
        'showBluetoothSettings', 'enable', 'discoverUnpaired', 'getBluetoothState', 'setDeviceDiscoveredListener',
        'clearDeviceDiscoveredListener',
      ].forEach(function (name) {
        expect(typeof api[name]).toBe('function');
      });
    });
  });

  describe('getBluetoothState (iOS)', function () {
    it('says what iOS knows, and raises no permission prompt', function (done) {
      if (platform !== 'ios') {
        return pending('iOS only');
      }
      api.getBluetoothState(function (state) {
        expect(['notDetermined', 'restricted', 'denied', 'allowedAlways']).toContain(state.authorization);
        expect(Array.isArray(state.supportedProtocols)).toBe(true);
        expect(typeof state.connectedAccessories).toBe('number');
        expect(typeof state.systemVersion).toBe('string');
        // A second read is the same: asking for the state must not decide the permission.
        api.getBluetoothState(function (again) {
          expect(again.authorization).toBe(state.authorization);
          done();
        }, failWith(done));
      }, failWith(done));
    });
  });

  describe('list', function () {
    it('answers an array of devices, or says why it cannot (Android needs the Bluetooth permission)', function (done) {
      api.list(function (devices) {
        expect(Array.isArray(devices)).toBe(true);
        done();
      }, function (error) {
        expect(error).toBeDefined();
        done();
      });
    });
  });

  describe('isEnabled', function () {
    it('answers true or false, once Bluetooth is decided (iOS asks the user once: a manual test)', function (done) {
      function ask() {
        api.isEnabled(function (enabled) {
          expect(enabled).toBe(true);
          done();
        }, function (disabled) {
          expect(disabled).toBe(false);
          done();
        });
      }
      if (platform !== 'ios') {
        return ask();
      }
      api.getBluetoothState(function (state) {
        if (state.authorization === 'notDetermined') {
          return pending('the Bluetooth permission is not decided: its prompt would block an unattended run');
        }
        ask();
      }, failWith(done));
    });
  });

  describe('listeners', function () {
    it('setDeviceDiscoveredListener needs a function', function () {
      expect(function () {
        api.setDeviceDiscoveredListener('not a function');
      }).toThrow();
    });

    it('a listener can be set and cleared', function () {
      api.setDeviceDiscoveredListener(function () {});
      api.clearDeviceDiscoveredListener();
    });
  });

  describe('a session that was never opened', function () {
    it('isConnected says false for a device nothing connected to', function (done) {
      api.isConnected('no-such-device', 'io.github.maximbelov.none', function (connected) {
        expect(connected).toBe(false);
        done();
      }, function () {
        // a refusal is also an answer of "not connected"
        done();
      });
    });

    it('write to it is refused, not swallowed', function (done) {
      api.write('no-such-device', 'io.github.maximbelov.none', 'AB', function () {
        fail('a write to a device that is not connected was accepted');
        done();
      }, function (error) {
        expect(error).toBeDefined();
        done();
      });
    });
  });
};

exports.defineManualTests = function (contentEl, createActionButton) {
  var api = window.bluetoothClassicSerial;
  function show(text) {
    contentEl.insertAdjacentHTML('beforeend', '<pre>' + String(text).replace(/</g, '&lt;') + '</pre>');
  }

  createActionButton('Bluetooth state (iOS)', function () {
    api.getBluetoothState(function (s) { show(JSON.stringify(s)); }, function (e) { show('fail ' + JSON.stringify(e)); });
  });
  createActionButton('isEnabled', function () {
    api.isEnabled(function (v) { show('isEnabled ' + v); }, function (e) { show('isEnabled fail ' + JSON.stringify(e)); });
  });
  createActionButton('Pair new device: the system picker "Select An Accessory" must open; Cancel answers "Cancelled" (iOS)', function () {
    api.discoverUnpaired(function (v) { show('discoverUnpaired ok ' + JSON.stringify(v)); }, function (e) { show('discoverUnpaired fail ' + JSON.stringify(e)); });
  });
};
