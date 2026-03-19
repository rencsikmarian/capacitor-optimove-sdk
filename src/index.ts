import { registerPlugin } from '@capacitor/core';

import type { OptimoveSDKPlugin } from './definitions';

const OptimoveSDK = registerPlugin<OptimoveSDKPlugin>('OptimoveSDK', {
  web: () => import('./web').then((m) => new m.OptimoveSDKWeb()),
});

export * from './definitions';
export { OptimoveSDK };
