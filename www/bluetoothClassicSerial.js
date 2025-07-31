/*global cordova*/
const exec = require('cordova/exec');

module.exports = {

  version: '1.0.0',

  connect: function (deviceId, interfaceArray, success, failure) {

    if (typeof interfaceArray === 'string') {
      interfaceArray = [interfaceArray];
    }

    exec(success, failure, "BluetoothClassicSerial", "connect", [deviceId, interfaceArray]);
  },

  // Android only - see http://goo.gl/1mFjZY
  connectInsecure: function (deviceId, interfaceArray, success, failure) {

    if (typeof interfaceArray === 'string') {
      interfaceArray = [interfaceArray];
    }

    exec(success, failure, "BluetoothClassicSerial", "connectInsecure", [deviceId, interfaceArray]);
  },

  disconnect: function (deviceId, interfaceId, success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "disconnect", [deviceId, interfaceId]);
  },

  disconnectAll: function (success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "disconnectAll", []);
  },

  // list bound devices
  list: function (success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "list", []);
  },

  isEnabled: function (success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "isEnabled", []);
  },

  isConnected: function (deviceId, interfaceId, success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "isConnected", [deviceId, interfaceId]);
  },

  // the number of bytes of data available to read is passed to the success function
  available: function (deviceId, interfaceId, success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "available", [deviceId, interfaceId]);
  },

  // read all the data in the buffer
  read: function (deviceId, interfaceId, success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "read", [deviceId, interfaceId]);
  },

  // reads the data in the buffer up to and including the delimiter
  readUntil: function (deviceId, interfaceId, delimiter, success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "readUntil", [deviceId, interfaceId, delimiter]);
  },

  // writes data to the bluetooth serial port
  // data can be an ArrayBuffer, string, integer array, or Uint8Array
  write: function (deviceId, interfaceId, data, success, failure) {

    // convert to ArrayBuffer
    if (typeof data === 'string') {
      data = stringToArrayBuffer(data);
    } else if (data instanceof Array) {
      // assuming an array of integer
      data = new Uint8Array(data).buffer;
    } else if (data instanceof Uint8Array) {
      data = data.buffer;
    }

    exec(success, failure, "BluetoothClassicSerial", "write", [deviceId, interfaceId, data]);
  },

  // calls the success callback when new data is available
  subscribe: function (deviceId, interfaceId, delimiter, success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "subscribe", [deviceId, interfaceId, delimiter]);
  },

  // removes data subscription
  unsubscribe: function (deviceId, interfaceId, success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "unsubscribe", [deviceId, interfaceId]);
  },

  // calls the success callback when new data is available with an ArrayBuffer
  subscribeRawData: function (deviceId, interfaceId, success, failure) {
    successWrapper = function (data) {

      // data = (typeof data === 'object') ? data : {};
      //
      // if (typeof data.rawDataB64 === 'string') {
      //   data.rawData = toByteArray(data.rawDataB64);
      // }

      success(data);
    };

    exec(successWrapper, failure, "BluetoothClassicSerial", "subscribeRaw", [deviceId, interfaceId]);
  },

  // removes data subscription
  unsubscribeRawData: function (deviceId, interfaceId, success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "unsubscribeRaw", [deviceId, interfaceId]);
  },

  // clears the data buffer
  clear: function (deviceId, interfaceId, success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "clear", [deviceId, interfaceId]);
  },

  showBluetoothSettings: function (success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "showBluetoothSettings", []);
  },

  enable: function (success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "enable", []);
  },

  discoverUnpaired: function (success, failure) {
    exec(success, failure, "BluetoothClassicSerial", "discoverUnpaired", []);
  },

  setDeviceDiscoveredListener: function (notify) {
    if (typeof notify != 'function')
      throw 'BluetoothClassicSerial.setDeviceDiscoveredListener: Callback not a function';

    exec(notify, null, "BluetoothClassicSerial", "setDeviceDiscoveredListener", []);
  },

  clearDeviceDiscoveredListener: function () {
    exec(null, null, "BluetoothClassicSerial", "clearDeviceDiscoveredListener", []);
  }

};

var stringToArrayBuffer = function (str) {
  var ret = new Uint8Array(str.length);
  for (var i = 0; i < str.length; i++) {
    ret[i] = str.charCodeAt(i);
  }
  return ret.buffer;
};
