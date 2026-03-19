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

    private let implementation = OptimoveSDKImplementation()

    // MARK: - Lifecycle

    /// Called when the JS bridge is ready. SDK should already be initialized
    /// from AppDelegate via OptimoveSDKImplementation.initializeFromConfig().
    /// This just wires up the event callback so native events reach JS.
    override public func load() {
        OptimoveSDKImplementation.eventCallback = { [weak self] eventName, data in
            self?.notifyListeners(eventName, data: data)
        }

        // Deliver any events that arrived before the JS bridge was ready
        OptimoveSDKImplementation.deliverPendingEvents()
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
        call.resolve(["visitorId": implementation.getVisitorId() ?? ""])
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
