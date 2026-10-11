package nz.co.soltius.cordova;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import android.bluetooth.BluetoothAdapter;
import android.Manifest;

import androidx.appcompat.app.AppCompatActivity;
import org.apache.cordova.CallbackContext;
import org.robolectric.android.controller.ActivityController;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaInterfaceImpl;
import org.apache.cordova.CordovaPreferences;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.Shadows;
import org.robolectric.annotation.Config;

/**
 * What the plugin answers JavaScript without a Bluetooth device in reach: the dispatch of its actions, what it says about a device
 * nothing is connected to, and what the adapter's state turns into. What a connection does is for a phone (cordova-paramedic).
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
public class BluetoothClassicSerialTest {

    private static final String DEVICE = "00:11:22:33:44:55";
    private static final String PROTOCOL = "00001101-0000-1000-8000-00805F9B34FB";

    private CordovaWebView webView;
    private AppCompatActivity activity;
    private BluetoothClassicSerial plugin;

    @Before
    public void setUp() {
        // cordova-android's CordovaInterfaceImpl takes an AppCompatActivity, which needs an AppCompat theme to be created.
        ActivityController<AppCompatActivity> controller = Robolectric.buildActivity(AppCompatActivity.class);
        controller.get().setTheme(androidx.appcompat.R.style.Theme_AppCompat);
        activity = controller.setup().get();
        webView = mock(CordovaWebView.class);
        plugin = new BluetoothClassicSerial();
        // the way Cordova hands a plugin its interface and web view
        plugin.privateInitialize("BluetoothClassicSerial", new CordovaInterfaceImpl(activity), webView, new CordovaPreferences());
    }

    private int calls = 0;

    /** Runs an action the way Cordova does and returns what the plugin sent to JavaScript (null when it sent nothing). */
    private PluginResult run(String action, String... args) throws JSONException {
        // every call has a callback id of its own, as in Cordova, so what one call sent is not mistaken for another's
        String id = "cb" + (++calls);
        CallbackContext callback = new CallbackContext(id, webView);
        assertTrue("the action is known: " + action, plugin.execute(action, new CordovaArgs(new JSONArray(java.util.Arrays.asList(args))), callback));
        ArgumentCaptor<PluginResult> sent = ArgumentCaptor.forClass(PluginResult.class);
        try {
            verify(webView).sendPluginResult(sent.capture(), eq(id));
        } catch (AssertionError none) {
            return null;
        }
        return sent.getValue();
    }

    @Test
    public void anActionTheCordovaPluginDoesNotKnowIsNotHandled() throws JSONException {
        CallbackContext callback = new CallbackContext("cb", webView);
        assertFalse(plugin.execute("noSuchAction", new CordovaArgs(new JSONArray()), callback));
        verify(webView, never()).sendPluginResult(any(), any());
    }

    @Test
    public void aWriteToADeviceNothingIsConnectedToIsRefused() throws JSONException {
        // "AAEC" is the base64 of three bytes, how an ArrayBuffer reaches native
        PluginResult result = run("write", DEVICE, PROTOCOL, "AAEC");
        assertEquals(PluginResult.Status.ERROR.ordinal(), result.getStatus());
        assertEquals("\"No Interface\"", result.getMessage()); // a string reaches JavaScript as JSON
    }

    @Test
    public void aDeviceNothingIsConnectedToHasNothingToRead() throws JSONException {
        assertEquals("0", run("available", DEVICE, PROTOCOL).getMessage());
        assertEquals("\"\"", run("read", DEVICE, PROTOCOL).getMessage());
        assertEquals("\"\"", run("readUntil", DEVICE, PROTOCOL, "\n").getMessage());
    }

    @Test
    public void clearingTheBufferOfADeviceNothingIsConnectedToIsHarmless() throws JSONException {
        assertEquals(PluginResult.Status.OK.ordinal(), run("clear", DEVICE, PROTOCOL).getStatus());
    }

    @Test
    public void aDeviceNothingIsConnectedToIsNotConnected() throws JSONException {
        PluginResult result = run("isConnected", DEVICE, PROTOCOL);
        assertEquals(PluginResult.Status.ERROR.ordinal(), result.getStatus());
        assertEquals("false", result.getMessage());
    }

    @Test
    public void subscribingKeepsTheCallbackForTheDataThatComes() throws JSONException {
        PluginResult result = run("subscribe", DEVICE, PROTOCOL, "\n");
        assertEquals(PluginResult.Status.NO_RESULT.ordinal(), result.getStatus());
        assertTrue(result.getKeepCallback());
        assertEquals(PluginResult.Status.OK.ordinal(), run("unsubscribe", DEVICE, PROTOCOL).getStatus());
    }

    @Test
    public void subscribingToRawDataKeepsTheCallbackToo() throws JSONException {
        PluginResult result = run("subscribeRaw", DEVICE, PROTOCOL);
        assertEquals(PluginResult.Status.NO_RESULT.ordinal(), result.getStatus());
        assertTrue(result.getKeepCallback());
        assertEquals(PluginResult.Status.OK.ordinal(), run("unsubscribeRaw", DEVICE, PROTOCOL).getStatus());
    }

    @Test
    public void theDiscoveryListenerIsSetAndClearedWithoutAnAnswer() throws JSONException {
        assertEquals(null, run("setDeviceDiscoveredListener"));
        assertEquals(null, run("clearDeviceDiscoveredListener"));
    }

    @Test
    public void isEnabledFollowsTheAdapter() throws JSONException {
        BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
        Shadows.shadowOf(adapter).setEnabled(true);
        PluginResult enabled = run("isEnabled");
        assertEquals(PluginResult.Status.OK.ordinal(), enabled.getStatus());
        assertEquals("true", enabled.getMessage());

        Shadows.shadowOf(adapter).setEnabled(false);
        PluginResult disabled = run("isEnabled");
        assertEquals(PluginResult.Status.ERROR.ordinal(), disabled.getStatus());
        assertEquals("\"Bluetooth is disabled.\"", disabled.getMessage());
    }

    @Test
    public void listAnswersTheBondedDevicesOnceTheBluetoothPermissionsAreGiven() throws JSONException {
        Shadows.shadowOf(RuntimeEnvironment.getApplication()).grantPermissions(
                Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN);
        PluginResult result = run("list");
        assertEquals(PluginResult.Status.OK.ordinal(), result.getStatus());
        assertEquals("[]", result.getMessage());
    }

    @Test
    public void listAsksForThePermissionsItLacksInsteadOfAnswering() throws JSONException {
        assertEquals(null, run("list"));
    }
}
