# HarmonyOS NEXT 转换 · 架构分析

> 配套：仓库结构 → [`OHOS_REPO_STRUCTURES.md`](./OHOS_REPO_STRUCTURES.md) ｜
> 总体方案 → [`OHOS_MIGRATION.md`](./OHOS_MIGRATION.md) ｜
> 模块映射 → [`EXPO_OHOS_MAPPING.md`](./EXPO_OHOS_MAPPING.md) ｜
> 构建 → [`OHOS_BUILD.md`](./OHOS_BUILD.md)

本文分两部分：**(一) 源项目（Expo/RN）架构**，**(二) 鸿蒙适配层的架构与映射**。

---

# 一、源项目架构（luckylew23/zhihu--）

## 1.1 技术栈

| 层 | 选型 |
|----|------|
| 框架 | React Native 0.83 + Expo SDK 55 |
| 路由 | Expo Router（**文件路由**，目录即路由） |
| 数据获取 | TanStack Query v5（无限滚动、缓存、重试） |
| 状态管理 | Zustand（auth / theme / settings / collection …） |
| 样式 | NativeWind（Tailwind CSS 原子化，跑在 RN 上） |
| 请求 | Axios（拦截器统一加签 / 注入 Cookie） |
| 列表 | `@shopify/flash-list`（高性能 Feed / 评论） |
| 手势/动画 | react-native-gesture-handler + react-native-reanimated |
| 富文本 | react-native-render-html |
| 登录 | react-native-webview 捕获 Cookie |
| 加签 | 自研 `x-zse-96` / `x-zse-93` 签名算法（`api/zse96/`） |

## 1.2 目录分层

```
app/            Expo Router 页面（文件路由）。(tabs) 组 = 自定义底部 Tab
components/     UI 组件（FeedCard / 评论 / 弹窗 / Themed …）
store/          Zustand 全局状态
api/            api/client.ts（Axios+加签+Cookie 拦截器）、api/zhihu/* 业务接口、api/zse96/* 签名
utils/          url/clipboard/feedDedup/feedFilter/query … 纯逻辑
hooks/          useZhihuInfiniteQuery / useScrollAnimation …
constants/      Colors（知乎蓝 #0084ff）
storage/        Feed 缓存 / 曝光记录（底层 sqlite / KV）
```

## 1.3 关键机制

- **通信枢纽**：`api/client.ts` 在 Axios 拦截器里注入 `x-zse-96/93` 签名、模拟移动端
  User-Agent、在登录后把 `z_c0` / `d_c0` Cookie 注入请求头；Cookie 由
  `react-native-cookies` 在 WebView 登录后拦截。
- **路由**：Expo Router 文件路由。`app/(tabs)/index.tsx` 是首页，**它内部用 PagerView +
  自定义底部栏** 实现「关注/推荐/热榜/日报/发布/我的」横向滑动切换——即本项目**没有原生
  Tab 栏**，底部栏是自绘的。深层链接经 `app/_layout.tsx` 的 `Linking` 监听做归一化分发。
- **主题**：`useThemeStore` 控制暗/亮，并 `useSyncThemeWithNativeWind()` 同步给 NativeWind；
  支持跟随系统 + 手动覆盖 + 全局主题色。
- **登录闭环**：WebView 登录 → 拦截 Cookie → `expo-secure-store` 持久化 → 后续请求自动注入。

> ⚠️ 关键事实：**根布局 `app/_layout.tsx` 承载了大量「跨页面全局逻辑」**——QueryClient 重试策略、
> 主题/状态栏、剪贴板链接弹窗、`Linking` 深度链接监听、`AppState` 剪贴板检查、人机验证弹窗、
> 收藏弹窗、全局渐变遮罩。鸿蒙入口不能直接复用它（见下文 2.3）。

---

# 二、鸿蒙适配层架构

转换路线：**React Native OpenHarmony（RNOH）端口**——保留 ~95% 业务代码，仅把
「原生层 + Expo 专属模块」替换为鸿蒙兼容实现。不采用全量 ArkTS 重写（成本极高且与上游无法共享）。

整体分 5 层，自上而下：

```
┌─────────────────────────────────────────────────────────────┐
│  harmony/  —— DevEco 原生宿主工程（ArkTS）                  │
│   EntryAbility → RNOHApp({appKey:"zhihu--"}) → 拉起 JS 根   │
└───────────────────────────┬─────────────────────────────────┘
                            │ (RNOH 运行时桥)
┌───────────────────────────┴─────────────────────────────────┐
│  ohos/  —— OHOS JS 入口与导航树                             │
│   index.tsx → AppRegistry.registerComponent                  │
│   App.tsx → 重建 React Navigation 树 + 承载全局根逻辑        │
│   routeRegistry.ts → URL ↔ 路由名 映射表                     │
└───────────────────────────┬─────────────────────────────────┘
                            │ import（被别名重定向）
┌───────────────────────────┴─────────────────────────────────┐
│  platform/ohos/shims/* —— 鸿蒙兼容垫片                      │
│   expo-router / expo-secure-store / expo-crypto / …         │
└───────────────────────────┬─────────────────────────────────┘
                            │ 别名层 (metro.config.js, HMOS_BUILD=1)
┌───────────────────────────┴─────────────────────────────────┐
│  app/ components/ store/ api/ utils/  —— 上游源码【不改】   │
└─────────────────────────────────────────────────────────────┘
```

## 2.1 别名层（metro.config.js）

`HMOS_BUILD=1` 时，`metro.config.js` 用 `resolver.extraNodeModules` 把上游代码里的
`expo-*` 与部分 RN 第三方库重定向到 `platform/ohos/shims/*`。因此业务代码对
`expo-router`、`expo-secure-store` 等的 import **逐字节不变**，与上游 rebase 几乎零冲突。
（详见 [`EXPO_OHOS_MAPPING.md`](./EXPO_OHOS_MAPPING.md) 的模块级映射表。）

## 2.2 expo-router 兼容垫片

`platform/ohos/shims/expoRouter.tsx` 提供 `useRouter / useLocalSearchParams / Link /
Redirect / Stack / Slot / useNavigation / useFocusEffect …` 的 API 表面，把
`router.push('/question/123')` 解析为 React Navigation 的 `navigate(name, params)`，
解析表来自 `ohos/routeRegistry.ts` 的 `ROUTE_TABLE`。由于真正的导航树由 `ohos/App.tsx`
用 React Navigation 构建，`Stack`/`Slot` 在垫片里是 **no-op（直接渲染子节点）**——
这一点是「头部标题 / 模态 / 动画」必须外置移植到 `ohos/App.tsx` 的根本原因（见 2.3）。

## 2.3 ohos/App.tsx —— 导航树 + 全局根逻辑重建（本次重点）

因为 OHOS 入口不挂载 `app/_layout.tsx`，本文件负责：

1. **重建导航树**：`(tabs)` 直接映射到 HomeScreen（`app/(tabs)/index`）。
   ⚠️ 已修正旧实现对 `(tabs)` 套用原生 `Tab.Navigator` 导致的**双底栏**问题——
   HomeScreen 内部已用 PagerView + 自绘底栏管理全部 Tab，无需再套一层原生 Tab。
2. **头部配置外置**：把 `app/_layout.tsx` 里 `<Stack.Screen options>` 的标题 / 模态 /
   动画声明，移植到 `ohos/App.tsx` 的 `optionsFor(name)`（按路由名返回 header options）。
3. **承载全局根逻辑**：QueryClient（含 40352 人机验证的 retry 策略）、
   `ThemeProvider`、`RootSiblingParent`、全局浮层（剪贴板链接弹窗 / 人机验证 / 收藏 /
   状态栏 / 顶部渐变遮罩），以及 `Linking` 深度链接与 `AppState` 剪贴板监听 → `router.push` 分发。
4. **Sentry 省略**：首版未接入 `@sentry/react-native`（原生依赖在 RNOH 上有风险），
   待后续评估；不影响功能。

## 2.4 harmony/ —— 原生宿主（DevEco 工程，HarmonyOS NEXT）

标准 RNOH 模板：`EntryAbility extends RNAbility`、`MyAbilityStage` 注入
`RNAbilityPackage`、`pages/index.ets` 用 `RNOHApp({ appKey: "zhihu--" })` 拉起 JS 根。
`oh-package.json5` 声明 `@rnoh/react-native-openharmony: 0.83.2`。

> **NEXT 工程约束（已对齐 `harmony/build-profile.json5`）**：
> - `runtimeOS: "HarmonyOS"`、`compatibleSdkVersion: "5.0.0(12)"`（即 HarmonyOS NEXT API 12），
>   产物为 **HAP/APP，不是安卓 APK**；Stage 模型（非 FA）Ability。
> - `AppScope/app.json5` 已补 `minAPIVersion`/`targetAPIVersion` 均为 `5.0.0(12)`。
> - **已移除** `entry/build-profile.json5` 中悬挂的 `externalNativeOptions`（`cpp/CMakeLists.txt`）
>   ——本工程 C++ 侧由 RNOH 预编译 `.so` 提供，应用层无需原生构建选项。

## 2.5 构建编排

`metro.config.js`（`HMOS_BUILD=1` 别名层）+ `package.ohos.json`（OHOS 专用依赖清单，
与原 `package.json` 解耦）+ `scripts/{install,build}-ohos.sh` 串联
「安装 → Metro bundle（入口 `ohos/index.tsx`）→ hvigor assembleHap」。

---

# 三、模块映射速览（详见 EXPO_OHOS_MAPPING.md）

| 上游 | 鸿蒙替代 | 实现位置 |
|------|----------|----------|
| `expo-router` | React Navigation 兼容层 | `platform/ohos/shims/expoRouter.tsx` + `ohos/App.tsx` |
| `expo-secure-store` | KV 存储 | `expoSecureStore.ts`（底层 `_kv.ts`） |
| `expo-crypto` | 纯 JS MD5/SHA256 | `expoCrypto.ts` + `cryptoImpl.ts` |
| `expo-clipboard/-file-system/-linking/-web-browser/-sharing` | KV / RN 委托 | 对应 shim |
| `expo-blur/-linear-gradient/-status-bar/-screen-orientation/-splash-screen` | 半透明 / SVG / 直通 / no-op | 对应 shim |
| `expo-sqlite` | `@react-native-ohos/sqlite-storage`（降级内存） | `expoSqlite.ts` |
| `react-native-cookies` | KV Cookie Jar | `reactNativeCookies.ts` |
| `react-native-root-siblings` | 直接渲染子节点 | `reactNativeRootSiblings.tsx` |
| `react-native` / `react-native-screens` / `-safe-area-context` / `-svg` / `-reanimated` / `-webview` / `-pager-view` / `-gesture-handler` / `-render-html` / `-image-zoom-viewer` / `@shopify/flash-list` | `@react-native-ohos/*` 端口或原包 OHOS 兼容 | `package.ohos.json` + `EXPO_OHOS_MAPPING.md` |
| `axios` / `@tanstack/react-query` / `zustand` / `nativewind` / `tailwindcss` | 平台无关，**原样复用** | — |

---

# 四、已知风险 / 待办

| 项 | 风险 | 说明 |
|----|------|------|
| 原生模块端口 | 🟡 | `pager-view / webview / reanimated / safe-area / flash-list / svg / gesture-handler` 需确认真有 RNOH 端口可用；缺失会白屏/崩。 |
| 本地去重/曝光 | 🟡 | `expo-sqlite` 委托 `@react-native-ohos/sqlite-storage`，未安装则降级内存。 |
| 图片存相册 | 🟡 | `expo-media-library` 垫片返回未授权 → 上层走系统分享。 |
| Sentry | ⚪ | 首版省略，不影响功能。 |
| 内页自设标题 | 🟡 | 部分页面用 `Stack.Screen` 声明标题已被 no-op；运行时 `navigation.setOptions` 仍生效，少数纯声明式标题需后续补到 `optionsFor`。 |

---

# 五、本次会话的改动清单

- ✅ `ohos/App.tsx`：重建导航树（`(tabs)`→HomeScreen，去掉双底栏）、外置头部配置、承载全局根逻辑。
- ✅ `ohos/routeRegistry.ts`：`(tabs)`/`(tabs)/index` → HomeTab，补充 `index`/`not-found` 路由。
- ✅ `platform/ohos/shims/expoRouterEntry.tsx` + `metro.config.js`：`expo-router/entry` 别名兜底。
- ✅ `scripts/install-ohos.sh` / `scripts/build-ohos.sh`：安装 + 构建编排。
- ✅ `OHOS_REPO_STRUCTURES.md`（仓库结构多方案）、`OHOS_ARCHITECTURE.md`（本文件）、`OHOS_BUILD.md`（构建指南）。
- ⚠️ 上述为静态代码与配置层面的实现；**真机/模拟器编译验证需 DevEco + JDK17 + OHOS SDK**（当前开发机缺 JDK，未做编译验证）。
