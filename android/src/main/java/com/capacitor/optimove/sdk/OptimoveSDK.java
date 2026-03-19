package com.capacitor.optimove.sdk;

import android.content.Context;

import androidx.annotation.Nullable;

import java.net.URL;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.TimeZone;

import com.optimove.android.Optimove;
import com.optimove.android.optimobile.InAppInboxItem;
import com.optimove.android.optimobile.InAppInboxSummary;
import com.optimove.android.optimobile.OptimoveInApp;

import com.getcapacitor.JSObject;
import com.getcapacitor.JSArray;

import org.json.JSONObject;

/**
 * Implementation class containing all Optimove SDK logic.
 * The plugin bridge (OptimoveSDKPlugin) delegates to this class.
 */
public class OptimoveSDK {

    // ─── User Identification ──────────────────────────────

    public void setCredentials(@Nullable String optimoveCredentials, @Nullable String optimobileCredentials) {
        if (optimoveCredentials != null && optimoveCredentials.isEmpty()) optimoveCredentials = null;
        if (optimobileCredentials != null && optimobileCredentials.isEmpty()) optimobileCredentials = null;
        Optimove.getInstance().setCredentials(optimoveCredentials, optimobileCredentials);
    }

    public void setUserId(String userId) {
        Optimove.getInstance().setUserId(userId);
    }

    public void setUserEmail(String email) {
        Optimove.getInstance().setUserEmail(email);
    }

    public void registerUser(String userId, String email) {
        Optimove.getInstance().registerUser(userId, email);
    }

    @Nullable
    public String getVisitorId() {
        return Optimove.getInstance().getVisitorId();
    }

    public void signOutUser() {
        Optimove.getInstance().signOutUser();
    }

    // ─── Analytics ────────────────────────────────────────

    public void reportEvent(String eventName, @Nullable JSObject params) throws Exception {
        if (params == null) {
            Optimove.getInstance().reportEvent(eventName);
        } else {
            Optimove.getInstance().reportEvent(eventName, JsonUtils.toMap(params));
        }
    }

    public void reportScreenVisit(String screenName, @Nullable String screenCategory) {
        if (screenCategory == null) {
            Optimove.getInstance().reportScreenVisit(screenName);
        } else {
            Optimove.getInstance().reportScreenVisit(screenName, screenCategory);
        }
    }

    // ─── Push ─────────────────────────────────────────────

    public void pushRequestDeviceToken() {
        Optimove.getInstance().pushRequestDeviceToken();
    }

    public void pushUnregister() {
        Optimove.getInstance().pushUnregister();
    }

    // ─── In-App Messaging ─────────────────────────────────

    public void inAppUpdateConsent(boolean consented) {
        OptimoveInApp.getInstance().updateConsentForUser(consented);
    }

    public JSObject inAppGetInboxItems() throws Exception {
        SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US);
        formatter.setTimeZone(TimeZone.getTimeZone("UTC"));

        List<InAppInboxItem> items = OptimoveInApp.getInstance().getInboxItems();
        JSArray results = new JSArray();

        for (InAppInboxItem item : items) {
            JSObject mapped = new JSObject();
            mapped.put("id", item.getId());
            mapped.put("title", item.getTitle());
            mapped.put("subtitle", item.getSubtitle());
            mapped.put("isRead", item.isRead());
            mapped.put("sentAt", formatter.format(item.getSentAt()));

            Date availableFrom = item.getAvailableFrom();
            Date availableTo = item.getAvailableTo();
            Date dismissedAt = item.getDismissedAt();
            JSONObject data = item.getData();
            URL imageUrl = item.getImageUrl();

            mapped.put("data", data == null ? JSObject.NULL : data);
            mapped.put("imageUrl", imageUrl == null ? JSObject.NULL : imageUrl.toString());
            mapped.put("availableFrom", availableFrom == null ? JSObject.NULL : formatter.format(availableFrom));
            mapped.put("availableTo", availableTo == null ? JSObject.NULL : formatter.format(availableTo));
            mapped.put("dismissedAt", dismissedAt == null ? JSObject.NULL : formatter.format(dismissedAt));

            results.put(mapped);
        }

        JSObject ret = new JSObject();
        ret.put("items", results);
        return ret;
    }

    public void inAppGetInboxSummary(InboxSummaryCallback callback) {
        OptimoveInApp.getInstance().getInboxSummaryAsync((InAppInboxSummary summary) -> {
            if (summary == null) {
                callback.onFailure();
                return;
            }
            callback.onSuccess(summary.getTotalCount(), summary.getUnreadCount());
        });
    }

    public boolean inAppMarkAsRead(int messageId) {
        InAppInboxItem item = getInboxItemById(messageId);
        if (item == null) return false;
        return OptimoveInApp.getInstance().markAsRead(item);
    }

    public boolean inAppMarkAllInboxItemsAsRead() {
        return OptimoveInApp.getInstance().markAllInboxItemsAsRead();
    }

    /**
     * @return presentation result ordinal (0=FAILED, 1=EXPIRED, 2=PRESENTED)
     */
    public int inAppPresentInboxMessage(int messageId) {
        InAppInboxItem item = getInboxItemById(messageId);
        if (item == null) return 0; // FAILED
        return OptimoveInApp.getInstance().presentInboxMessage(item).ordinal();
    }

    public boolean inAppDeleteMessageFromInbox(int messageId) {
        InAppInboxItem item = getInboxItemById(messageId);
        if (item == null) return false;
        return OptimoveInApp.getInstance().deleteMessageFromInbox(item);
    }

    // ─── Helpers ──────────────────────────────────────────

    @Nullable
    private InAppInboxItem getInboxItemById(int id) {
        List<InAppInboxItem> inboxItems = OptimoveInApp.getInstance().getInboxItems();
        for (InAppInboxItem item : inboxItems) {
            if (item.getId() == id) return item;
        }
        return null;
    }

    public interface InboxSummaryCallback {
        void onSuccess(int totalCount, int unreadCount);
        void onFailure();
    }
}
