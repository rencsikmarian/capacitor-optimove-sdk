import type { PluginListenerHandle } from '@capacitor/core';

// Enums

export enum DeepLinkResolution {
  LOOKUP_FAILED = 'LOOKUP_FAILED',
  LINK_NOT_FOUND = 'LINK_NOT_FOUND',
  LINK_EXPIRED = 'LINK_EXPIRED',
  LINK_LIMIT_EXCEEDED = 'LINK_LIMIT_EXCEEDED',
  LINK_MATCHED = 'LINK_MATCHED',
}

export enum OptimoveInAppPresentationResult {
  FAILED = 0,
  EXPIRED = 1,
  PRESENTED = 2,
}

// Interfaces

export interface InAppInboxItem {
  id: number;
  title: string;
  subtitle: string;
  availableFrom: string | null;
  availableTo: string | null;
  dismissedAt: string | null;
  sentAt: string;
  data: Record<string, any> | null;
  isRead: boolean;
  imageUrl: string | null;
}

export interface InAppInboxSummary {
  totalCount: number;
  unreadCount: number;
}

export interface InAppButtonPress {
  deepLinkData: Record<string, any>;
  messageId: number;
  messageData: Record<string, any> | null;
}

export interface PushNotification {
  id: number;
  title: string | null;
  message: string | null;
  data: Record<string, any> | null;
  url: string | null;
  actionId: string | null;
}

export interface DeepLinkContent {
  title: string | null;
  description: string | null;
}

export interface DeepLink {
  resolution: DeepLinkResolution;
  url: string;
  content: DeepLinkContent | null;
  linkData: Record<string, any> | null;
}

// Plugin Interface

export interface OptimoveSDKPlugin {
  // User identification
  setCredentials(options: {
    optimoveCredentials?: string;
    optimobileCredentials?: string;
  }): Promise<void>;
  setUserId(options: { userId: string }): Promise<void>;
  setUserEmail(options: { email: string }): Promise<void>;
  registerUser(options: { userId: string; email: string }): Promise<void>;
  getVisitorId(): Promise<{ visitorId: string }>;
  signOutUser(): Promise<void>;

  // Analytics
  reportEvent(options: {
    event: string;
    params?: Record<string, any>;
  }): Promise<void>;
  reportScreenVisit(options: {
    screenName: string;
    screenCategory?: string;
  }): Promise<void>;

  // Push
  pushRequestDeviceToken(): Promise<void>;
  pushUnregister(): Promise<void>;

  // In-App
  inAppUpdateConsent(options: { consented: boolean }): Promise<void>;
  inAppGetInboxItems(): Promise<{ items: InAppInboxItem[] }>;
  inAppGetInboxSummary(): Promise<InAppInboxSummary>;
  inAppMarkAsRead(options: { id: number }): Promise<void>;
  inAppMarkAllInboxItemsAsRead(): Promise<void>;
  inAppPresentInboxMessage(options: {
    id: number;
  }): Promise<{ result: OptimoveInAppPresentationResult }>;
  inAppDeleteMessageFromInbox(options: { id: number }): Promise<void>;

  // Event listeners (Capacitor pattern)
  addListener(
    eventName: 'pushReceived',
    handler: (notification: PushNotification) => void,
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: 'pushOpened',
    handler: (notification: PushNotification) => void,
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: 'inAppDeepLink',
    handler: (data: InAppButtonPress) => void,
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: 'deepLink',
    handler: (deepLink: DeepLink) => void,
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: 'inAppInboxUpdated',
    handler: () => void,
  ): Promise<PluginListenerHandle>;
  removeAllListeners(): Promise<void>;
}
