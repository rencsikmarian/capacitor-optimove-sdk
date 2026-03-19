import Foundation
import Capacitor

@objc(OptimoveSDKPlugin)
public class OptimoveSDKPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "OptimoveSDKPlugin"
    public let jsName = "OptimoveSDK"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setCredentials", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setUserId", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setUserEmail", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "registerUser", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getVisitorId", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "signOutUser", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reportEvent", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reportScreenVisit", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pushRequestDeviceToken", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "pushUnregister", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "inAppUpdateConsent", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "inAppGetInboxItems", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "inAppGetInboxSummary", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "inAppMarkAsRead", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "inAppMarkAllInboxItemsAsRead", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "inAppPresentInboxMessage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "inAppDeleteMessageFromInbox", returnType: CAPPluginReturnPromise),
    ]

    private let implementation = OptimoveSDKImpl()

    // MARK: - Lifecycle

    override public func load() {
        implementation.setEventCallback { [weak self] eventName, data in
            self?.notifyListeners(eventName, data: data)
        }

        // Read config: capacitor.config.json first, Info.plist fallback
        let config = getConfig()

        implementation.initialize(
            optimoveCredentials: configString("optimoveCredentials", config: config),
            optimoveMobileCredentials: configString("optimoveMobileCredentials", config: config),
            inAppConsentStrategy: configString("inAppConsentStrategy", config: config) ?? "in-app-disabled",
            enableDeferredDeepLinking: configBool("enableDeferredDeepLinking", config: config),
            ddlCname: configString("ddlCname", config: config),
            enableDelayedInitialization: configBool("delayedInitialization.enable", config: config),
            delayedRegion: configString("delayedInitialization.region", config: config),
            delayedEnableOptimove: configBool("delayedInitialization.featureSet.enableOptimove", config: config),
            delayedEnableOptimobile: configBool("delayedInitialization.featureSet.enableOptimobile", config: config)
        )

        implementation.deliverPendingEvents()
    }

    // MARK: - Config Resolution (capacitor.config.json -> Info.plist fallback)

    /// Reads a string value: tries capacitor.config.json first, then Info.plist
    private func configString(_ key: String, config: PluginConfig) -> String? {
        // 1. Try capacitor.config.json (plugins.OptimoveSDK section)
        if let value = config.getString(key), !value.isEmpty {
            return value
        }
        // 2. Fall back to Info.plist
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty {
            return value
        }
        return nil
    }

    /// Reads a bool value: tries capacitor.config.json first, then Info.plist.
    /// Uses sentinel pattern to detect key presence in Capacitor config:
    /// if getBoolean(key, true) == getBoolean(key, false), the key exists with that value.
    /// If they differ, the key is absent (each returns its own default).
    private func configBool(_ key: String, config: PluginConfig) -> Bool {
        // 1. Try capacitor.config.json (handles both JSON boolean and string "true"/"false")
        let withTrue = config.getBoolean(key, true)
        let withFalse = config.getBoolean(key, false)
        if withTrue == withFalse {
            return withTrue
        }
        // 2. Fall back to Info.plist (supports both Bool and String values)
        if let value = Bundle.main.object(forInfoDictionaryKey: key) {
            if let boolValue = value as? Bool {
                return boolValue
            }
            if let stringValue = value as? String {
                return stringValue.caseInsensitiveCompare("true") == .orderedSame
            }
        }
        return false
    }

    // MARK: - User Identification

    @objc func setCredentials(_ call: CAPPluginCall) {
        implementation.setCredentials(
            optimoveCredentials: call.getString("optimoveCredentials"),
            optimobileCredentials: call.getString("optimobileCredentials")
        )
        call.resolve()
    }

    @objc func setUserId(_ call: CAPPluginCall) {
        guard let userId = call.getString("userId") else {
            call.reject("userId is required")
            return
        }
        implementation.setUserId(userId)
        call.resolve()
    }

    @objc func setUserEmail(_ call: CAPPluginCall) {
        guard let email = call.getString("email") else {
            call.reject("email is required")
            return
        }
        implementation.setUserEmail(email)
        call.resolve()
    }

    @objc func registerUser(_ call: CAPPluginCall) {
        guard let userId = call.getString("userId") else {
            call.reject("userId is required")
            return
        }
        guard let email = call.getString("email") else {
            call.reject("email is required")
            return
        }
        implementation.registerUser(userId: userId, email: email)
        call.resolve()
    }

    @objc func getVisitorId(_ call: CAPPluginCall) {
        call.resolve(["visitorId": implementation.getVisitorId()])
    }

    @objc func signOutUser(_ call: CAPPluginCall) {
        implementation.signOutUser()
        call.resolve()
    }

    // MARK: - Analytics

    @objc func reportEvent(_ call: CAPPluginCall) {
        guard let eventName = call.getString("event") else {
            call.reject("event name is required")
            return
        }
        let params = call.getObject("params") ?? [:]
        implementation.reportEvent(name: eventName, parameters: params)
        call.resolve()
    }

    @objc func reportScreenVisit(_ call: CAPPluginCall) {
        guard let screenName = call.getString("screenName") else {
            call.reject("screenName is required")
            return
        }
        implementation.reportScreenVisit(
            screenTitle: screenName,
            screenCategory: call.getString("screenCategory")
        )
        call.resolve()
    }

    // MARK: - Push

    @objc func pushRequestDeviceToken(_ call: CAPPluginCall) {
        implementation.pushRequestDeviceToken()
        call.resolve()
    }

    @objc func pushUnregister(_ call: CAPPluginCall) {
        implementation.pushUnregister()
        call.resolve()
    }

    // MARK: - In-App Messaging

    @objc func inAppUpdateConsent(_ call: CAPPluginCall) {
        guard let consented = call.getBool("consented") else {
            call.reject("consented is required")
            return
        }
        implementation.inAppUpdateConsent(consented: consented)
        call.resolve()
    }

    @objc func inAppGetInboxItems(_ call: CAPPluginCall) {
        DispatchQueue.global(qos: .userInitiated).async {
            let items = self.implementation.inAppGetInboxItems()
            call.resolve(["items": items])
        }
    }

    @objc func inAppGetInboxSummary(_ call: CAPPluginCall) {
        implementation.inAppGetInboxSummary(
            completion: { totalCount, unreadCount in
                call.resolve([
                    "totalCount": totalCount,
                    "unreadCount": unreadCount
                ])
            },
            failure: {
                call.reject("Could not get inbox summary")
            }
        )
    }

    @objc func inAppMarkAsRead(_ call: CAPPluginCall) {
        guard let messageId = call.getInt("id") else {
            call.reject("id is required")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.implementation.inAppMarkAsRead(messageId: messageId)
            if result {
                call.resolve()
            } else {
                call.reject("Message not found or failed to mark as read")
            }
        }
    }

    @objc func inAppMarkAllInboxItemsAsRead(_ call: CAPPluginCall) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.implementation.inAppMarkAllInboxItemsAsRead()
            if result {
                call.resolve()
            } else {
                call.reject("Failed to mark all messages as read")
            }
        }
    }

    @objc func inAppPresentInboxMessage(_ call: CAPPluginCall) {
        guard let messageId = call.getInt("id") else {
            call.reject("id is required")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.implementation.inAppPresentInboxMessage(messageId: messageId)
            call.resolve(["result": result])
        }
    }

    @objc func inAppDeleteMessageFromInbox(_ call: CAPPluginCall) {
        guard let messageId = call.getInt("id") else {
            call.reject("id is required")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.implementation.inAppDeleteMessageFromInbox(messageId: messageId)
            if result {
                call.resolve()
            } else {
                call.reject("Message not found or not available")
            }
        }
    }
}
