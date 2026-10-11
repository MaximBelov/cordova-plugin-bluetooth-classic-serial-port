# Bluetooth Classic Serial Plugin for Cordova

This plugin enables serial communication over Bluetooth. 

It is a fork of https://github.com/don/BluetoothSerial and https://github.com/soltius/BluetoothClassicSerial.

This plugin is written using the [iOS Accessory Framework](https://developer.apple.com/documentation/externalaccessory/) (MFi) to support Classic Bluetooth on iOS.


## Supported Platforms

* Android
* iOS (devices must be MFi certified)
* Browser (Testing only. See [comments](https://github.com/MaximBelov/cordova-plugin-bluetooth-classic-serial-port/blob/main/src/browser/bluetoothClassicSerial.js).)

## Limitations

 * The phone must initiate the Bluetooth connection
 * Will *not* connect Android to Android (https://github.com/don/BluetoothSerial/issues/50#issuecomment-66405396)
 * Will *not* connect iOS to iOS

# Background Scanning on iOS

Android applications will continue to receive notification while the application is in the background.

iOS applications need additional configuration to allow Bluetooth to run in the background.

Add a new section to config.xml

    <platform name="ios">
        <config-file parent="UIBackgroundModes" target="*-Info.plist">
            <array>
                <string>external-accessory</string>
            </array>
        </config-file>
    </platform>

See [Documentation](https://developer.apple.com/documentation/bundleresources/information_property_list/uibackgroundmodes).

# Installing

Install with Cordova cli

    $ cordova plugin add cordova-plugin-bluetooth-classic-serial-port
    $ cordova plugin add https://github.com/MaximBelov/cordova-plugin-bluetooth-classic-serial-port.git


Install with Ionic

    $ ionic cordova plugin add cordova-plugin-bluetooth-classic-serial-port

Note that this plugin's id changed from 'cordova-plugin-bluetooth-serial' to 'cordova-plugin-bluetooth-classic-serial-port' as part of the fork.

## Plugin variables

All variables can be modified after installation by updating the values in `package.json`.

-   `BLUETOOTH_USAGE_DESCRIPTION`: [**iOS**] defines the values for [NSBluetoothAlwaysUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nsbluetoothalwaysusagedescription?language=objc).

-   `IOS_INIT_ON_LOAD`: [**iOS**] Prevents the Bluetooth plugin from being initialised until first access to the `bluetoothClassicSerial` window object. This allows an application to warn the user before the Bluetooth access permission is requested.

## Android permission

To include the default set of permissions the plugin installs on Android SDK v33+, add the following snippet in your `config.xml` file, in the `<platform name="android">` section:

```xml
    <config-file target="AndroidManifest.xml" parent="/manifest">
        <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" android:maxSdkVersion="28" />
        <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="34" />
        <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
        <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
        <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="33" />
        <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="33" />
    </config-file>
```

For the best understanding about which permissions are needed for which combinations of target SDK version & OS version, see [Android Bluetooth permissions](https://developer.android.com/guide/topics/connectivity/bluetooth/permissions)

## Ionic Production

    $ npm i @awesome-cordova-plugins/bluetooth-classic-serial-port

## Ionic Development

    $ npm i @awesome-cordova-plugins-hotfix/bluetooth-classic-serial-port

## iOS Notes

iOS requires that the device's protocol string is in the p-list.  

### Examples

Replace the text 'first.device.protocol.string' with the protocol string for the Bluetooth accessory you are connecting to. 
Create a new line for each protocol string.  
Some devices may have more than one.  
The plugin only allows for connection to one device and one protocol.  
If you need to connect to another, disconnect, then connect to the required device and protocol.

#### Cordova Command Line config.xml entry for Supported Accessories

```xml
<platform name="ios">
    <config-file target="*-Info.plist" parent="UISupportedExternalAccessoryProtocols">
        <array>
            <string>first.device.protocol.string</string>
            <string>second.device.protocol.string</string>
         </array>
    </config-file>
</platform>
```


## iOS: Pair new device and the system picker

The iOS side is built and tested for iOS 16 and later (the minimum of the test package and of the demo app).

`discoverUnpaired` opens iOS's own "Select An Accessory" popup. It needs no Bluetooth permission and no MFi accessory nearby to open. It answers the list of connected accessories when the user picks one, and fails with `"Cancelled"`, `"Device not found"` or `"Device selection failed"` otherwise. A second call while the popup is up ends the first one with `"Cancelled"` (iOS does that).

iOS presents the popup in the application delegate's `window`. Cordova's `CDVAppDelegate` has that property and an app on scenes (cordova-ios 8) never sets it, so the popup was never shown and the call never answered. The plugin hands the delegate the key window before the call when it has the property and it is `nil`.

The Bluetooth permission prompt is raised when the plugin is created. With the default `IOS_INIT_ON_LOAD=false` that is the first call of any method, and a prompt that is up when the popup is asked for swallows the request, so the first `discoverUnpaired` of a fresh install can end without a popup. Set `IOS_INIT_ON_LOAD` to `true` and the prompt comes when the app starts instead.

# Development

`demo/` is a small Cordova app with one button per call and the answer on screen. `npm run test:unit` runs the JavaScript half on Node, with no phone: the API calls, and the automatic tests of `tests/` against a fake native. On a simulator, an emulator or a phone:

    npm run test:paramedic:ios:simulator    # IOS_SIMULATOR=<name> to pick one; no phone needed: the calls that need no Bluetooth answer on a simulator too
    npm run test:paramedic:ios:device       # with HW_IOS_UDID=<udid> to pick the phone
    npm run test:paramedic:android          # with ANDROID_SERIAL=<serial>; an emulator that is running has one too (emulator-5554), and CI does exactly that
    npm run test:paramedic:android:emulator # with ANDROID_AVD=<name>
    HW_IOS_UDID=<udid> XCODE_ORG_ID=<team id> npm run test:appium:ios   # starts and stops its own Appium server
    npm run test:ios                        # the Objective-C on an iOS simulator, with XCTest: no phone, no Bluetooth
    npm run test:android                    # the Java on the JVM, with Robolectric (Gradle): no emulator, no Bluetooth
    npm run test:unit:coverage              # also test:ios:coverage and test:android:coverage: the line coverage of each layer, against its floor

The first two run the tests in `tests/` with cordova-paramedic (on iOS they need your signing in `demo/build.local.json`: copy `demo/build.json` and put your Apple team id in it; the copy is not tracked). The last one presses "Pair new device" in the demo on a clean install and looks for the system popup, which JavaScript cannot see.

`npm run test:ios` builds `src/ios` against cordova-ios (`test/ios` is a Swift package whose source is a link to it) and runs the XCTest cases there: the messages `discoverUnpaired` answers for each picker result, that it answers every time, and the hand-over of the window to the application delegate. The picker itself is faked there, so whether it really shows is still the Appium probe's to say.

On an iPhone the paramedic app is installed fresh each run, so iOS asks two things that a person has to answer with Allow while the run waits: the Bluetooth permission (raised when the plugin is created, on the first call) and the local network permission (the app talks to the test server on your computer). With the permission undecided, the `isEnabled` test is skipped rather than raising a third prompt of its own.

`npm run test:android` builds `src/android` against cordova-android's framework (`test/android` is a small Gradle project whose source directory is `src/android`) and runs Robolectric tests on the JVM: how the plugin dispatches its actions, what it answers about a device nothing is connected to, how the adapter's state and the Bluetooth permissions turn into answers. A connection itself needs a phone.

The coverage of each layer is measured with the tool of its platform (Node's own for the JavaScript, JaCoCo for the Java, llvm-cov for the Objective-C) and compared with a floor in `test/coverage/floors.json`. A floor is not a target: the Android and iOS tests run without a device, so the code that talks to Bluetooth (the connection threads and sessions) is mostly out of their reach, and the floors hold what is measured, so coverage cannot fall without somebody choosing to lower them. CI prints the numbers in the summary of each job and keeps the reports.

`test/unit/platform-parity.test.mjs` keeps the platforms and the README in step: every JavaScript method has its action on Android and on iOS except those written down in the test (`connectInsecure`, `available`, `showBluetoothSettings` and `enable` are Android only, `getBluetoothState` is iOS only), and the README has a section and an index entry for each method and says what a platform lacks. It runs first in CI, before the longer tests.

To try the plugin as it is on disk in the demo: `cd demo && npm install && npm run ios:prepare && npm run ios:build`.

# Examples

# API

## Methods

- [bluetoothClassicSerial.connect](#connect)
- [bluetoothClassicSerial.connectInsecure](#connectInsecure)
- [bluetoothClassicSerial.disconnect](#disconnect)
- [bluetoothClassicSerial.disconnectAll](#disconnectAll)
- [bluetoothClassicSerial.write](#write)
- [bluetoothClassicSerial.available](#available)
- [bluetoothClassicSerial.read](#read)
- [bluetoothClassicSerial.readUntil](#readuntil)
- [bluetoothClassicSerial.subscribe](#subscribe)
- [bluetoothClassicSerial.unsubscribe](#unsubscribe)
- [bluetoothClassicSerial.subscribeRawData](#subscriberawdata)
- [bluetoothClassicSerial.unsubscribeRawData](#unsubscriberawdata)
- [bluetoothClassicSerial.clear](#clear)
- [bluetoothClassicSerial.list](#list)
- [bluetoothClassicSerial.isEnabled](#isenabled)
- [bluetoothClassicSerial.isConnected](#isconnected)
- [bluetoothClassicSerial.showBluetoothSettings](#showbluetoothsettings)
- [bluetoothClassicSerial.enable](#enable)
- [bluetoothClassicSerial.discoverUnpaired](#discoverunpaired)
- [bluetoothClassicSerial.getBluetoothState](#getbluetoothstate)
- [bluetoothClassicSerial.setDeviceDiscoveredListener](#setdevicediscoveredlistener)
- [bluetoothClassicSerial.clearDeviceDiscoveredListener](#cleardevicediscoveredlistener)

| Method | Android | iOS |
| --- | --- | --- |
| `connect`, `disconnect`, `disconnectAll`, `write`, `read`, `readUntil`, `subscribe`, `unsubscribe`, `subscribeRawData`, `unsubscribeRawData`, `clear`, `list`, `isEnabled`, `isConnected`, `discoverUnpaired`, `setDeviceDiscoveredListener`, `clearDeviceDiscoveredListener` | yes | yes |
| `connectInsecure`, `available`, `showBluetoothSettings`, `enable` | yes | **no** |
| `getBluetoothState` | **no** | yes |

A method a platform does not have is answered differently on each: Android calls the failure callback with an invalid action error, while on iOS Cordova only logs `Method ... not defined in Plugin` and calls **neither** callback, so a call to one of them never answers.


## connect

Connect to a Bluetooth device.

    bluetoothClassicSerial.connect(deviceId, interfaceIdArray, connectSuccess, connectFailure);

### Description

Function `connect` connects to a Bluetooth device.  The callback is long running.  Success will be called when the connection is successful.  Failure is called if the connection fails, or later if the connection disconnects. An error message is passed to the failure callback.  
If a device has multiple interfaces then you can connect to them by providing the interface Ids.

### Parameters

- __connectSuccess__: Success callback function that is invoked when the connection is successful.
- __connectFailure__: Error callback function, invoked when error occurs or the connection disconnects.

#### Android

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceIdArray__: This identifies the serial port to connect to. For Android this is the SPP_UUID. A common SPP_UUID string is "00001101-0000-1000-8000-00805F9B34FB".  The device documentation should provide the SPP_UUID.

#### iOS

- __deviceId__: For iOS this is the connection ID
- __interfaceIdArray__: This identifies the serial port to connect to. For iOS the interfaceId is the Protocol String. The Protocol String must be one of those specified in your config.xml.

For iOS, `connect` takes the ConnectionID as the deviceID, and the Protocol String as the interfaceId.

## connectInsecure

Connect insecurely to a Bluetooth device.
```
bluetoothClassicSerial.connectInsecure(deviceId, interfaceIdArray, connectSuccess, connectFailure);
```

### Description

Function `connectInsecure` works like [connect](#connect), but creates an insecure connection to a Bluetooth device.  See the [Android docs](http://goo.gl/1mFjZY) for more information.

#### Android

For Android, see [connect](#connect).

#### iOS

`connectInsecure` is **not supported**. The iOS plugin has no such method: Cordova logs an error and calls neither callback.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceIdArray__: This identifies the serial port to connect to. For Android this is the SPP_UUID. A common SPP_UUID string is "00001101-0000-1000-8000-00805F9B34FB".  The device documentation should provide the SPP_UUID.
- __connectSuccess__: Success callback function that is invoked when the connection is successful.
- __connectFailure__: Error callback function, invoked when error occurs or the connection disconnects.

## disconnect
```
bluetoothClassicSerial.disconnect(deviceId, interfaceId, success, failure);
```

### Description

Function `disconnect` disconnects the current connection.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to disconnect
- __success__: Success callback function that is invoked when the connection is successful. [optional]
- __failure__: Error callback function, invoked when error occurs. [optional]


## disconnectAll
```
bluetoothClassicSerial.disconnectAll(success, failure);
```

### Description

Function `disconnectAll` disconnects all connections.

### Parameters

- __success__: Success callback function that is invoked when the disconnection is successful. [optional]
- __failure__: Error callback function, invoked when error occurs. [optional]

## write

Writes data to the serial port.
```
bluetoothClassicSerial.write(deviceId, interfaceId, data, success, failure);
```

### Description

Function `write` data to the serial port. Data can be an ArrayBuffer, string, array of integers, or a Uint8Array.

Internally string, integer array, and Uint8Array are converted to an ArrayBuffer. String conversion assume 8bit characters.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to send the data to
- __data__: ArrayBuffer of data
- __success__: Success callback function that is invoked when the connection is successful. [optional]
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
// string
bluetoothClassicSerial.write(deviceId, "00001101-0000-1000-8000-00805F9B34FB", "hello, world", success, failure);

// array of int (or bytes)
bluetoothClassicSerial.write(deviceId, "00001101-0000-1000-8000-00805F9B34FB", [186, 220, 222], success, failure);

// Typed Array
var data = new Uint8Array(4);
data[0] = 0x41;
data[1] = 0x42;
data[2] = 0x43;
data[3] = 0x44;
bluetoothClassicSerial.write(deviceId, interfaceId, data, success, failure);

// Array Buffer
bluetoothClassicSerial.write(deviceId, interfaceId, data.buffer, success, failure);
```

## available

Gets the number of bytes of data available.
```
bluetoothClassicSerial.available(deviceId, interfaceId, success, failure);
```

### Description

Function `available` gets the number of bytes of data available.  The bytes are passed as a parameter to the success callback.

#### iOS

`available` is **not supported**. The iOS plugin has no such method: Cordova logs an error and calls neither callback.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to check
- __success__: Success callback function that is invoked when the connection is successful. [optional]
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
bluetoothClassicSerial.available(deviceid, "00001101-0000-1000-8000-00805F9B34FB", function (numBytes) { console.log("There are " + numBytes + " available to read."); }, failure);
```

## read

Reads data from the buffer.
```
bluetoothClassicSerial.read(deviceId, interfaceId, success, failure);
```

### Description

Function `read` reads the data from the buffer. The data is passed to the success callback as a String.  Calling `read` when no data is available will pass an empty String to the callback.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to read
- __success__: Success callback function that is invoked with the number of bytes available to be read.
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
bluetoothClassicSerial.read(deviceId, "00001101-0000-1000-8000-00805F9B34FB", function (data) { console.log(data);}, failure);
```

## readUntil

Reads data from the buffer until it reaches a delimiter.

    bluetoothClassicSerial.readUntil(deviceId, interfaceId, '\n', success, failure);


### Description

Function `readUntil` reads the data from the buffer until it reaches a delimiter.  The data is passed to the success callback as a String.  If the buffer does not contain the delimiter, an empty String is passed to the callback. Calling `read` when no data is available will pass an empty String to the callback.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to read
- __delimiter__: delimiter
- __success__: Success callback function that is invoked with the data.
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
    bluetoothClassicSerial.readUntil(deviceId, "00001101-0000-1000-8000-00805F9B34FB", '\n', function (data) {console.log(data);}, failure);
```

## subscribe

Subscribe to be notified when data is received.

    bluetoothClassicSerial.subscribe(deviceId, interfaceId, '\n', success, failure);

### Description

Function `subscribe` registers a callback that is called when data is received.  A delimiter must be specified.  The callback is called with the data as soon as the delimiter string is read.  The callback is a long running callback and will exist until `unsubscribe` is called.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to subscribe to
- __delimiter__: delimiter
- __success__: Success callback function that is invoked with the data.
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
// the success callback is called whenever data is received
bluetoothClassicSerial.subscribe(deviceId, "00:AA:DD:DD:1A:2D", '\n', function (data) {
    console.log(data);
}, failure);
```

## unsubscribe

Unsubscribe from a subscription.

    bluetoothClassicSerial.unsubscribe(deviceId, interfaceId, success, failure);

### Description

Function `unsubscribe` removes any notification added by `subscribe` and kills the callback.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to unsubscribe from
- __success__: Success callback function that is invoked when the connection is successful. [optional]
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example

    bluetoothClassicSerial.unsubscribe(deviceId, interfaceId, console.log, console.error);

## subscribeRawData

Subscribe to be notified when data is received.

    bluetoothClassicSerial.subscribeRawData(deviceId, interfaceId, success, failure);

### Description

Function `subscribeRawData` registers a callback that is called when data is received. The callback is called immediately when data is received. The data is sent to callback as an ArrayBuffer. The callback is a long running callback and will exist until `unsubscribeRawData` is called.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to subscribe to
- __success__: Success callback function that is invoked with the data.
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
// the success callback is called whenever data is received
bluetoothClassicSerial.subscribeRawData(deviceId, interfaceId, function (data) {
    var bytes = new Uint8Array(data);
    console.log(bytes);
}, failure);
```

## unsubscribeRawData

Unsubscribe from a subscription.

    bluetoothClassicSerial.unsubscribeRawData(deviceId, interfaceId, success, failure);

### Description

Function `unsubscribeRawData` removes any notification added by `subscribeRawData` and kills the callback.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to unsubscribe from
- __success__: Success callback function that is invoked when the unsubscribe is successful. [optional]
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
bluetoothClassicSerial.unsubscribeRawData(deviceId, "00001101-0000-1000-8000-00805F9B34FB");
```

## clear

Clears data in the buffer.

    bluetoothClassicSerial.clear(deviceId, interfaceId, success, failure);

### Description

Function `clear` removes any data from the receive buffer.

### Parameters

- __success__: Success callback function that is invoked when the connection is successful. [optional]
- __failure__: Error callback function, invoked when error occurs. [optional]

## list

Lists bonded devices

    bluetoothClassicSerial.list(success, failure);

### Description

#### Android

Function `list` lists the paired Bluetooth devices.  The success callback is called with a list of objects.

Example list passed to success callback.  See [BluetoothDevice](http://developer.android.com/reference/android/bluetooth/BluetoothDevice.html#getName\(\)) and [BluetoothClass#getDeviceClass](http://developer.android.com/reference/android/bluetooth/BluetoothClass.html#getDeviceClass\(\)).

    [{
        "class": 276,
        "id": "10:BF:48:CB:00:00",
        "address": "10:BF:48:CB:00:00",
        "name": "Device SPP"
    }, {
        "class": 7936,
        "id": "00:06:66:4D:00:00",
        "address": "00:06:66:4D:00:00",
        "name": "ESP32 Bluetooth classic"
    }]

#### iOS

Function `list` lists the paired Bluetooth devices.  The success callback is called with a list of objects.

Example list passed to success callback for iOS.

    [{
        "id": 12345,
        "address": 12345,
        "class": "",
        "manufacturer": "Manufacturer 1",
        "name": "MFI Device",
        "modelNumber": "ABC123",
        "serialNumber": "ABC123",
        "firmwareRevision": "ABC",
        "hardwareRevision": "ABC",
        "protocols": [ "com.string.protocol" ]
    }]

### Note

`id` is the generic name for `connection Id` or [mac]`address` so that code can be platform independent.

### Parameters

- __success__: Success callback function that is invoked with a list of bonded devices.
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
bluetoothClassicSerial.list(function(devices) {
    devices.forEach(function(device) {
        console.log(device.id, device);
    })
}, failure);
```

## isConnected

Reports the connection status.  If all interfaces are connected then the success callback is called.  If one interface is not connected then the failure callback is called.  The connect method does not allow the status of a single interface to be determined (unless you have only specified a single interfaceId in the prior connect method).

    bluetoothClassicSerial.isConnected(deviceId, interfaceId, success, failure);

### Description

Function `isConnected` calls the success callback when connected to a peer and the failure callback when *not* connected.

### Parameters

- __deviceId__: Identifier of the remote device. For Android this is the MAC address.
- __interfaceId__: The interface to unsubscribe from
- __success__: Success callback function, invoked when device connected.
- __failure__: Error callback function, invoked when device is NOT connected.

### Quick Example
```
bluetoothClassicSerial.isConnected(
    deviceId, 
    interfaceId,
    function() {
        console.log("Bluetooth is connected");
    },
    function() {
        console.log("Bluetooth is *not* connected");
    }
);
```

## isEnabled

Reports if bluetooth is enabled.

    bluetoothClassicSerial.isEnabled(success, failure);

### Description

Function `isEnabled` calls the success callback when bluetooth is enabled and the failure callback when bluetooth is *not* enabled.

### Parameters

- __success__: Success callback function, invoked when Bluetooth is enabled.
- __failure__: Error callback function, invoked when Bluetooth is NOT enabled.

### Quick Example
```
bluetoothClassicSerial.isEnabled(
    function() {
        console.log("Bluetooth is enabled");
    },
    function() {
        console.log("Bluetooth is *not* enabled");
    }
);
```

## showBluetoothSettings

Show the Bluetooth settings on the device.

    bluetoothClassicSerial.showBluetoothSettings(success, failure);

### Description

Function `showBluetoothSettings` opens the Bluetooth settings on the operating systems.

#### iOS

`showBluetoothSettings` is not supported. The iOS plugin has no such method: Cordova logs an error and calls neither callback.

### Parameters

- __success__: Success callback function [optional]
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
bluetoothClassicSerial.showBluetoothSettings();
```

## enable

Enable Bluetooth on the device.

    bluetoothClassicSerial.enable(success, failure);

### Description

Function `enable` prompts the user to enable Bluetooth. If `enable` is called when Bluetooth is already enabled, the user will not prompted and the success callback will be invoked.

#### iOS

`enable` is **not supported**. The iOS plugin has no such method: Cordova logs an error and calls neither callback.

`enable` is only supported on Android and does not work on iOS.

If `enable` is called when Bluetooth is already enabled, the user will not prompted and the success callback will be invoked.

### Parameters

- __success__: Success callback function, invoked if the user enabled Bluetooth.
- __failure__: Error callback function, invoked if the user does not enabled Bluetooth.

### Quick Example
```
bluetoothClassicSerial.enable(
    function() {
        console.log("Bluetooth is enabled");
    },
    function() {
        console.log("The user did *not* enable Bluetooth");
    }
);
```

## discoverUnpaired

Discover unpaired devices

    bluetoothClassicSerial.discoverUnpaired(success, failure);

### Description

The behaviour of this method varies between Android and iOS.

#### Android

Function `discoverUnpaired` discovers unpaired Bluetooth devices. The success callback is called with a list of objects similar to `list`, or an empty list if no unpaired devices are found.

Example list passed to success callback.
```
[{
    "class": 276,
    "id": "10:BF:48:CB:00:00",
    "address": "10:BF:48:CB:00:00",
    "name": "Nexus 7"
}, {
    "class": 7936,
    "id": "00:06:66:4D:00:00",
    "address": "00:06:66:4D:00:00",
    "name": "RN42"
}]
```

The discovery process takes a while to happen. You can register notify callback with [setDeviceDiscoveredListener](#setdevicediscoveredlistener).
You may also want to show a progress indicator while waiting for the discover process to finish, and the success callback to be invoked.

Calling `connect` on an unpaired Bluetooth device should begin the Android pairing process.

#### iOS

Function `discoverUnpaired` will launch a native iOS window showing all devices which match the protocol string defined in the application's cordova config.xml file.  Choosing a device from the list will initiate pairing and the details of that device will **not** trigger the success callback function. **The device discovered listener must be used**. Once paired the device is available for connection.

### Parameters

- __success__: Success callback function that is invoked with a list of unpaired devices.
- __failure__: Error callback function, invoked when error occurs. [optional]

### Quick Example
```
bluetoothClassicSerial.discoverUnpaired(function(devices) {
    devices.forEach(function(device) {
        console.log(device.id, device);
    })
}, failure);
```

## getBluetoothState

What iOS knows about Bluetooth for this app, without asking for anything.

    bluetoothClassicSerial.getBluetoothState(success, failure);

### Description

Function `getBluetoothState` answers an object, and never raises the Bluetooth permission prompt:

    {
      authorization: "notDetermined" | "restricted" | "denied" | "allowedAlways" | "unknown",
      supportedProtocols: ["com.acme.proto"],   // UISupportedExternalAccessoryProtocols of the app
      connectedAccessories: 0,
      systemVersion: "26.6"
    }

An app can use it to see whether the permission is decided before it calls something that would raise the prompt.

#### Android

`getBluetoothState` is **not supported**. The plugin has no such action, so Cordova calls the failure callback with an invalid action error.

### Parameters

- __success__: Success callback function that is invoked with the object above.
- __failure__: Error callback function, invoked when error occurs. [optional]

## setDeviceDiscoveredListener

### Description

Register a notify callback function to be called during bluetooth device discovery.

#### Android

Register a notify callback function to be called during bluetooth device discovery. For callback to work, discovery process must
be started with [discoverUnpaired](#discoverunpaired).
There can be only one registered callback.

Example object passed to notify callback.
```
{
    "class": 276,
    "id": "10:BF:48:CB:00:00",
    "address": "10:BF:48:CB:00:00",
    "name": "Nexus 7"
}
```

#### iOS

When a device is paired from the [discoverUnpaired](#discoverunpaired) function it's details will be passed to the callback function.  Unlike Android this will only be fired once for the selected device, not for all the available devices.

### Parameters

- __notify__: Notify callback function invoked when a device is discovered during a discovery process.

### Quick Example
```
bluetoothClassicSerial.setDeviceDiscoveredListener(function(device) {
  console.log('Found: ',device.id);
});
```

## clearDeviceDiscoveredListener

Clears notify callback function registered with [setDeviceDiscoveredListener](#setdevicediscoveredlistener).

### Quick Example
```
bluetoothClassicSerial.clearDeviceDiscoveredListener();
```

# Misc

## Where does this work?

### Android

Development Devices include
 * Samsung A04 with Android 14

### iOS

Development Devices include
  * iPhone 11-16

## Props

This project is a fork of Don Coleman's https://github.com/don/BluetoothSerial so all the big props to him.

The multi-interface implementation for Android borrowed ideas from Shikoruma's pull request https://github.com/don/BluetoothSerial/pull/205 to Don Coleman's [Cordova BluetoothSerial Plugin](https://github.com/don/BluetoothSerial).

### Android

Most of the Bluetooth implementation was borrowed from the Bluetooth Chat example in the Android SDK.

### iOS

### API

The API for available, read, readUntil was influenced by the [BtSerial Library for Processing for Arduino](https://github.com/arduino/BtSerial)

## Wrong Bluetooth Plugin?

If you need generic Bluetooth Low Energy support checkout Don Colemans's [Cordova BLE Plugin](https://github.com/don/cordova-plugin-ble-central).

If you need BLE for RFduino checkout Don Colemans's [RFduino Plugin](https://github.com/don/cordova-plugin-rfduino).

For Windows Phone 8 support see the original project, Don Coleman's [Cordova BluetoothSerial Plugin](https://github.com/don/BluetoothSerial)

## What format should the Mac Address be in?
An example a properly formatted mac address is "AA:BB:CC:DD:EE:FF"

## Feedback

Try the code. If you find a problem or missing feature, file an issue or create a pull request.
