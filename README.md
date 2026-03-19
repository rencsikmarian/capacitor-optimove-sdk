# capacitor-optimove-sdk

Capacitor plugin for the Optimove SDK. Supports push notifications, in-app messaging, analytics, user identification, and deferred deep linking on iOS and Android.

## Install

```bash
npm install capacitor-optimove-sdk
npx cap sync
```

## Credentials

You can retrieve your credentials from **Optimove UI** (Settings > OptiMobile > Mobile Push Config > App Keys):

- **`optimoveCredentials`** - Your unique SDK token to identify your Optimove tenant
- **`optimoveMobileCredentials`** - The mobile config used to identify your app bundle

At least one must be provided to initialize the SDK.

## Configuration

The plugin reads configuration from **`capacitor.config.json`** (primary) with a **native config fallback** (Info.plist on iOS, string resources on Android).

### Option 1: capacitor.config.json (recommended)

Add to your `capacitor.config.json` or `capacitor.config.ts`:

```json
{
  "plugins": {
    "OptimoveSDK": {
      "optimoveCredentials": "YOUR_OPTIMOVE_CREDENTIALS",
      "optimoveMobileCredentials": "YOUR_OPTIMOVE_MOBILE_CREDENTIALS",
      "inAppConsentStrategy": "auto-enroll",
      "enableDeferredDeepLinking": false,
      "ddlCname": "links.yourdomain.com"
    }
  }
}
```

> **Note:** On Android, the SDK initializes via a `ContentProvider` which runs before Capacitor loads. Android always reads from string resources (see Option 2 below). You must configure Android string resources regardless of whether you use `capacitor.config.json`.

### Option 2: Native config files (fallback / Android required)

#### iOS - Info.plist

Add keys to your app's `Info.plist`:

```xml
<key>optimoveCredentials</key>
<string>YOUR_OPTIMOVE_CREDENTIALS</string>
<key>optimoveMobileCredentials</key>
<string>YOUR_OPTIMOVE_MOBILE_CREDENTIALS</string>
<key>inAppConsentStrategy</key>
<string>auto-enroll</string>
<key>enableDeferredDeepLinking</key>
<false/>
```

On iOS, the plugin checks `capacitor.config.json` first. If a key is not found there, it falls back to `Info.plist`.

#### Android - String Resources

Create `android/app/src/main/res/values/optimove.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools">
    <string name="optimoveCredentials"
        tools:ignore="TypographyDashes">YOUR_OPTIMOVE_CREDENTIALS</string>
    <string name="optimoveMobileCredentials"
        tools:ignore="TypographyDashes">YOUR_OPTIMOVE_MOBILE_CREDENTIALS</string>
    <string name="optimoveInAppConsentStrategy"
        tools:ignore="TypographyDashes">auto-enroll</string>
    <string name="optimoveEnableDeferredDeepLinking"
        tools:ignore="TypographyDashes">false</string>
    <string name="android.pushNotificationIconName"
        tools:ignore="TypographyDashes">ic_notification</string>
</resources>
```

### Configuration Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `optimoveCredentials` | string | - | Optimove SDK token |
| `optimoveMobileCredentials` | string | - | Mobile push config token |
| `inAppConsentStrategy` | string | `"in-app-disabled"` | `"auto-enroll"`, `"explicit-by-user"`, or `"in-app-disabled"` |
| `enableDeferredDeepLinking` | boolean | `false` | Enable deferred deep linking |
| `ddlCname` | string | - | Custom CNAME for deep links (iOS only) |

#### Delayed Initialization Keys

For apps that determine credentials at runtime:

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `delayedInitialization.enable` | boolean | `false` | Enable delayed initialization |
| `delayedInitialization.region` | string | `"EU"` | `"EU"`, `"US"`, or `"DEV"` |
| `delayedInitialization.featureSet.enableOptimove` | boolean | `false` | Enable Optimove features |
| `delayedInitialization.featureSet.enableOptimobile` | boolean | `false` | Enable Optimobile features |

## Android Setup

### Firebase

Push notifications require Firebase Cloud Messaging:

1. Add `google-services.json` to `android/app/`
2. Apply the Google Services plugin in your app's `android/app/build.gradle`:

```groovy
apply plugin: 'com.google.gms.google-services'
```

3. Add the classpath to your project-level `android/build.gradle`:

```groovy
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

## iOS Setup

### Initialization (required)

The Optimove SDK must be initialized early in the app lifecycle, before the Capacitor web view loads. Add the following to your `AppDelegate.swift`:

```swift
import capacitor_optimove_sdk

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    OptimoveSDKImplementation.initializeFromConfig()
    return true
}
```

This reads credentials and settings from your `Info.plist`. The Capacitor plugin bridge connects automatically when the web view loads.

### Deep Linking

If you use deferred deep links, add the following to your `AppDelegate.swift` to forward universal links to the Optimove SDK:

```swift
import OptimoveSDK

func application(_ application: UIApplication,
                 continue userActivity: NSUserActivity,
                 restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    return Optimove.shared.application(application, continue: userActivity, restorationHandler: restorationHandler)
}
```

For apps using `SceneDelegate` (iOS 13+):

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    Optimove.shared.scene(scene, continue: userActivity)
}

func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    if let userActivity = connectionOptions.userActivities.first {
        Optimove.shared.scene(scene, continue: userActivity)
    }
}
```

## Usage

```typescript
import { OptimoveSDK } from 'capacitor-optimove-sdk';

// Set user identity
await OptimoveSDK.setUserId({ userId: 'user-123' });
await OptimoveSDK.setUserEmail({ email: 'user@example.com' });

// Track events
await OptimoveSDK.reportEvent({ event: 'purchase', params: { amount: 29.99 } });
await OptimoveSDK.reportScreenVisit({ screenName: 'Home' });

// Push notifications
await OptimoveSDK.pushRequestDeviceToken();

OptimoveSDK.addListener('pushReceived', (notification) => {
  console.log('Push received:', notification);
});

OptimoveSDK.addListener('pushOpened', (notification) => {
  console.log('Push opened:', notification);
});

// In-App inbox
const { items } = await OptimoveSDK.inAppGetInboxItems();
const summary = await OptimoveSDK.inAppGetInboxSummary();

// Deep links
OptimoveSDK.addListener('deepLink', (deepLink) => {
  console.log('Deep link:', deepLink.url, deepLink.resolution);
});
```

## API

<docgen-index>

* [`setCredentials(...)`](#setcredentials)
* [`setUserId(...)`](#setuserid)
* [`setUserEmail(...)`](#setuseremail)
* [`registerUser(...)`](#registeruser)
* [`getVisitorId()`](#getvisitorid)
* [`signOutUser()`](#signoutuser)
* [`reportEvent(...)`](#reportevent)
* [`reportScreenVisit(...)`](#reportscreenvisit)
* [`pushRequestDeviceToken()`](#pushrequestdevicetoken)
* [`pushUnregister()`](#pushunregister)
* [`inAppUpdateConsent(...)`](#inappupdateconsent)
* [`inAppGetInboxItems()`](#inappgetinboxitems)
* [`inAppGetInboxSummary()`](#inappgetinboxsummary)
* [`inAppMarkAsRead(...)`](#inappmarkasread)
* [`inAppMarkAllInboxItemsAsRead()`](#inappmarkallinboxitemsasread)
* [`inAppPresentInboxMessage(...)`](#inapppresentinboxmessage)
* [`inAppDeleteMessageFromInbox(...)`](#inappdeletemessagefrominbox)
* [`addListener('pushReceived', ...)`](#addlistenerpushreceived-)
* [`addListener('pushOpened', ...)`](#addlistenerpushopened-)
* [`addListener('inAppDeepLink', ...)`](#addlistenerinappdeeplink-)
* [`addListener('deepLink', ...)`](#addlistenerdeeplink-)
* [`addListener('inAppInboxUpdated', ...)`](#addlistenerinappinboxupdated-)
* [`removeAllListeners()`](#removealllisteners)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)
* [Enums](#enums)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### setCredentials(...)

```typescript
setCredentials(options: { optimoveCredentials?: string; optimobileCredentials?: string; }) => Promise<void>
```

| Param         | Type                                                                           |
| ------------- | ------------------------------------------------------------------------------ |
| **`options`** | <code>{ optimoveCredentials?: string; optimobileCredentials?: string; }</code> |

--------------------


### setUserId(...)

```typescript
setUserId(options: { userId: string; }) => Promise<void>
```

| Param         | Type                             |
| ------------- | -------------------------------- |
| **`options`** | <code>{ userId: string; }</code> |

--------------------


### setUserEmail(...)

```typescript
setUserEmail(options: { email: string; }) => Promise<void>
```

| Param         | Type                            |
| ------------- | ------------------------------- |
| **`options`** | <code>{ email: string; }</code> |

--------------------


### registerUser(...)

```typescript
registerUser(options: { userId: string; email: string; }) => Promise<void>
```

| Param         | Type                                            |
| ------------- | ----------------------------------------------- |
| **`options`** | <code>{ userId: string; email: string; }</code> |

--------------------


### getVisitorId()

```typescript
getVisitorId() => Promise<{ visitorId: string; }>
```

**Returns:** <code>Promise&lt;{ visitorId: string; }&gt;</code>

--------------------


### signOutUser()

```typescript
signOutUser() => Promise<void>
```

--------------------


### reportEvent(...)

```typescript
reportEvent(options: { event: string; params?: Record<string, any>; }) => Promise<void>
```

| Param         | Type                                                                                      |
| ------------- | ----------------------------------------------------------------------------------------- |
| **`options`** | <code>{ event: string; params?: <a href="#record">Record</a>&lt;string, any&gt;; }</code> |

--------------------


### reportScreenVisit(...)

```typescript
reportScreenVisit(options: { screenName: string; screenCategory?: string; }) => Promise<void>
```

| Param         | Type                                                          |
| ------------- | ------------------------------------------------------------- |
| **`options`** | <code>{ screenName: string; screenCategory?: string; }</code> |

--------------------


### pushRequestDeviceToken()

```typescript
pushRequestDeviceToken() => Promise<void>
```

--------------------


### pushUnregister()

```typescript
pushUnregister() => Promise<void>
```

--------------------


### inAppUpdateConsent(...)

```typescript
inAppUpdateConsent(options: { consented: boolean; }) => Promise<void>
```

| Param         | Type                                 |
| ------------- | ------------------------------------ |
| **`options`** | <code>{ consented: boolean; }</code> |

--------------------


### inAppGetInboxItems()

```typescript
inAppGetInboxItems() => Promise<{ items: InAppInboxItem[]; }>
```

**Returns:** <code>Promise&lt;{ items: InAppInboxItem[]; }&gt;</code>

--------------------


### inAppGetInboxSummary()

```typescript
inAppGetInboxSummary() => Promise<InAppInboxSummary>
```

**Returns:** <code>Promise&lt;<a href="#inappinboxsummary">InAppInboxSummary</a>&gt;</code>

--------------------


### inAppMarkAsRead(...)

```typescript
inAppMarkAsRead(options: { id: number; }) => Promise<void>
```

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: number; }</code> |

--------------------


### inAppMarkAllInboxItemsAsRead()

```typescript
inAppMarkAllInboxItemsAsRead() => Promise<void>
```

--------------------


### inAppPresentInboxMessage(...)

```typescript
inAppPresentInboxMessage(options: { id: number; }) => Promise<{ result: OptimoveInAppPresentationResult; }>
```

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: number; }</code> |

**Returns:** <code>Promise&lt;{ result: <a href="#optimoveinapppresentationresult">OptimoveInAppPresentationResult</a>; }&gt;</code>

--------------------


### inAppDeleteMessageFromInbox(...)

```typescript
inAppDeleteMessageFromInbox(options: { id: number; }) => Promise<void>
```

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: number; }</code> |

--------------------


### addListener('pushReceived', ...)

```typescript
addListener(eventName: 'pushReceived', handler: (notification: PushNotification) => void) => Promise<PluginListenerHandle>
```

| Param           | Type                                                                                     |
| --------------- | ---------------------------------------------------------------------------------------- |
| **`eventName`** | <code>'pushReceived'</code>                                                              |
| **`handler`**   | <code>(notification: <a href="#pushnotification">PushNotification</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('pushOpened', ...)

```typescript
addListener(eventName: 'pushOpened', handler: (notification: PushNotification) => void) => Promise<PluginListenerHandle>
```

| Param           | Type                                                                                     |
| --------------- | ---------------------------------------------------------------------------------------- |
| **`eventName`** | <code>'pushOpened'</code>                                                                |
| **`handler`**   | <code>(notification: <a href="#pushnotification">PushNotification</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('inAppDeepLink', ...)

```typescript
addListener(eventName: 'inAppDeepLink', handler: (data: InAppButtonPress) => void) => Promise<PluginListenerHandle>
```

| Param           | Type                                                                             |
| --------------- | -------------------------------------------------------------------------------- |
| **`eventName`** | <code>'inAppDeepLink'</code>                                                     |
| **`handler`**   | <code>(data: <a href="#inappbuttonpress">InAppButtonPress</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('deepLink', ...)

```typescript
addListener(eventName: 'deepLink', handler: (deepLink: DeepLink) => void) => Promise<PluginListenerHandle>
```

| Param           | Type                                                                 |
| --------------- | -------------------------------------------------------------------- |
| **`eventName`** | <code>'deepLink'</code>                                              |
| **`handler`**   | <code>(deepLink: <a href="#deeplink">DeepLink</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('inAppInboxUpdated', ...)

```typescript
addListener(eventName: 'inAppInboxUpdated', handler: () => void) => Promise<PluginListenerHandle>
```

| Param           | Type                             |
| --------------- | -------------------------------- |
| **`eventName`** | <code>'inAppInboxUpdated'</code> |
| **`handler`**   | <code>() =&gt; void</code>       |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => Promise<void>
```

--------------------


### Interfaces


#### InAppInboxItem

| Prop                | Type                                                                 |
| ------------------- | -------------------------------------------------------------------- |
| **`id`**            | <code>number</code>                                                  |
| **`title`**         | <code>string</code>                                                  |
| **`subtitle`**      | <code>string</code>                                                  |
| **`availableFrom`** | <code>string \| null</code>                                          |
| **`availableTo`**   | <code>string \| null</code>                                          |
| **`dismissedAt`**   | <code>string \| null</code>                                          |
| **`sentAt`**        | <code>string</code>                                                  |
| **`data`**          | <code><a href="#record">Record</a>&lt;string, any&gt; \| null</code> |
| **`isRead`**        | <code>boolean</code>                                                 |
| **`imageUrl`**      | <code>string \| null</code>                                          |


#### InAppInboxSummary

| Prop              | Type                |
| ----------------- | ------------------- |
| **`totalCount`**  | <code>number</code> |
| **`unreadCount`** | <code>number</code> |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### PushNotification

| Prop           | Type                                                                 |
| -------------- | -------------------------------------------------------------------- |
| **`id`**       | <code>number</code>                                                  |
| **`title`**    | <code>string \| null</code>                                          |
| **`message`**  | <code>string \| null</code>                                          |
| **`data`**     | <code><a href="#record">Record</a>&lt;string, any&gt; \| null</code> |
| **`url`**      | <code>string \| null</code>                                          |
| **`actionId`** | <code>string \| null</code>                                          |


#### InAppButtonPress

| Prop               | Type                                                                 |
| ------------------ | -------------------------------------------------------------------- |
| **`deepLinkData`** | <code><a href="#record">Record</a>&lt;string, any&gt;</code>         |
| **`messageId`**    | <code>number</code>                                                  |
| **`messageData`**  | <code><a href="#record">Record</a>&lt;string, any&gt; \| null</code> |


#### DeepLink

| Prop             | Type                                                                 |
| ---------------- | -------------------------------------------------------------------- |
| **`resolution`** | <code><a href="#deeplinkresolution">DeepLinkResolution</a></code>    |
| **`url`**        | <code>string</code>                                                  |
| **`content`**    | <code><a href="#deeplinkcontent">DeepLinkContent</a> \| null</code>  |
| **`linkData`**   | <code><a href="#record">Record</a>&lt;string, any&gt; \| null</code> |


#### DeepLinkContent

| Prop              | Type                        |
| ----------------- | --------------------------- |
| **`title`**       | <code>string \| null</code> |
| **`description`** | <code>string \| null</code> |


### Type Aliases


#### Record

Construct a type with a set of properties K of type T

<code>{ [P in K]: T; }</code>


### Enums


#### OptimoveInAppPresentationResult

| Members         | Value          |
| --------------- | -------------- |
| **`FAILED`**    | <code>0</code> |
| **`EXPIRED`**   | <code>1</code> |
| **`PRESENTED`** | <code>2</code> |


#### DeepLinkResolution

| Members                   | Value                              |
| ------------------------- | ---------------------------------- |
| **`LOOKUP_FAILED`**       | <code>'LOOKUP_FAILED'</code>       |
| **`LINK_NOT_FOUND`**      | <code>'LINK_NOT_FOUND'</code>      |
| **`LINK_EXPIRED`**        | <code>'LINK_EXPIRED'</code>        |
| **`LINK_LIMIT_EXCEEDED`** | <code>'LINK_LIMIT_EXCEEDED'</code> |
| **`LINK_MATCHED`**        | <code>'LINK_MATCHED'</code>        |

</docgen-api>
