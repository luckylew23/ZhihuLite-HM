const path = require('path');

// ----------------------------------------------------------------------------
// 两种构建模式：
//  Android/iOS/Web（上游）  → 原样使用 Expo 的 Metro 配置
//  HarmonyOS（HMOS_BUILD=1）→ 独立构造 Metro 配置 + OHOS 别名层
//
// 为何 HMOS 不用 expo/metro-config：
//   1) expo 的 getDefaultConfig 会读取 app.json 的 expo.plugins 并逐个解析其
//      config-plugin（expo-secure-store / expo-file-system / @sentry 等）。
//      OHOS 构建并不需要这些插件，一旦某些 expo 包未安装就会直接中断打包。
//   2) 别名层已经把所有 expo-* 的 import 重定向到 platform/ohos/shims/*，
//      因此打包过程本身不依赖任何 expo 包。
// ----------------------------------------------------------------------------
let config;

if (process.env.HMOS_BUILD === '1') {
  // 以 Metro 官方默认值为底（sourceExts / assetExts 等取自 metro-config defaults）
  config = {
    resolver: {
      assetExts: [
        'bmp', 'gif', 'jpg', 'jpeg', 'png', 'psd', 'svg', 'webp', 'xml',
        'm4v', 'mov', 'mp4', 'mpeg', 'mpg', 'webm',
        'aac', 'aiff', 'caf', 'm4a', 'mp3', 'wav',
        'html', 'pdf', 'yaml', 'yml', 'otf', 'ttf', 'zip',
      ],
      sourceExts: ['js', 'jsx', 'json', 'ts', 'tsx', 'cjs', 'mjs', 'css', 'scss', 'sass'],
      platforms: ['ios', 'android', 'windows', 'web', 'native', 'harmony'],
      resolverMainFields: ['react-native', 'browser', 'main'],
      // 关键：优先取包的 "react-native" 导出条件。
      // 否则 Metro 会走 "import" 条件命中 ESM 构建（如 zustand 的 esm/*.mjs），
      // 其中使用 import.meta，而 Hermes 不支持 →
      // "SyntaxError: `import.meta` is not supported in Hermes"。
      unstable_conditionNames: ['react-native', 'require', 'default'],
    },
    transformer: {
      babelTransformerPath: require.resolve('metro-babel-transformer'),
      // 关键：Metro 默认值是 'missing-asset-registry-path'，不覆盖会导致
      // 任何图片/字体资源都报 "Unable to resolve module missing-asset-registry-path"
      assetRegistryPath: '@react-native/assets-registry/registry',
      assetPlugins: [],
      getTransformOptions: async () => ({
        transform: { experimentalImportSupport: false, inlineRequires: false },
      }),
    },
    serializer: {
      getModulesRunBeforeMainModule: () => [],
      getPolyfills: () => [],
    },
    server: { port: 8081 },
    watchFolders: [],
    projectRoot: __dirname,
  };
} else {
  const { getDefaultConfig } = require('expo/metro-config');
  const { withNativeWind } = require('nativewind/metro');
  config = withNativeWind(getDefaultConfig(__dirname), { input: './global.css' });
}

// ============================================================================
// HarmonyOS (HMOS) 别名层
// ----------------------------------------------------------------------------
// 在 HMOS_BUILD=1 时，把业务代码里对 Expo / 部分 RN 第三方库的 import 重定向到
// platform/ohos/shims/* 下的鸿蒙兼容实现，并解析 tsconfig 的 '@/*' 路径别名。
// 这样 app/ components/ store/ api/ utils/ 等源码【完全不需要改动】，
// 与上游 rebase 时冲突面极小。
//
// 用 resolver.resolveRequest（而非 resolver.extraNodeModules）：
//   - extraNodeModules 只能按「包名」整体替换，无法处理带子路径的模块名
//     （如 'expo-file-system/legacy'、'expo-router/entry'）
//   - resolveRequest 接收完整模块请求名，可精确匹配子路径与自定义前缀
// ============================================================================
if (process.env.HMOS_BUILD === '1') {
  const shim = (name) => path.join(__dirname, 'platform', 'ohos', 'shims', name);
  const stubPath = (name) => path.join(__dirname, 'platform', 'ohos', 'stubs', name);

  // 注意：React Native 运行时**不要**重定向到 @react-native-ohos/react-native——
  // 该包在 npm/ohpm 上不存在（RNOH 适配发生在原生层，JS 层仍用标准 react-native）。
  const ALIASES = {
    // —— Expo 叶子模块 → 鸿蒙兼容实现 ——
    'expo-secure-store': shim('expoSecureStore.ts'),
    'expo-crypto': shim('expoCrypto.ts'),
    'expo-clipboard': shim('expoClipboard.ts'),
    'expo-file-system': shim('expoFileSystem.ts'),
    // ⚠️ 子路径必须显式列出：useAuthStore / saveImage / UpdateChecker 都在用
    'expo-file-system/legacy': shim('expoFileSystemLegacy.ts'),
    'expo-linking': shim('expoLinking.ts'),
    'expo-web-browser': shim('expoWebBrowser.ts'),
    'expo-sharing': shim('expoSharing.ts'),
    'expo-intent-launcher': shim('expoIntentLauncher.ts'),
    'expo-haptics': shim('expoHaptics.ts'),
    'expo-blur': shim('expoBlur.tsx'),
    'expo-linear-gradient': shim('expoLinearGradient.tsx'),
    'expo-status-bar': shim('expoStatusBar.tsx'),
    'expo-screen-orientation': shim('expoScreenOrientation.ts'),
    'expo-splash-screen': shim('expoSplashScreen.ts'),
    'expo-constants': shim('expoConstants.ts'),
    'expo-sqlite': shim('expoSqlite.ts'),
    'expo-media-library': shim('expoMediaLibrary.ts'),

    // —— Expo 原生桥 / 资源：OHOS 无等价实现，用降级垫片 ——
    // （expo-modules-core 由 expo-font → @expo/vector-icons 的 Ionicons 间接依赖）
    'expo-modules-core': shim('expoModulesCore.ts'),
    'expo-asset': shim('expoAsset.ts'),

    // —— 第三方 RN 库（OHOS 无原生实现，用兼容垫片）——
    '@react-native-cookies/cookies': shim('reactNativeCookies.ts'),
    'react-native-root-siblings': shim('reactNativeRootSiblings.tsx'),

    // —— Expo Router → 基于 React Navigation 的兼容层 ——
    'expo-router': shim('expoRouter.tsx'),
    'expo-router/html': shim('expoRouterHtml.tsx'),
    'expo-router/entry': shim('expoRouterEntry.tsx'),
  };

  // 可选 OHOS 原生包：真实设备上提供原生能力；若未安装，解析失败时回退纯 JS stub，
  // 保证打包不中断（功能降级，见 platform/ohos/stubs/*）。
  const OPTIONAL_OHOS_PACKAGES = {
    '@react-native-ohos/async-storage': stubPath('asyncStorage.ts'),
    '@react-native-ohos/clipboard': stubPath('clipboard.ts'),
    '@react-native-ohos/media-library': stubPath('mediaLibrary.ts'),
    '@react-native-ohos/sqlite-storage': stubPath('sqliteStorage.ts'),
  };
  const fallbackWarned = new Set();

  config.resolver.resolveRequest = (context, moduleName, platform) => {
    let request = moduleName;
    if (moduleName.startsWith('@/')) {
      // tsconfig paths: { "@/*": ["./*"] } —— 上游大量使用 '@/store/xxx' 等
      request = path.join(__dirname, moduleName.slice(2));
    } else if (Object.prototype.hasOwnProperty.call(ALIASES, moduleName)) {
      request = ALIASES[moduleName];
    }

    try {
      return context.resolveRequest(context, request, platform);
    } catch (e) {
      // 可选 OHOS 原生包缺失 → 回退 JS stub
      const stub = OPTIONAL_OHOS_PACKAGES[moduleName];
      if (stub) {
        if (!fallbackWarned.has(moduleName)) {
          fallbackWarned.add(moduleName);
          console.warn('[OHOS] ' + moduleName + ' 未安装，回退到 JS stub（功能降级）');
        }
        return context.resolveRequest(context, stub, platform);
      }
      throw e;
    }
  };
}

module.exports = config;
