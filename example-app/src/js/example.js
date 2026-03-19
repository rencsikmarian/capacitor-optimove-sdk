import { OptimoveSDK } from 'capacitor-optimove-sdk';

// Event listeners
OptimoveSDK.addListener('pushReceived', (notification) => {
  console.log('Push received:', notification);
  document.getElementById('output').textContent = JSON.stringify(notification, null, 2);
});

OptimoveSDK.addListener('pushOpened', (notification) => {
  console.log('Push opened:', notification);
});

OptimoveSDK.addListener('inAppDeepLink', (data) => {
  console.log('In-app deep link:', data);
});

OptimoveSDK.addListener('deepLink', (deepLink) => {
  console.log('Deep link:', deepLink);
});

OptimoveSDK.addListener('inAppInboxUpdated', () => {
  console.log('Inbox updated');
});

// User identification
window.testSetUserId = async () => {
  const userId = document.getElementById('userIdInput').value;
  await OptimoveSDK.setUserId({ userId });
  console.log('User ID set');
};

window.testGetVisitorId = async () => {
  const { visitorId } = await OptimoveSDK.getVisitorId();
  document.getElementById('output').textContent = 'Visitor ID: ' + visitorId;
};

// Analytics
window.testReportEvent = async () => {
  await OptimoveSDK.reportEvent({ event: 'test_event', params: { key: 'value' } });
  console.log('Event reported');
};

// Push
window.testRequestPush = async () => {
  await OptimoveSDK.pushRequestDeviceToken();
  console.log('Push token requested');
};

// In-App
window.testGetInboxItems = async () => {
  const { items } = await OptimoveSDK.inAppGetInboxItems();
  document.getElementById('output').textContent = JSON.stringify(items, null, 2);
};
