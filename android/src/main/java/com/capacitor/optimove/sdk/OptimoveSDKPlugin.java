package com.capacitor.optimove.sdk;

import android.content.Context;

import androidx.annotation.Nullable;

import com.optimove.android.optimobile.InAppDeepLinkHandlerInterface;
import com.optimove.android.optimobile.OptimoveInApp;
import com.optimove.android.optimobile.PushMessage;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

import org.json.JSONObject;

@CapacitorPlugin(name = "OptimoveSDK")
public class OptimoveSDKPlugin extends Plugin {

    @Nullable static OptimoveSDKPlugin instance;
    @Nullable static PushMessage pendingPush;
    @Nullable static String pendingActionId;
    @Nullable static JSObject pendingDDL;

    private final OptimoveSDK implementation = new OptimoveSDK();

    @Override
    public void load() {
        instance = this;
        deliverPendingEvents();
    }

    private void deliverPendingEvents() {
        if (pendingPush != null) {
            sendEvent("pushOpened", PushReceiver.pushMessageToJSObject(pendingPush, pendingActionId));
            pendingPush = null;
            pendingActionId = null;
        }
        if (pendingDDL != null) {
            sendEvent("deepLink", pendingDDL);
            pendingDDL = null;
        }
    }

    static void sendEvent(String eventName, JSObject data) {
        if (instance != null) {
            instance.notifyListeners(eventName, data);
        }
    }

    // ─── User Identification ──────────────────────────────

    @PluginMethod
    public void setCredentials(PluginCall call) {
        try {
            implementation.setCredentials(
                    call.getString("optimoveCredentials"),
                    call.getString("optimobileCredentials")
            );
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    @PluginMethod
    public void setUserId(PluginCall call) {
        String userId = call.getString("userId");
        if (userId == null) { call.reject("userId is required"); return; }
        try {
            implementation.setUserId(userId);
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    @PluginMethod
    public void setUserEmail(PluginCall call) {
        String email = call.getString("email");
        if (email == null) { call.reject("email is required"); return; }
        try {
            implementation.setUserEmail(email);
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    @PluginMethod
    public void registerUser(PluginCall call) {
        String userId = call.getString("userId");
        String email = call.getString("email");
        if (userId == null) { call.reject("userId is required"); return; }
        if (email == null) { call.reject("email is required"); return; }
        try {
            implementation.registerUser(userId, email);
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    @PluginMethod
    public void getVisitorId(PluginCall call) {
        String visitorId = implementation.getVisitorId();
        if (visitorId != null) {
            JSObject ret = new JSObject();
            ret.put("visitorId", visitorId);
            call.resolve(ret);
        } else {
            call.reject("visitor id is null");
        }
    }

    @PluginMethod
    public void signOutUser(PluginCall call) {
        try {
            implementation.signOutUser();
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    // ─── Analytics ────────────────────────────────────────

    @PluginMethod
    public void reportEvent(PluginCall call) {
        String eventName = call.getString("event");
        if (eventName == null) { call.reject("event is required"); return; }
        try {
            implementation.reportEvent(eventName, call.getObject("params"));
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    @PluginMethod
    public void reportScreenVisit(PluginCall call) {
        String screenName = call.getString("screenName");
        if (screenName == null) { call.reject("screenName is required"); return; }
        try {
            implementation.reportScreenVisit(screenName, call.getString("screenCategory"));
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    // ─── Push ─────────────────────────────────────────────

    @PluginMethod
    public void pushRequestDeviceToken(PluginCall call) {
        try {
            implementation.pushRequestDeviceToken();
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    @PluginMethod
    public void pushUnregister(PluginCall call) {
        try {
            implementation.pushUnregister();
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    // ─── In-App Messaging ─────────────────────────────────

    @PluginMethod
    public void inAppUpdateConsent(PluginCall call) {
        Boolean consented = call.getBoolean("consented");
        if (consented == null) { call.reject("consented is required"); return; }
        try {
            implementation.inAppUpdateConsent(consented);
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    @PluginMethod
    public void inAppGetInboxItems(PluginCall call) {
        try {
            JSObject result = implementation.inAppGetInboxItems();
            call.resolve(result);
        } catch (Exception e) {
            call.reject(e.getMessage(), e);
        }
    }

    @PluginMethod
    public void inAppGetInboxSummary(PluginCall call) {
        implementation.inAppGetInboxSummary(new OptimoveSDK.InboxSummaryCallback() {
            @Override
            public void onSuccess(int totalCount, int unreadCount) {
                JSObject ret = new JSObject();
                ret.put("totalCount", totalCount);
                ret.put("unreadCount", unreadCount);
                call.resolve(ret);
            }

            @Override
            public void onFailure() {
                call.reject("Could not get inbox summary");
            }
        });
    }

    @PluginMethod
    public void inAppMarkAsRead(PluginCall call) {
        Integer messageId = call.getInt("id");
        if (messageId == null) { call.reject("id is required"); return; }
        boolean result = implementation.inAppMarkAsRead(messageId);
        if (result) { call.resolve(); } else { call.reject("Message not found or failed to mark as read"); }
    }

    @PluginMethod
    public void inAppMarkAllInboxItemsAsRead(PluginCall call) {
        boolean result = implementation.inAppMarkAllInboxItemsAsRead();
        if (result) { call.resolve(); } else { call.reject("Failed to mark all messages as read"); }
    }

    @PluginMethod
    public void inAppPresentInboxMessage(PluginCall call) {
        Integer messageId = call.getInt("id");
        if (messageId == null) { call.reject("id is required"); return; }
        int result = implementation.inAppPresentInboxMessage(messageId);
        JSObject ret = new JSObject();
        ret.put("result", result);
        call.resolve(ret);
    }

    @PluginMethod
    public void inAppDeleteMessageFromInbox(PluginCall call) {
        Integer messageId = call.getInt("id");
        if (messageId == null) { call.reject("id is required"); return; }
        boolean result = implementation.inAppDeleteMessageFromInbox(messageId);
        if (result) { call.resolve(); } else { call.reject("Message not found or not available"); }
    }

    // ─── Inner Classes for Init Provider ──────────────────

    static class InAppDeepLinkHandler implements InAppDeepLinkHandlerInterface {
        @Override
        public void handle(Context context, InAppDeepLinkHandlerInterface.InAppButtonPress buttonPress) {
            JSObject data = new JSObject();
            try {
                data.put("deepLinkData", buttonPress.getDeepLinkData());
                data.put("messageId", buttonPress.getMessageId());
                JSONObject messageData = buttonPress.getMessageData();
                data.put("messageData", messageData == null ? JSObject.NULL : messageData);
            } catch (Exception e) {
                // noop
            }
            sendEvent("inAppDeepLink", data);
        }
    }

    static class InboxUpdatedHandler implements OptimoveInApp.InAppInboxUpdatedHandler {
        @Override
        public void run() {
            sendEvent("inAppInboxUpdated", new JSObject());
        }
    }
}
