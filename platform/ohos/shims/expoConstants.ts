// expo-constants → OHOS 兼容垫片
// 提供最小化的 expoConfig / manifest / platform 等字段，满足 app/_layout.tsx 中的读取。
const expoConfig = {
  name: '知乎--',
  version: '0.4.1',
  scheme: 'zhihu--',
  slug: 'ZhihuMinusMinus',
  icon: './assets/images/icon.png',
  extra: {
    eas: { projectId: 'faa0f061-50e6-4ec4-bb6f-accda0dbd24f' },
    router: {},
  },
};

export const Constants = {
  expoConfig,
  manifest: expoConfig,
  manifest2: { extra: { expoClient: expoConfig } },
  deviceName: 'HarmonyOS Device',
  systemVersion: '1.0',
  platform: { ios: undefined, android: undefined, web: undefined },
  installationId: 'ohos-installation-id',
  sessionId: 'ohos-session-id',
  statusBarHeight: 0,
  isDevice: true,
};

export default Constants;
