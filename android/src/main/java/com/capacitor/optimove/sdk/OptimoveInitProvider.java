package com.capacitor.optimove.sdk;

import android.app.Application;
import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.Context;
import android.content.res.Resources;
import android.database.Cursor;
import android.net.Uri;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.optimove.android.Optimove;
import com.optimove.android.OptimoveConfig;
import com.optimove.android.optimobile.DeferredDeepLinkHandlerInterface;
import com.optimove.android.optimobile.DeferredDeepLinkHelper;
import com.optimove.android.optimobile.OptimoveInApp;

import com.getcapacitor.JSObject;

import org.json.JSONException;
import org.json.JSONObject;

public class OptimoveInitProvider extends ContentProvider {
    private static final String KEY_OPTIMOVE_CREDENTIALS = "optimoveCredentials";
    private static final String KEY_OPTIMOVE_MOBILE_CREDENTIALS = "optimoveMobileCredentials";
    private static final String KEY_IN_APP_CONSENT_STRATEGY = "optimoveInAppConsentStrategy";
    private static final String KEY_DELAYED_INITIALIZATION_ENABLE = "delayedInitialization.enable";
    private static final String KEY_DELAYED_INITIALIZATION_REGION = "delayedInitialization.region";

    private static final String IN_APP_AUTO_ENROLL = "auto-enroll";
    private static final String IN_APP_EXPLICIT_BY_USER = "explicit-by-user";

    private static final String ENABLE_DEFERRED_DEEP_LINKING = "optimoveEnableDeferredDeepLinking";
    private static final String ANDROID_PUSH_NOTIFICATION_ICON_NAME = "android.pushNotificationIconName";
    private static final String DELAYED_INIT_ENABLE_OPTIMOVE = "delayedInitialization.featureSet.enableOptimove";
    private static final String DELAYED_INIT_ENABLE_OPTIMOBILE = "delayedInitialization.featureSet.enableOptimobile";

    private static final String SDK_VERSION = "1.0.0";
    private static final int RUNTIME_TYPE = 4;
    private static final int SDK_TYPE = 107;

    @Override
    public boolean onCreate() {
        Application app = (Application) getContext().getApplicationContext();
        String packageName = app.getPackageName();
        Resources resources = app.getResources();

        String optimoveCredentials = getStringConfigValue(packageName, resources, KEY_OPTIMOVE_CREDENTIALS);
        String optimoveMobileCredentials = getStringConfigValue(packageName, resources, KEY_OPTIMOVE_MOBILE_CREDENTIALS);
        boolean enableDelayedInit = Boolean.parseBoolean(
                getStringConfigValue(packageName, resources, KEY_DELAYED_INITIALIZATION_ENABLE));
        boolean enableOptimove = Boolean.parseBoolean(
                getStringConfigValue(packageName, resources, DELAYED_INIT_ENABLE_OPTIMOVE));
        boolean enableOptimobile = Boolean.parseBoolean(
                getStringConfigValue(packageName, resources, DELAYED_INIT_ENABLE_OPTIMOBILE));

        OptimoveConfig.Builder configBuilder;

        if (enableDelayedInit) {
            String optimoveRegion = getStringConfigValue(packageName, resources, KEY_DELAYED_INITIALIZATION_REGION);
            OptimoveConfig.Region region = OptimoveConfig.Region.valueOf(optimoveRegion.toUpperCase());
            OptimoveConfig.FeatureSet featureSet = new OptimoveConfig.FeatureSet();
            if (enableOptimove) featureSet.withOptimove();
            if (enableOptimobile) featureSet.withOptimobile();
            configBuilder = new OptimoveConfig.Builder(region, featureSet);
        } else {
            if (optimoveCredentials == null && optimoveMobileCredentials == null) {
                throw new IllegalArgumentException(
                        "OptimoveSDK: Invalid credentials - provide at least one set in res/values/optimove.xml");
            }
            configBuilder = new OptimoveConfig.Builder(optimoveCredentials, optimoveMobileCredentials);
        }

        if (!configBuilder.build().isOptimobileConfigured()) {
            Optimove.initialize(app, configBuilder.build());
            return true;
        }

        String inAppConsentStrategy = getStringConfigValue(packageName, resources, KEY_IN_APP_CONSENT_STRATEGY);
        if (IN_APP_AUTO_ENROLL.equals(inAppConsentStrategy)) {
            configBuilder.enableInAppMessaging(OptimoveConfig.InAppConsentStrategy.AUTO_ENROLL);
        } else if (IN_APP_EXPLICIT_BY_USER.equals(inAppConsentStrategy)) {
            configBuilder.enableInAppMessaging(OptimoveConfig.InAppConsentStrategy.EXPLICIT_BY_USER);
        }

        String enableDDL = getStringConfigValue(packageName, resources, ENABLE_DEFERRED_DEEP_LINKING);
        if (Boolean.parseBoolean(enableDDL)) {
            configBuilder.enableDeepLinking(getDDLHandler());
        }

        String pushIconName = getStringConfigValue(packageName, resources, ANDROID_PUSH_NOTIFICATION_ICON_NAME);
        if (pushIconName != null) {
            int iconResource = resources.getIdentifier(pushIconName, "drawable", packageName);
            configBuilder.setPushSmallIconId(iconResource);
        }

        overrideInstallInfo(configBuilder);

        Optimove.initialize(app, configBuilder.build());

        if (IN_APP_AUTO_ENROLL.equals(inAppConsentStrategy) || IN_APP_EXPLICIT_BY_USER.equals(inAppConsentStrategy)) {
            OptimoveInApp.getInstance().setDeepLinkHandler(new OptimoveSDKPlugin.InAppDeepLinkHandler());
        }

        Optimove.getInstance().setPushActionHandler(new PushReceiver.PushActionHandler());
        OptimoveInApp.getInstance().setOnInboxUpdated(new OptimoveSDKPlugin.InboxUpdatedHandler());

        return true;
    }

    private void overrideInstallInfo(OptimoveConfig.Builder configBuilder) {
        JSONObject sdkInfo = new JSONObject();
        JSONObject runtimeInfo = new JSONObject();
        try {
            sdkInfo.put("id", SDK_TYPE);
            sdkInfo.put("version", SDK_VERSION);
            runtimeInfo.put("id", RUNTIME_TYPE);
            runtimeInfo.put("version", "8.0.0");
            configBuilder.setSdkInfo(sdkInfo);
            configBuilder.setRuntimeInfo(runtimeInfo);
        } catch (JSONException e) {
            e.printStackTrace();
        }
    }

    @Nullable
    private String getStringConfigValue(String packageName, Resources resources, String key) {
        int resId = resources.getIdentifier(key, "string", packageName);
        if (resId == 0) return null;
        String value = resources.getString(resId);
        return TextUtils.isEmpty(value) ? null : value;
    }

    private DeferredDeepLinkHandlerInterface getDDLHandler() {
        return (Context context, DeferredDeepLinkHelper.DeepLinkResolution resolution,
                String link, @Nullable DeferredDeepLinkHelper.DeepLink data) -> {
            try {
                JSObject deepLink = new JSObject();
                String mappedResolution;
                String url;

                switch (resolution) {
                    case LINK_MATCHED:
                        mappedResolution = "LINK_MATCHED";
                        url = data.url;
                        JSObject deepLinkContent = new JSObject();
                        deepLinkContent.put("title", data.content.title);
                        deepLinkContent.put("description", data.content.description);
                        deepLink.put("content", deepLinkContent);
                        deepLink.put("linkData", data.data);
                        break;
                    case LINK_NOT_FOUND:
                        mappedResolution = "LINK_NOT_FOUND";
                        url = link;
                        break;
                    case LINK_EXPIRED:
                        mappedResolution = "LINK_EXPIRED";
                        url = link;
                        break;
                    case LINK_LIMIT_EXCEEDED:
                        mappedResolution = "LINK_LIMIT_EXCEEDED";
                        url = link;
                        break;
                    default:
                        mappedResolution = "LOOKUP_FAILED";
                        url = link;
                        break;
                }

                deepLink.put("resolution", mappedResolution);
                deepLink.put("url", url);
                if (!deepLink.has("content")) deepLink.put("content", JSObject.NULL);
                if (!deepLink.has("linkData")) deepLink.put("linkData", JSObject.NULL);

                if (OptimoveSDKPlugin.instance == null) {
                    OptimoveSDKPlugin.pendingDDL = deepLink;
                    return;
                }
                OptimoveSDKPlugin.sendEvent("deepLink", deepLink);
            } catch (Exception e) {
                e.printStackTrace();
            }
        };
    }

    // Required ContentProvider overrides (no-op)
    @Nullable @Override
    public Cursor query(@NonNull Uri u, String[] p, String s, String[] sa, String so) { return null; }
    @Nullable @Override
    public String getType(@NonNull Uri uri) { return null; }
    @Nullable @Override
    public Uri insert(@NonNull Uri uri, ContentValues v) { return null; }
    @Override
    public int delete(@NonNull Uri u, String s, String[] sa) { return 0; }
    @Override
    public int update(@NonNull Uri u, ContentValues v, String s, String[] sa) { return 0; }
}
