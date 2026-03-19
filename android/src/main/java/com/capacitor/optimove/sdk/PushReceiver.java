package com.capacitor.optimove.sdk;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import com.optimove.android.Optimove;
import com.optimove.android.optimobile.Optimobile;
import com.optimove.android.optimobile.PushActionHandlerInterface;
import com.optimove.android.optimobile.PushBroadcastReceiver;
import com.optimove.android.optimobile.PushMessage;

import com.getcapacitor.JSObject;

public class PushReceiver extends PushBroadcastReceiver {

    @Override
    protected void onPushReceived(Context context, PushMessage pushMessage) {
        super.onPushReceived(context, pushMessage);
        OptimoveSDKPlugin.sendEvent("pushReceived", pushMessageToJSObject(pushMessage, null));
    }

    @Override
    protected void onPushOpened(Context context, PushMessage pushMessage) {
        try {
            Optimove.getInstance().pushTrackOpen(pushMessage.getId());
        } catch (Optimobile.UninitializedException ignored) {
        }
        handlePushOpen(context, pushMessage, null);
    }

    @Override
    protected Intent getPushOpenActivityIntent(Context context, PushMessage pushMessage) {
        Intent launchIntent = context.getPackageManager()
                .getLaunchIntentForPackage(context.getPackageName());
        if (launchIntent == null) {
            return null;
        }
        launchIntent.putExtra(PushMessage.EXTRAS_KEY, pushMessage);
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return launchIntent;
    }

    static void handlePushOpen(Context context, PushMessage pushMessage, String actionId) {
        if (OptimoveSDKPlugin.instance == null) {
            OptimoveSDKPlugin.pendingPush = pushMessage;
            OptimoveSDKPlugin.pendingActionId = actionId;
            return;
        }
        OptimoveSDKPlugin.sendEvent("pushOpened", pushMessageToJSObject(pushMessage, actionId));
    }

    static JSObject pushMessageToJSObject(PushMessage pushMessage, String actionId) {
        JSObject result = new JSObject();
        try {
            String title = pushMessage.getTitle();
            String message = pushMessage.getMessage();
            Uri uri = pushMessage.getUrl();
            org.json.JSONObject data = pushMessage.getData();

            result.put("id", pushMessage.getId());
            result.put("title", title != null ? title : JSObject.NULL);
            result.put("message", message != null ? message : JSObject.NULL);
            result.put("url", uri != null ? uri.toString() : JSObject.NULL);
            result.put("actionId", actionId != null ? actionId : JSObject.NULL);
            result.put("data", data != null ? data : JSObject.NULL);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return result;
    }

    static class PushActionHandler implements PushActionHandlerInterface {
        @SuppressLint("MissingPermission")
        @Override
        public void handle(Context context, PushMessage pushMessage, String actionId) {
            PushReceiver.handlePushOpen(context, pushMessage, actionId);
            try {
                Intent it = new Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS);
                context.sendBroadcast(it);
            } catch (SecurityException ignored) {
            }
        }
    }
}
