import Foundation
import OptimoveSDK

/// Callback type for delivering events from native to the plugin bridge
public typealias OptimoveEventCallback = (_ eventName: String, _ data: [String: Any]) -> Void

@objc public class OptimoveSDKImplementation: NSObject {

    private static var pendingPush: PushNotification?
    private static var pendingDdl: DeepLinkResolution?

    private static let sdkVersion = "1.0.0"
    private static let sdkTypeCapacitor = 107
    private static let runtimeTypeCapacitor = 4

    /// Static callback set by the plugin when it loads (JS bridge ready)
    static var eventCallback: OptimoveEventCallback?

    // MARK: - Early Initialization (call from AppDelegate)

    /// Initialize the Optimove SDK. Call this from AppDelegate.didFinishLaunchingWithOptions.
    /// Reads credentials from Info.plist.
    @objc public static func initializeFromConfig() {
        let optimoveCredentials = infoPlistString("optimoveCredentials")
        let optimoveMobileCredentials = infoPlistString("optimoveMobileCredentials")
        let inAppStrategy = infoPlistString("inAppConsentStrategy") ?? "in-app-disabled"
        let enableDDL = infoPlistBool("enableDeferredDeepLinking")
        let ddlCname = infoPlistString("ddlCname")
        let enableDelayed = infoPlistBool("delayedInitialization.enable")
        let delayedRegion = infoPlistString("delayedInitialization.region")
        let delayedEnableOptimove = infoPlistBool("delayedInitialization.featureSet.enableOptimove")
        let delayedEnableOptimobile = infoPlistBool("delayedInitialization.featureSet.enableOptimobile")

        var builder: OptimoveConfigBuilder

        if enableDelayed {
            let regionStr = delayedRegion ?? "EU"
            let region: OptimobileConfig.Region
            switch regionStr {
            case "DEV": region = .DEV
            case "US": region = .US
            default: region = .EU
            }

            var featureSet: Feature = []
            if delayedEnableOptimove { featureSet.insert(.optimove) }
            if delayedEnableOptimobile { featureSet.insert(.optimobile) }

            builder = OptimoveConfigBuilder(region: region, features: featureSet)
        } else {
            guard optimoveCredentials != nil || optimoveMobileCredentials != nil else {
                print("OptimoveSDK: No credentials found in Info.plist")
                return
            }
            builder = OptimoveConfigBuilder(
                optimoveCredentials: optimoveCredentials,
                optimobileCredentials: optimoveMobileCredentials
            )
        }

        // Standard init without optimobile
        if optimoveMobileCredentials == nil && !enableDelayed {
            Optimove.initialize(with: builder.build())
            print("OptimoveSDK: Initialized successfully")
            return
        }

        // Delayed init with optimobile disabled
        if enableDelayed && !delayedEnableOptimobile {
            Optimove.initialize(with: builder.build())
            return
        }

        // Push handlers
        builder.setPushOpenedHandler { notification in
            guard let cb = eventCallback else {
                pendingPush = notification
                return
            }
            cb("pushOpened", pushNotificationToDict(notification))
        }

        if #available(iOS 10, *) {
            builder.setPushReceivedInForegroundHandler { notification, completionHandler in
                eventCallback?("pushReceived", pushNotificationToDict(notification))
                completionHandler(.alert)
            }
        }

        // In-app consent
        switch inAppStrategy {
        case "auto-enroll":
            builder.enableInAppMessaging(inAppConsentStrategy: .autoEnroll)
        case "explicit-by-user":
            builder.enableInAppMessaging(inAppConsentStrategy: .explicitByUser)
        default:
            break
        }

        // In-app deep link handler
        builder.setInAppDeepLinkHandler { data in
            let dict: [String: Any] = [
                "deepLinkData": data.deepLinkData as Any,
                "messageId": data.messageId,
                "messageData": data.messageData as Any
            ]
            eventCallback?("inAppDeepLink", dict)
        }

        // Deferred deep linking
        if enableDDL {
            let ddlHandler: DeepLinkHandler = { resolution in
                guard let cb = eventCallback else {
                    pendingDdl = resolution
                    return
                }
                cb("deepLink", ddlResolutionToDict(resolution))
            }

            if let cname = ddlCname {
                builder.enableDeepLinking(cname: cname, ddlHandler)
            } else {
                builder.enableDeepLinking(ddlHandler)
            }
        }

        // Override install info for Capacitor
        overrideInstallInfo(builder: builder)

        Optimove.initialize(with: builder.build())

        OptimoveInApp.setOnInboxUpdated {
            eventCallback?("inAppInboxUpdated", [:])
        }
    }

    // MARK: - Pending Events (Cold Start)

    /// Deliver any events that arrived before the JS bridge was ready.
    /// Called by the plugin's load() after setting the event callback.
    public static func deliverPendingEvents() {
        if let push = pendingPush {
            eventCallback?("pushOpened", pushNotificationToDict(push))
            pendingPush = nil
        }
        if let ddl = pendingDdl {
            eventCallback?("deepLink", ddlResolutionToDict(ddl))
            pendingDdl = nil
        }
    }

    // MARK: - User Identification

    public func setCredentials(optimoveCredentials: String?, optimobileCredentials: String?) {
        Optimove.setCredentials(
            optimoveCredentials: optimoveCredentials,
            optimobileCredentials: optimobileCredentials
        )
    }

    public func setUserId(_ userId: String) {
        Optimove.shared.setUserId(userId)
    }

    public func setUserEmail(_ email: String) {
        Optimove.shared.setUserEmail(email: email)
    }

    public func registerUser(userId: String, email: String) {
        Optimove.shared.registerUser(sdkId: userId, email: email)
    }

    public func getVisitorId() -> String? {
        return Optimove.getVisitorID()
    }

    public func signOutUser() {
        Optimove.shared.signOutUser()
    }

    // MARK: - Analytics

    public func reportEvent(name: String, parameters: [String: Any]) {
        Optimove.shared.reportEvent(name: name, parameters: parameters)
    }

    public func reportScreenVisit(screenTitle: String, screenCategory: String?) {
        Optimove.shared.reportScreenVisit(screenTitle: screenTitle, screenCategory: screenCategory)
    }

    // MARK: - Push

    public func pushRequestDeviceToken() {
        Optimove.shared.pushRequestDeviceToken()
    }

    public func pushUnregister() {
        Optimove.shared.pushUnregister()
    }

    // MARK: - In-App Messaging

    public func inAppUpdateConsent(consented: Bool) {
        OptimoveInApp.updateConsent(forUser: consented)
    }

    public func inAppGetInboxItems() -> [[String: Any?]] {
        let inboxItems = OptimoveInApp.getInboxItems()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        return inboxItems.map { item in
            [
                "id": item.id,
                "title": item.title,
                "subtitle": item.subtitle,
                "availableFrom": item.availableFrom.map { formatter.string(from: $0) },
                "availableTo": item.availableTo.map { formatter.string(from: $0) },
                "dismissedAt": item.dismissedAt.map { formatter.string(from: $0) },
                "isRead": item.isRead(),
                "sentAt": formatter.string(from: item.sentAt),
                "imageUrl": item.getImageUrl()?.absoluteString,
                "data": item.data
            ]
        }
    }

    public func inAppGetInboxSummary(completion: @escaping (Int64, Int64) -> Void, failure: @escaping () -> Void) {
        OptimoveInApp.getInboxSummaryAsync { summary in
            guard let summary = summary else {
                failure()
                return
            }
            completion(summary.totalCount, summary.unreadCount)
        }
    }

    public func inAppMarkAsRead(messageId: Int) -> Bool {
        let inboxItems = OptimoveInApp.getInboxItems()
        guard let msg = inboxItems.first(where: { $0.id == Int64(messageId) }) else {
            return false
        }
        return OptimoveInApp.markAsRead(item: msg)
    }

    public func inAppMarkAllInboxItemsAsRead() -> Bool {
        return OptimoveInApp.markAllInboxItemsAsRead()
    }

    public func inAppPresentInboxMessage(messageId: Int) -> Int {
        let inboxItems = OptimoveInApp.getInboxItems()
        guard let msg = inboxItems.first(where: { $0.id == Int64(messageId) }) else {
            return 0
        }

        let presentationResult = OptimoveInApp.presentInboxMessage(item: msg)
        switch presentationResult {
        case .PRESENTED: return 2
        case .EXPIRED: return 1
        default: return 0
        }
    }

    public func inAppDeleteMessageFromInbox(messageId: Int) -> Bool {
        let inboxItems = OptimoveInApp.getInboxItems()
        guard let msg = inboxItems.first(where: { $0.id == Int64(messageId) }) else {
            return false
        }
        return OptimoveInApp.deleteMessageFromInbox(item: msg)
    }

    // MARK: - Private Helpers

    private static func overrideInstallInfo(builder: OptimoveConfigBuilder) {
        let runtimeInfo: [String: AnyObject] = [
            "id": runtimeTypeCapacitor as AnyObject,
            "version": "8.0.0" as AnyObject,
        ]
        let sdkInfo: [String: AnyObject] = [
            "id": sdkTypeCapacitor as AnyObject,
            "version": sdkVersion as AnyObject,
        ]
        builder.setRuntimeInfo(runtimeInfo: runtimeInfo)
        builder.setSdkInfo(sdkInfo: sdkInfo)

        var isRelease = true
        #if DEBUG
            isRelease = false
        #endif
        builder.setTargetType(isRelease: isRelease)
    }

    private static func infoPlistString(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func infoPlistBool(_ key: String) -> Bool {
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

    private static func pushNotificationToDict(_ notification: PushNotification) -> [String: Any] {
        let aps: [AnyHashable: Any] = notification.aps
        var alert: [String: String] = [:]
        if let a = aps["alert"] as? [String: String] {
            alert = a
        }

        return [
            "id": notification.id,
            "title": alert["title"] as Any,
            "message": alert["body"] as Any,
            "data": notification.data as Any,
            "url": notification.url?.absoluteString as Any,
            "actionId": notification.actionIdentifier as Any
        ]
    }

    private static func ddlResolutionToDict(_ resolution: DeepLinkResolution) -> [String: Any] {
        var urlString: String
        var resolutionStr: String
        var content: [String: Any?]?
        var linkData: [AnyHashable: Any?]?

        switch resolution {
        case .lookupFailed(let dl):
            urlString = dl.absoluteString
            resolutionStr = "LOOKUP_FAILED"
        case .linkNotFound(let dl):
            urlString = dl.absoluteString
            resolutionStr = "LINK_NOT_FOUND"
        case .linkExpired(let dl):
            urlString = dl.absoluteString
            resolutionStr = "LINK_EXPIRED"
        case .linkLimitExceeded(let dl):
            urlString = dl.absoluteString
            resolutionStr = "LINK_LIMIT_EXCEEDED"
        case .linkMatched(let dl):
            urlString = dl.url.absoluteString
            resolutionStr = "LINK_MATCHED"
            content = [
                "title": dl.content.title,
                "description": dl.content.description
            ]
            linkData = dl.data
        }

        return [
            "resolution": resolutionStr,
            "url": urlString,
            "content": content as Any,
            "linkData": linkData as Any
        ]
    }
}
