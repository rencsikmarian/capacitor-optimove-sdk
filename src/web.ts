import { WebPlugin } from '@capacitor/core';

import type { OptimoveSDKPlugin } from './definitions';

export class OptimoveSDKWeb extends WebPlugin implements OptimoveSDKPlugin {
  async setCredentials(): Promise<void> {
    this.logUnavailable('setCredentials');
  }
  async setUserId(): Promise<void> {
    this.logUnavailable('setUserId');
  }
  async setUserEmail(): Promise<void> {
    this.logUnavailable('setUserEmail');
  }
  async registerUser(): Promise<void> {
    this.logUnavailable('registerUser');
  }
  async getVisitorId(): Promise<{ visitorId: string }> {
    this.logUnavailable('getVisitorId');
    return { visitorId: '' };
  }
  async signOutUser(): Promise<void> {
    this.logUnavailable('signOutUser');
  }
  async reportEvent(): Promise<void> {
    this.logUnavailable('reportEvent');
  }
  async reportScreenVisit(): Promise<void> {
    this.logUnavailable('reportScreenVisit');
  }
  async pushRequestDeviceToken(): Promise<void> {
    this.logUnavailable('pushRequestDeviceToken');
  }
  async pushUnregister(): Promise<void> {
    this.logUnavailable('pushUnregister');
  }
  async inAppUpdateConsent(): Promise<void> {
    this.logUnavailable('inAppUpdateConsent');
  }
  async inAppGetInboxItems(): Promise<{ items: [] }> {
    this.logUnavailable('inAppGetInboxItems');
    return { items: [] };
  }
  async inAppGetInboxSummary(): Promise<{
    totalCount: number;
    unreadCount: number;
  }> {
    this.logUnavailable('inAppGetInboxSummary');
    return { totalCount: 0, unreadCount: 0 };
  }
  async inAppMarkAsRead(): Promise<void> {
    this.logUnavailable('inAppMarkAsRead');
  }
  async inAppMarkAllInboxItemsAsRead(): Promise<void> {
    this.logUnavailable('inAppMarkAllInboxItemsAsRead');
  }
  async inAppPresentInboxMessage(): Promise<{ result: number }> {
    this.logUnavailable('inAppPresentInboxMessage');
    return { result: 0 };
  }
  async inAppDeleteMessageFromInbox(): Promise<void> {
    this.logUnavailable('inAppDeleteMessageFromInbox');
  }

  private logUnavailable(method: string): void {
    console.warn(`OptimoveSDK: ${method} is not available on web.`);
  }
}
