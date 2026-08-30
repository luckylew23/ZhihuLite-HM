# Expo / RN → HarmonyOS 模块映射表

> 本表列出原项目用到的每个平台专属模块，在 OHOS 构建时如何被 `platform/ohos/shims/*` 或
> `@react-native-ohos/*` 端口替代。所有垫片在 `HMOS_BUILD=1` 时由 `metro.config.js` 的
> `resolver.alias` 自动重定向，业务代码 **无需修改**。

## 1. Expo 叶子模块 → 鸿蒙垫片

| 原模块 | OHOS 替代 | 垫片文件 | 实现说明 |
|--------|-----------|----------|----------|
| `expo-secure-store` | KV 存储 | `expoSecureStore.ts` | 基于 `@react-native-ohos/async-storage`，缺省退化为内存 |
| `expo-crypto` | 纯 JS | `expoCrypto.ts` + `cryptoImpl.ts` | 自带 MD5 / SHA-256，零原生依赖（zse96 签名可用） |
| `expo-clipboard` | KV / 原生 | `expoClipboard.ts` | 优先 `@react-native-ohos/clipboard`，否则应用内 KV |
| `expo-file-system` | KV 模拟 | `expoFileSystem.ts` | `documentDirectory`/`cacheDirectory`/`getInfo`/`read`/`write`/`delete` |
| `expo-file-system/legacy` | 同上 | `expoFileSystemLegacy.ts` | 直接 re-export 主模块 |
| `expo-linking` | RN Linking | `expoLinking.ts` | `createURL`/`parse`/`addEventListener` 等委托 |
| `expo-web-browser` | RN Linking | `expoWebBrowser.ts` | `openBrowserAsync`/`openAuthSessionAsync` 改为系统打开 |
| `expo-sharing` | RN Share | `expoSharing.ts` | `shareAsync` 委托 `Share.share` |
| `expo-intent-launcher` | 空操作 | `expoIntentLauncher.ts` | Android 专属，OHOS 无等价，降级 no-op |
| `expo-haptics` | 空操作 | `expoHaptics.ts` | 触感反馈降级（不影响逻辑） |
| `expo-media-library` | 系统分享降级 | `expoMediaLibrary.ts` | `requestPermissionsAsync` 返回未授权 → 上层走分享 |
| `expo-blur` | 半透明 | `expoBlur.tsx` | `BlurView` 降级为 rgba 遮罩 |
| `expo-linear-gradient` | SVG | `expoLinearGradient.tsx` | 用 `react-native-svg` 实现渐变（OHOS 原生支持） |
| `expo-status-bar` | RN StatusBar | `expoStatusBar.tsx` | 直接透传 |
| `expo-screen-orientation` | 空操作 | `expoScreenOrientation.ts` | 旋转锁定降级 |
| `expo-splash-screen` | 空操作 | `expoSplashScreen.ts` | 启动页由 Ability 控制 |
| `expo-constants` | 内置常量 | `expoConstants.ts` | 提供 `expoConfig`/`platform` 等最小字段 |
| `expo-sqlite` | OHOS SQLite | `expoSqlite.ts` | 委托 `@react-native-ohos/sqlite-storage`（需安装） |
| `expo-router` | React Navigation | `expoRouter.tsx` | `useRouter`/`useLocalSearchParams`/`Link`/`Redirect`/`Stack`/`Slot` |
| `expo-router/entry` | 自定义入口 | `ohos/index.tsx` | `AppRegistry.registerComponent('zhihu--', App)` |
| `expo-router/html` | 透传 | `expoRouterHtml.tsx` | Web 专用，OHOS 透传 |

## 2. 第三方 RN 库 → OHOS 端口

| 原模块 | OHOS 替代 | 备注 |
|--------|-----------|------|
| `react-native` | `@react-native-ohos/react-native` | Metro 别名整体重定向 |
| `@react-native-cookies/cookies` | 垫片 | `reactNativeCookies.ts`（KV Cookie Jar） |
| `react-native-root-siblings` | 垫片 | `reactNativeRootSiblings.tsx` 直接渲染子节点 |
| `react-native-safe-area-context` | `@react-native-ohos/safe-area-context` | 由 `package.ohos.json` 提供 |
| `react-native-screens` | `@react-native-ohos/screens` | 同上 |
| `react-native-svg` | `@react-native-ohos/svg` | 同上 |
| `react-native-reanimated` | `@react-native-ohos/reanimated` | 同上 |
| `react-native-gesture-handler` | `@react-native-ohos/gesture-handler` | 同上 |
| `react-native-webview` | `@react-native-ohos/webview` | 登录 WebView 依赖 |
| `react-native-pager-view` | `@react-native-ohos/pager-view` | 横滑翻页 |
| `@shopify/flash-list` | `@react-native-ohos/flash-list` | 列表 |
| `react-native-render-html` | 同包（OHOS 兼容） | 富文本渲染 |
| `react-native-image-zoom-viewer` | 同包（OHOS 兼容） | 图片预览 |
| `@react-native-masked-view/masked-view` | 同包（OHOS 兼容） | 遮罩 |

> 上述 `@react-native-ohos/*` 端口需在 `package.ohos.json` 中声明并安装；
> 清单见该文件 `dependencies`。

## 3. 纯 JS 库（无需替换，直接复用）

`axios`、`@tanstack/react-query`、`zustand`、`nativewind`、`tailwindcss`、
`@react-navigation/native`、`expo-zse96` 签名逻辑（`api/zse96/*`）等——平台无关，OHOS 下原样使用。

## 4. 如何新增一个被上层依赖的 Expo 模块

1. 在 `platform/ohos/shims/` 新建 `<moduleName>.ts(x)`，实现上游用到的 API 表面。
2. 在 `metro.config.js` 的 `config.resolver.alias` 中加一行：
   ```js
   'expo-xxx': shim('expoXxx.ts'),
   ```
3. 若需真实原生能力，改在 `package.ohos.json` 增加 `@react-native-ohos/xxx` 并让垫片委托之。
4. 更新本表。
