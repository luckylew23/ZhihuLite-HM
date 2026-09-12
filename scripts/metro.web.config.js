/**
 * metro.web.config.js —— Expo Web 导出专用 Metro 配置
 * ---------------------------------------------------------------------------
 * 由 scripts/build-web.sh 在 `expo export --platform web` 期间临时替换到上游
 * 工程根目录（导出结束后自动还原），因此上游 metro.config.js 保持原样，
 * 不会污染 Android/iOS 构建，也保证与上游 rebase 零冲突。
 *
 * 与上游 metro.config.js 的差异（全部仅在 platform === 'web' 下生效）：
 *   1) react-native-pager-view -> 库自带 index.web.js
 *      其 main/module 指向 native-only 实现
 *      （PagerViewNativeComponent -> codegenNativeCommands），
 *      Metro 会报 "Importing native-only module ... on web" 而打包失败。
 *   2) 无 Web 实现的原生模块 -> platform/web/shims/*（见 WEB_ALIASES）
 *      例如 expo-sqlite 的 web 实现依赖 .wasm，Metro 无法解析。
 *
 * ⚠️ 注意：绝不能把 expo-router 加入别名 —— Web 端必须使用真正的
 *    expo-router 来做路由（OHOS 版的 expoRouter.tsx 不适用于 web）。
 * ---------------------------------------------------------------------------
 */
const path = require('path');
const { getDefaultConfig } = require('expo/metro-config');
const { withNativeWind } = require('nativewind/metro');

const config = getDefaultConfig(__dirname);

// HMOS 仓库根目录，由 build-web.sh 注入（用于定位 platform/web/shims/*）
const HMOS_ROOT =
  process.env.HMOS_ROOT || path.resolve(__dirname, '..', 'zhihu--HMOS');
const webShim = (name) => path.join(HMOS_ROOT, 'platform', 'web', 'shims', name);

// Web 端缺失实现、会导致打包失败或运行时崩溃的模块
const WEB_ALIASES = {
  'expo-sqlite': webShim('expoSqlite.ts'),
  // SSG 阶段在 Node 里跑，这两个模块均无 Web 实现，会直接让 export 崩溃
  'expo-file-system': webShim('expoFileSystemLegacy.ts'),
  'expo-file-system/legacy': webShim('expoFileSystemLegacy.ts'),
  'expo-secure-store': webShim('expoSecureStore.ts'),
  // 纯原生 TurboModule，Web 下 getEnforcing 返回 undefined，模块工厂直接抛错
  '@preeternal/react-native-cookie-manager': webShim(
    'reactNativeCookieManager.ts',
  ),
  // Web 下只会渲染「不支持此平台」占位且从不触发 onMessage，
  // 而首页靠它解锁游客 feed 门禁 → 必须垫片化
  'react-native-webview': webShim('reactNativeWebView.ts'),
  // 后续若再遇到 "Unable to resolve ..." 的原生模块，在这里补一行即可
};

// Web 垫片位于 HMOS 仓库（上游 projectRoot 之外）。不加入 watchFolders 时
// Metro 无法为其计算 SHA-1，会报
//   "Failed to get the SHA-1 for: .../platform/web/shims/xxx.ts"
config.watchFolders = (config.watchFolders || []).concat([
  path.join(HMOS_ROOT, 'platform'),
]);

const originalResolveRequest = config.resolver.resolveRequest;

config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (platform === 'web') {
    if (moduleName === 'react-native-pager-view') {
      return {
        type: 'sourceFile',
        filePath: path.resolve(
          __dirname,
          'node_modules/react-native-pager-view/index.web.js',
        ),
      };
    }
    if (Object.prototype.hasOwnProperty.call(WEB_ALIASES, moduleName)) {
      return { type: 'sourceFile', filePath: WEB_ALIASES[moduleName] };
    }
  }
  return (originalResolveRequest || context.resolveRequest)(
    context,
    moduleName,
    platform,
  );
};

module.exports = withNativeWind(config, { input: './global.css' });
