import Foundation
import OptimoveSDK

/// Callback type for delivering events from native to the plugin bridge
public typealias OptimoveEventCallback = (_ eventName: String, _ data: [String: Any]) -> Void

@objc public class OptimoveSDKImpl: NSObject {

    private static var pendingPush: PushNotification?
    private static var pendingDdl: DeepLinkResolution?

    private static let sdkVersion = "1.0.0"
    private static let sdkTypeCapacitor = 107
    private static let runtimeTypeCapacitor = 4

    private var eventCallback: OptimoveEventCallback?

    public func setEventCallback(_ callback: @escaping OptimoveEventCallback) {
        self.eventCallback = callback
    }

    // MARK: - Initialization

    public func initialize(
        optimoveCredentials: String?,
        optimoveMobileCredentials: String?,
        inAppConsentStrategy: String,
        enableDeferredDeepLinking: Bool,
        ddlCname: String?,
        enableDelayedInitialization: Bool,
        delayedRegion: String?,
        delayedEnableOptimove: Bool,
        delayedEnableOptimobile: Bool
    ) {
        var builder: OptimoveConfigBuilder

        if enableDelayedInitialization {
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
                print("OptimoveSDK: No credentials provided in capacitor.config")
                return
            }
            builder = OptimoveConfigBuilder(
                optimoveCredentials: optimoveCredentials,
                optimobileCredentials: optimoveMobileCredentials
            )
        }

        // Standard init without optimobile
        if optimoveMobileCredentials == nil && !enableDelayedInitialization {
            Optimove.initialize(with: builder.build())
            return
        }

        // Delayed init with optimobile disabled
        if enableDelayedInitialization && !delayedEnableOptimobile {
            Optimove.initialize(with: builder.build())
            return
        }

        // Push handlers
        builder.setPushOpenedHandler { [weak self] notification in
            guard let self = self, let cb = self.eventCallback else {
                OptimoveSDKImpl.pendingPush = notification
                return
            }
            cb("pushOpened", OptimoveSDKImpl.pushNotificationToDict(notification))
        }

        if #available(iOS 10, *) {
            builder.setPushReceivedInForegroundHandler { [weak self] notification, completionHandler in
                self?.eventCallback?("pushReceived", OptimoveSDKImpl.pushNotificationToDict(notification))
                completionHandler(.alert)
            }
        }

        // In-app consent
        switch inAppConsentStrategy {
        case "auto-enroll":
            builder.enableInAppMessaging(inAppConsentStrategy: .autoEnroll)
        case "explicit-by-user":
            builder.enableInAppMessaging(inAppConsentStrategy: .explicitByUser)
        default:
            break
        }

        // In-app deep link handler
        builder.setInAppDeepLinkHandler { [weak self] data in
            let dict: [String: Any] = [
                "deepLinkData": data.deepLinkData as Any,
                "messageId": data.messageId,
                "messageData": data.messageData as Any
            ]
            self?.eventCallback?("inAppDeepLink", dict)
        }

        // Deferred deep linking
        if enableDeferredDeepLinking {
            let ddlHandler: DeepLinkHandler = { [weak self] resolution in
                guard let self = self, let cb = self.eventCallback else {
                    OptimoveSDKImpl.pendingDdl = resolution
                    return
                }
                cb("deepLink", OptimoveSDKImpl.ddlResolutionToDict(resolution))
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

        OptimoveInApp.setOnInboxUpdated { [weak self] in
            self?.eventCallback?("inAppInboxUpdated", [:])
        }
    }

    // MARK: - Pending Events (Cold Start)

    public func deliverPendingEvents() {
        if let push = OptimoveSDKImpl.pendingPush {
            eventCallback?("pushOpened", OptimoveSDKImpl.pushNotificationToDict(push))
            OptimoveSDKImpl.pendingPush = nil
        }
        if let ddl = OptimoveSDKImpl.pendingDdl {
            eventCallback?("deepLink", OptimoveSDKImpl.ddlResolutionToDict(ddl))
            OptimoveSDKImpl.pendingDdl = nil
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

    public func getVisitorId() -> String {
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

    public func inAppGetInboxSummary(completion: @escaping (Int, Int) -> Void, failure: @escaping () -> Void) {
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

    /// Returns: 0 = FAILED, 1 = EXPIRED, 2 = PRESENTED, -1 = not found
    public func inAppPresentInboxMessage(messageId: Int) -> Int {
        let inboxItems = OptimoveInApp.getInboxItems()
        guard let msg = inboxItems.first(where: { $0.id == Int64(messageId) }) else {
            return 0 // FAILED
        }

        let presentationResult = OptimoveInApp.presentInboxMessage(item: msg)
        switch presentationResult {
        case .PRESENTED: return 2
        case .EXPIRED: return 1
        default: return 0
        }
    }

    /// Returns true if deleted, false if not found
    public func inAppDeleteMessageFromInbox(messageId: Int) -> Bool {
        let inboxItems = OptimoveInApp.getInboxItems()
        guard let msg = inboxItems.first(where: { $0.id == Int64(messageId) }) else {
            return false
        }
        return OptimoveInApp.deleteMessageFromInbox(item: msg)
    }

    // MARK: - Private Helpers

    private func overrideInstallInfo(builder: OptimoveConfigBuilder) {
        let runtimeInfo: [String: AnyObject] = [
            "id": OptimoveSDKImpl.runtimeTypeCapacitor as AnyObject,
            "version": "8.0.0" as AnyObject,
        ]
        let sdkInfo: [String: AnyObject] = [
            "id": OptimoveSDKImpl.sdkTypeCapacitor as AnyObject,
            "version": OptimoveSDKImpl.sdkVersion as AnyObject,
        ]
        builder.setRuntimeInfo(runtimeInfo: runtimeInfo)
        builder.setSdkInfo(sdkInfo: sdkInfo)

        var isRelease = true
        #if DEBUG
            isRelease = false
        #endif
        builder.setTargetType(isRelease: isRelease)
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
