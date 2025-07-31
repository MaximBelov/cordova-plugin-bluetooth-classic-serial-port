package nz.co.soltius.cordova;

import android.content.pm.PackageManager;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Handler;
import android.os.Message;
import android.provider.Settings;
import android.util.Log;
import android.os.Build;

import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;
import org.apache.cordova.LOG;
import org.apache.cordova.PermissionHelper;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Iterator;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;

/**
 * Cordova Plugin for Serial Communication over Bluetooth
 */
public class BluetoothClassicSerial extends CordovaPlugin {

    // permissions
    private static final String ACCESS_BACKGROUND_LOCATION = "android.permission.ACCESS_BACKGROUND_LOCATION"; // API 29
    private static final String BLUETOOTH_CONNECT = "android.permission.BLUETOOTH_CONNECT"; // API 31
    private static final String BLUETOOTH_SCAN = "android.permission.BLUETOOTH_SCAN"; // API 31
    private static final String ACCESS_FINE_LOCATION = "android.permission.ACCESS_FINE_LOCATION"; // API 30
    private static final String ACCESS_COARSE_LOCATION = "android.permission.ACCESS_COARSE_LOCATION"; // API 29

    // actions
    private static final String LIST = "list";
    private static final String CONNECT = "connect";
    private static final String CONNECT_INSECURE = "connectInsecure";
    private static final String DISCONNECT = "disconnect";
    private static final String DISCONNECT_ALL = "disconnectAll";
    private static final String WRITE = "write";
    private static final String AVAILABLE = "available";
    private static final String READ = "read";
    private static final String READ_UNTIL = "readUntil";
    private static final String SUBSCRIBE = "subscribe";
    private static final String UNSUBSCRIBE = "unsubscribe";
    private static final String SUBSCRIBE_RAW = "subscribeRaw";
    private static final String UNSUBSCRIBE_RAW = "unsubscribeRaw";
    private static final String IS_ENABLED = "isEnabled";
    private static final String IS_CONNECTED = "isConnected";
    private static final String CLEAR = "clear";
    private static final String SETTINGS = "showBluetoothSettings";
    private static final String ENABLE = "enable";
    private static final String DISCOVER_UNPAIRED = "discoverUnpaired";
    private static final String SET_DEVICE_DISCOVERED_LISTENER = "setDeviceDiscoveredListener";
    private static final String CLEAR_DEVICE_DISCOVERED_LISTENER = "clearDeviceDiscoveredListener";

    private CallbackContext enableBluetoothCallback;
    private CallbackContext deviceDiscoveredCallback;

    private BluetoothAdapter bluetoothAdapter;

    // Debugging
    private static final String TAG = "BluetoothClassicSerial";
    private static final boolean D = true;

    // Message types sent from the BluetoothClassicSerialService Handler
    public static final int MESSAGE_STATE_CHANGE = 1;
    public static final int MESSAGE_READ = 2;
    public static final int MESSAGE_WRITE = 3;
    public static final int MESSAGE_DEVICE_NAME = 4;
    public static final int MESSAGE_TOAST = 5;
    public static final int MESSAGE_READ_RAW = 6;
    public static final int MESSAGE_FAILED = 7;

    // Key names received from the BluetoothChatService Handler
    public static final String DEVICE_NAME = "device_name";
    public static final String TOAST = "toast";

    private static final int REQUEST_ENABLE_BLUETOOTH = 1;
    private static final int REQUEST_LIST_BONDED_DEVICES = 2;
    private static final int REQUEST_LIST_UNPAIRED_DEVICES = 3;
    private CallbackContext permissionCallback;

    //Container for interfaces (Index = interfaceID)
    private final HashMap<String, InterfaceContext> connections = new HashMap<String, InterfaceContext>();

    private static int COMPILE_SDK_VERSION = -1;

    @Override
    protected void pluginInitialize() {
        if (COMPILE_SDK_VERSION == -1) {
            Context context = cordova.getContext();
            COMPILE_SDK_VERSION = context.getApplicationContext().getApplicationInfo().targetSdkVersion;
        }
    }

    @Override
    public boolean execute(String action, CordovaArgs args, CallbackContext callbackContext) throws JSONException {

        LOG.d(TAG, "action = " + action);

        if (bluetoothAdapter == null) {
            bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        }


        boolean validAction = true;

        if (action.equals(LIST)) {

            listBondedDevices(callbackContext);

        } else if (action.equals(CONNECT)) {

            connect(args, true, callbackContext);

        } else if (action.equals(CONNECT_INSECURE)) {

            // see Android docs about Insecure RFCOMM http://goo.gl/1mFjZY
            connect(args, false, callbackContext);

        } else if (action.equals(DISCONNECT)) {

            disconnect(args, callbackContext);

        } else if (action.equals(DISCONNECT_ALL)) {

            disconnectAll(callbackContext);

        } else {
            if (action.equals(WRITE)) {

                String macAddress = args.getString(0);
                byte[] data = args.getArrayBuffer(2);

                InterfaceContext ic = getInterfaceContext(macAddress);

                if (ic != null) {
                    ic.bluetoothClassicSerialService.write(data);
                    callbackContext.success();
                } else {
                    callbackContext.error("No Interface");
                }

            } else if (action.equals(AVAILABLE)) {

                String macAddress = args.getString(0);
                InterfaceContext ic = getInterfaceContext(macAddress);
                int available = 0;

                if (ic != null) {
                    available = ic.available();
                }

                callbackContext.success(available);

            } else if (action.equals(READ)) {

                String macAddress = args.getString(0);
                InterfaceContext ic = getInterfaceContext(macAddress);
                String data = "";

                if (ic != null) {
                    data = ic.read();
                }
                callbackContext.success(data);

            } else if (action.equals(READ_UNTIL)) {

                String macAddress = args.getString(0);
                String delimiter = args.getString(2);
                String readText = "";
                InterfaceContext ic;

                ic = getInterfaceContext(macAddress);

                if (ic != null) {
                    readText = ic.readUntil(delimiter);
                }

                callbackContext.success(readText);

            } else if (action.equals(SUBSCRIBE)) {

                String macAddress = args.getString(0);
                String delimiter = args.getString(2);

                setContextSubscribe(macAddress, callbackContext, delimiter);
                PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
                result.setKeepCallback(true);
                callbackContext.sendPluginResult(result);

            } else if (action.equals(UNSUBSCRIBE)) {

                String macAddress = args.getString(0);

                setContextSubscribe(macAddress, null, null);

                callbackContext.success();

            } else if (action.equals(SUBSCRIBE_RAW)) {

                String macAddress = args.getString(0);

                setContextRawSubscribe(macAddress, callbackContext);

                PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
                result.setKeepCallback(true);
                callbackContext.sendPluginResult(result);

            } else if (action.equals(UNSUBSCRIBE_RAW)) {

                String macAddress = args.getString(0);
                setContextRawSubscribe(macAddress, null);

                callbackContext.success();

            } else if (action.equals(IS_ENABLED)) {

                isEnabled(callbackContext);

            } else if (action.equals(IS_CONNECTED)) {

                isConnected(args, callbackContext);

            } else if (action.equals(CLEAR)) {

                String macAddress = args.getString(0);
                InterfaceContext ic;

                ic = getInterfaceContext(macAddress);
                if (ic != null) {
                    ic.clearBuffer();
                }

                callbackContext.success();

            } else if (action.equals(SETTINGS)) {

                Intent intent = new Intent(Settings.ACTION_BLUETOOTH_SETTINGS);
                cordova.getActivity().startActivity(intent);
                callbackContext.success();

            } else if (action.equals(ENABLE)) {

                enableBluetoothCallback = callbackContext;
                Intent intent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
                cordova.startActivityForResult(this, intent, REQUEST_ENABLE_BLUETOOTH);

            } else if (action.equals(DISCOVER_UNPAIRED)) {

                discoverUnpairedDevices(callbackContext);

            } else if (action.equals(SET_DEVICE_DISCOVERED_LISTENER)) {

                this.deviceDiscoveredCallback = callbackContext;

            } else if (action.equals(CLEAR_DEVICE_DISCOVERED_LISTENER)) {

                this.deviceDiscoveredCallback = null;

            } else {
                validAction = false;

            }
        }

        return validAction;
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {

        if (requestCode == REQUEST_ENABLE_BLUETOOTH) {

            if (resultCode == Activity.RESULT_OK) {
                Log.d(TAG, "User enabled Bluetooth");
                if (enableBluetoothCallback != null) {
                    enableBluetoothCallback.success();
                }
            } else {
                Log.d(TAG, "User did *NOT* enable Bluetooth");
                if (enableBluetoothCallback != null) {
                    enableBluetoothCallback.error("User did not enable Bluetooth");
                }
            }

            enableBluetoothCallback = null;
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        destroy();
    }

    // https://github.com/don/cordova-plugin-ble-central/blob/master/src/android/BLECentralPlugin.java#L1200
    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {

        for (int i = 0; i < permissions.length; i++) {

            if (permissions[i].equals(ACCESS_FINE_LOCATION) && grantResults[i] == PackageManager.PERMISSION_DENIED) {
                LOG.d(TAG, "User *rejected* Fine Location Access");
                this.permissionCallback.error("Location permission not granted.");
                return;
            } else if (permissions[i].equals(ACCESS_COARSE_LOCATION) && grantResults[i] == PackageManager.PERMISSION_DENIED) {
                LOG.d(TAG, "User *rejected* Coarse Location Access");
                this.permissionCallback.error("Location permission not granted.");
                return;
            } else if (permissions[i].equals(BLUETOOTH_SCAN) && grantResults[i] == PackageManager.PERMISSION_DENIED) {
                LOG.d(TAG, "User *rejected* Bluetooth_Scan Access");
                this.permissionCallback.error("Bluetooth scan permission not granted.");
                return;
            } else if (permissions[i].equals(BLUETOOTH_CONNECT) && grantResults[i] == PackageManager.PERMISSION_DENIED) {
                LOG.d(TAG, "User *rejected* Bluetooth_Connect Access");
                this.permissionCallback.error("Bluetooth Connect permission not granted.");
                return;
            }
        }


        switch (requestCode) {
            case REQUEST_LIST_BONDED_DEVICES:
                LOG.d(TAG, "User granted permission");
                listBondedDevices(permissionCallback);
                this.permissionCallback = null;
                break;
            case REQUEST_LIST_UNPAIRED_DEVICES:
                LOG.d(TAG, "User granted permission");
                discoverUnpairedDevices(permissionCallback);
                this.permissionCallback = null;
                break;
        }

    }

    // https://github.com/don/cordova-plugin-ble-central/blob/master/src/android/BLECentralPlugin.java#L1062
    private List<String> getMissingPermissions() {
        //Android 12 (API 31) and higher
        // Users MUST accept BLUETOOTH_SCAN and BLUETOOTH_CONNECT
        // Android 10 (API 29) up to Android 11 (API 30)
        // Users MUST accept ACCESS_FINE_LOCATION
        // Users may accept or reject ACCESS_BACKGROUND_LOCATION
        // Android 9 (API 28) and lower
        // Users MUST accept ACCESS_COARSE_LOCATION
        List<String> missingPermissions = new ArrayList<String>();
        if (COMPILE_SDK_VERSION >= 31 && Build.VERSION.SDK_INT >= 31) { // (API 31) Build.VERSION_CODE.S
            if (!PermissionHelper.hasPermission(this, BLUETOOTH_SCAN)) {
                missingPermissions.add(BLUETOOTH_SCAN);
            }
            if (!PermissionHelper.hasPermission(this, BLUETOOTH_CONNECT)) {
                missingPermissions.add(BLUETOOTH_CONNECT);
            }
        } else if (COMPILE_SDK_VERSION >= 29 && Build.VERSION.SDK_INT >= 29) { // (API 29) Build.VERSION_CODES.Q
            if (!PermissionHelper.hasPermission(this, ACCESS_FINE_LOCATION)) {
                missingPermissions.add(ACCESS_FINE_LOCATION);
            }

            String accessBackgroundLocation = this.preferences.getString("accessBackgroundLocation", "false");
            if (accessBackgroundLocation == "true" && !PermissionHelper.hasPermission(this, ACCESS_BACKGROUND_LOCATION)) {
                LOG.w(TAG, "ACCESS_BACKGROUND_LOCATION is being requested");
                missingPermissions.add(ACCESS_BACKGROUND_LOCATION);
            }
        } else {
            if (!PermissionHelper.hasPermission(this, ACCESS_COARSE_LOCATION)) {
                missingPermissions.add(ACCESS_COARSE_LOCATION);
            }
        }
        return missingPermissions;
    }

    // Object to Hold Connected Interfaces
    private class InterfaceContext {

        public BluetoothClassicSerialService bluetoothClassicSerialService;
        public StringBuffer buffer;
        public String delimiter;
        public String macAddress;
        public CallbackContext dataAvailableCallback;
        public CallbackContext connectCallback;
        public CallbackContext rawDataAvailableCallback;
        private boolean mConnected = false;

        // The Handler that gets information back from the BluetoothClassicSerialService
        // Original code used a handler for the because it was talking to the UI.
        // Consider replacing with normal callbacks
        private final Handler mHandler;

        public InterfaceContext(String macAddress) {

            this.macAddress = macAddress;

            mHandler = new Handler() {

                public void handleMessage(Message msg) {

                    byte[] byteArray;
                    String stringData;

                    switch (msg.what) {
                        case MESSAGE_READ:

                            stringData = (String) msg.obj;

                            if (buffer == null) {
                                buffer = new StringBuffer();
                            }

                            buffer.append(stringData);

                            if (dataAvailableCallback != null) {
                                sendDataToSubscriber();
                            }

                            break;

                        case MESSAGE_READ_RAW:

                            if (rawDataAvailableCallback != null) {
                                byteArray = (byte[]) msg.obj;
                                sendRawDataToSubscriber(byteArray);
                            }

                            break;

                        case MESSAGE_STATE_CHANGE:

                            if (D) Log.i(TAG, "MESSAGE_STATE_CHANGE: " + msg.arg1);
                            switch (msg.arg1) {
                                case BluetoothClassicSerialService.STATE_CONNECTED:
                                    Log.i(TAG, "BluetoothClassicSerialService.STATE_CONNECTED");
                                    if (mConnected == false) {
                                        mConnected = true;
                                        notifyConnectionSuccess();
                                    }
                                    break;
                                case BluetoothClassicSerialService.STATE_CONNECTING:
                                    Log.i(TAG, "BluetoothClassicSerialService.STATE_CONNECTING");
                                    break;
                                case BluetoothClassicSerialService.STATE_LISTEN:
                                    Log.i(TAG, "BluetoothClassicSerialService.STATE_LISTEN");
                                    break;
                                case BluetoothClassicSerialService.STATE_NONE:
                                    Log.i(TAG, "BluetoothClassicSerialService.STATE_NONE");
                                    break;
                            }
                            break;

                        case MESSAGE_WRITE:
                            //  byte[] writeBuf = (byte[]) msg.obj;
                            //  String writeMessage = new String(writeBuf);
                            //  Log.i(TAG, "Wrote: " + writeMessage);
                            break;

                        case MESSAGE_DEVICE_NAME:
                            Log.i(TAG, msg.getData().getString(DEVICE_NAME));
                            break;

                        case MESSAGE_TOAST:
                            String message = msg.getData().getString(TOAST);
                            if (mConnected == true) {
                                mConnected = false;
                                notifyConnectionLost(message);
                            }
                            break;
                        case MESSAGE_FAILED:
                            String messageF = msg.getData().getString(TOAST);
                            if (connectCallback != null) {
                                if (mConnected == true) {
                                    mConnected = false;
                                }
                                PluginResult result = new PluginResult(PluginResult.Status.ERROR, messageF);
                                connectCallback.error(messageF);
                                connectCallback = null;
                            }
                            break;
                    }

                }
            };

            this.bluetoothClassicSerialService = new BluetoothClassicSerialService(this.mHandler);
            this.buffer = new StringBuffer();
            this.macAddress = macAddress;
            this.dataAvailableCallback = null;
            this.delimiter = null;
        }

        public int available() {
            return buffer.length();
        }

        public void clearBuffer() {
            this.buffer.setLength(0);
        }

        public String read() {
            int length = buffer.length();
            String data = buffer.substring(0, length);
            buffer.delete(0, length);
            return data;
        }

        public String readUntil(String delimiter) {

            String data = null;
            int index;

            index = buffer.indexOf(delimiter, 0);

            if (index > -1) {
                data = buffer.substring(0, index + delimiter.length());
                buffer.delete(0, index + delimiter.length());
            }

            return data;

        }

        private void sendDataToSubscriber() {

            String data = readUntil(delimiter);

            if (data != null && !data.isEmpty()) {
                PluginResult result = new PluginResult(PluginResult.Status.OK, data);
                result.setKeepCallback(true);
                dataAvailableCallback.sendPluginResult(result);
                sendDataToSubscriber();
            }

        }

        private void sendRawDataToSubscriber(byte[] byteData) {

            PluginResult result;

            if (byteData.length > 0) {

                result = new PluginResult(PluginResult.Status.OK, byteData);
                result.setKeepCallback(true);
                rawDataAvailableCallback.sendPluginResult(result);

            }
        }

        private void notifyConnectionLost(String error) {
            if (connectCallback != null) {
                connectCallback.error(error);
                connectCallback = null;
            }
        }

        private void notifyConnectionSuccess() {
            if (connectCallback != null) {
                PluginResult result = new PluginResult(PluginResult.Status.OK);
                result.setKeepCallback(true);
                connectCallback.sendPluginResult(result);
            }
        }

    }  //End of Interface Context Class

    private void isEnabled(CallbackContext callbackContext) {
        if (bluetoothAdapter.isEnabled()) {
            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.OK, true));
        } else {
            callbackContext.error("Bluetooth is disabled.");
        }
    }

    private void listBondedDevices(CallbackContext callbackContext) throws JSONException {

        List<String> missingPermissions = getMissingPermissions();
        if (missingPermissions.size() > 0) {
            permissionCallback = callbackContext;
            PermissionHelper.requestPermissions(this, REQUEST_LIST_BONDED_DEVICES, missingPermissions.toArray(new String[0]));
            return;
        }

        JSONArray deviceList = new JSONArray();
        Set<BluetoothDevice> bondedDevices = bluetoothAdapter.getBondedDevices();

        for (BluetoothDevice device : bondedDevices) {
            deviceList.put(deviceToJSON(device));
        }
        callbackContext.success(deviceList);
    }

    private void discoverUnpairedDevices(final CallbackContext callbackContext) throws JSONException {

        List<String> missingPermissions = getMissingPermissions();
        if (missingPermissions.size() > 0) {
            permissionCallback = callbackContext;
            PermissionHelper.requestPermissions(this, REQUEST_LIST_UNPAIRED_DEVICES, missingPermissions.toArray(new String[0]));
            return;
        }

        final CallbackContext ddc = deviceDiscoveredCallback;

        final BroadcastReceiver discoverReceiver = new BroadcastReceiver() {

            private JSONArray unpairedDevices = new JSONArray();

            public void onReceive(Context context, Intent intent) {
                String action = intent.getAction();
                if (BluetoothDevice.ACTION_FOUND.equals(action)) {
                    BluetoothDevice device = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE);
                    try {
                        JSONObject o = deviceToJSON(device);
                        unpairedDevices.put(o);
                        if (ddc != null) {
                            PluginResult res = new PluginResult(PluginResult.Status.OK, o);
                            res.setKeepCallback(true);
                            ddc.sendPluginResult(res);
                        }
                    } catch (JSONException e) {
                        // This shouldn't happen, log and ignore
                        Log.e(TAG, "Problem converting device to JSON", e);
                    }
                } else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(action)) {
                    callbackContext.success(unpairedDevices);
                    cordova.getActivity().unregisterReceiver(this);
                }
            }
        };

        Activity activity = cordova.getActivity();
        activity.registerReceiver(discoverReceiver, new IntentFilter(BluetoothDevice.ACTION_FOUND));
        activity.registerReceiver(discoverReceiver, new IntentFilter(BluetoothAdapter.ACTION_DISCOVERY_FINISHED));
        bluetoothAdapter.startDiscovery();
    }

    private JSONObject deviceToJSON(BluetoothDevice device) throws JSONException {
        JSONObject json = new JSONObject();
        json.put("name", device.getName());
        json.put("address", device.getAddress());
        json.put("id", device.getAddress());
        if (device.getBluetoothClass() != null) {
            json.put("class", device.getBluetoothClass().getDeviceClass());
        }
        return json;
    }

    private void connect(CordovaArgs args, boolean secure, CallbackContext callbackContext) throws JSONException {
        String macAddress = args.getString(0);
        JSONArray uuidJSONArray = args.getJSONArray(1);

        if (!bluetoothAdapter.isEnabled()) {
            callbackContext.error("Bluetooth is disabled.");
            return;
        }

        String stringConnectUuid;
        UUID connectUuid;
        InterfaceContext interfaceContext;
        BluetoothClassicSerialService blueService;


        destroy(macAddress);

        BluetoothDevice device = bluetoothAdapter.getRemoteDevice(macAddress);

        if (device != null) {

            for (int i = 0; i < uuidJSONArray.length(); i++) {
                stringConnectUuid = uuidJSONArray.getString(i);
                connectUuid = UUID.fromString(stringConnectUuid);

                interfaceContext = connections.get(macAddress);

                if (interfaceContext == null) {
                    interfaceContext = new InterfaceContext(macAddress);
                    interfaceContext.connectCallback = callbackContext;
                    connections.put(macAddress, interfaceContext);
                }

              blueService = interfaceContext.bluetoothClassicSerialService;
              blueService.connect(device, connectUuid, secure);
            }

            PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
            result.setKeepCallback(true);
            callbackContext.sendPluginResult(result);

        } else {
            callbackContext.error("Could not connect to " + macAddress);
        }
    }

    private void disconnect(CordovaArgs args, CallbackContext callbackContext) throws JSONException {

        InterfaceContext ic;
        String macAddress = args.getString(0);

        if (macAddress != null) {
            ic = connections.get(macAddress);
            if (ic != null && ic.bluetoothClassicSerialService != null) {
                ic.bluetoothClassicSerialService.stop();
            }
            callbackContext.success();
        } else {
            callbackContext.error("No Interface");

        }

    }

    private void disconnectAll(CallbackContext callbackContext) {

        for (Map.Entry<String, InterfaceContext> stringInterfaceContextEntry : connections.entrySet()) {
            InterfaceContext connectionsIterator = stringInterfaceContextEntry.getValue();
            if (connectionsIterator.bluetoothClassicSerialService != null) {
                connectionsIterator.bluetoothClassicSerialService.stop();
            }
        }

        callbackContext.success();
    }

    private void destroy() {

        destroy(null);
    }

    private void destroy(String macAddress) {
        InterfaceContext ic;

        Iterator<Map.Entry<String, InterfaceContext>> it = connections.entrySet().iterator();
        while (it.hasNext()) {
            Map.Entry<String, InterfaceContext> entry = it.next();
            ic = entry.getValue();

            if (macAddress == null || entry.getKey().equalsIgnoreCase(macAddress)) {
                if (ic.bluetoothClassicSerialService != null) {
                    ic.bluetoothClassicSerialService.stop();
                }
                it.remove();
            }
        }
    }

    private void setContextSubscribe(String macAddress, CallbackContext cc, String delimiter) {

        InterfaceContext ic;

        ic = getInterfaceContext(macAddress);

        if (ic == null) {
            ic = new InterfaceContext(macAddress);
            setInterfaceContext(macAddress, ic);
        }

        ic.dataAvailableCallback = cc;
        ic.delimiter = delimiter;

        setInterfaceContext(macAddress, ic);

    }

    private void setContextRawSubscribe(String macAddress, CallbackContext cc) {

        InterfaceContext ic;

        ic = getInterfaceContext(macAddress);

        if (ic == null) {
            ic = new InterfaceContext(macAddress);
            setInterfaceContext(macAddress, ic);
        }

      ic.rawDataAvailableCallback = cc;
      setInterfaceContext(macAddress, ic);

    }

    private InterfaceContext getInterfaceContext(String macAddress) {
        return connections.get(macAddress);
    }

    private void setInterfaceContext(String macAddress, InterfaceContext ic) {

        if (macAddress == null) {
            return;
        }

        if (ic == null) {
            ic = new InterfaceContext(macAddress);
        }

        connections.put(macAddress, ic);

    }

    private void isConnected(CordovaArgs args, CallbackContext callbackContext) throws JSONException {

        String macAddress = args.getString(0);

        InterfaceContext ic;
        boolean successful = false;

        ic = connections.get(macAddress);

        if (ic != null && ic.bluetoothClassicSerialService != null) {
            if (ic.bluetoothClassicSerialService.getState() == BluetoothClassicSerialService.STATE_CONNECTED) {
                successful = true;
            }
        }

        if (successful) {
            callbackContext.success();
        } else {
            callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, successful));
        }
    }

}
