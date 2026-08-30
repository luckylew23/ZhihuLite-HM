# HarmonyOS NEXT 构建指南 — Zhihu--

> 本文件说明如何把 `zhihu--` 的 React Native (Expo) 代码构建成 **HarmonyOS NEXT** App
> （产物为 HAP/APP，非安卓 APK；构建目标 `runtimeOS` 固定为 `HarmonyOS`）。
> 目录结构与转换原理见 [`OHOS_MIGRATION.md`](./OHOS_MIGRATION.md)、
> [`OHOS_ARCHITECTURE.md`](./OHOS_ARCHITECTURE.md)、
> [`OHOS_REPO_STRUCTURES.md`](./OHOS_REPO_STRUCTURES.md)。
> 模块级映射见 [`EXPO_OHOS_MAPPING.md`](./EXPO_OHOS_MAPPING.md)。

## 1. 前置环境（本机需自行准备）

| 依赖 | 版本 / 说明 |
|------|------------|
| Node.js | 18+（与 Expo/RN 同版本要求） |
| DevEco Studio | 最新版（含 HarmonyOS SDK） |
| HarmonyOS SDK | API 12（= HarmonyOS NEXT）/ OHOS 5.0.0(12) |
| JDK | 17（OHOS 构建强制要求） |
| ohpm | DevEco 自带；`ohpm -v` 可验证 |

> 元宝/WorkBuddy 当前开发机缺 JDK，本文档所述命令未做真机编译验证；
> 以下为标准 RNOH (React Native OpenHarmony) 流程。

## 2. 初始化远程仓库（仅首次）

```bash
# 配置你的 fork（origin）+ 原作者（upstream，只读，禁止推送）
./scripts/setup-remotes.sh git@github.com:<你的名>/zhihu--.git
```

## 3. 安装依赖

```bash
./scripts/install-ohos.sh
```

脚本会：用 `package.ohos.json`（OHOS 专用清单，与上游 `package.json` 解耦）临时覆盖
`package.json` 安装 JS 依赖（装完即恢复，源清单零改动），再在 `harmony/` 工程执行 `ohpm install`。

## 4. 构建 HAP

```bash
./scripts/build-ohos.sh
```

脚本会：`HMOS_BUILD=1` 触发 `metro.config.js` 别名层 → `react-native bundle`
（入口 `ohos/index.tsx`）→ 产物写入 `harmony/entry/src/main/resources/rawfile/` →
`hvigorw assembleHap`。

> 较新版本 RNOH 的 hvigor 插件会在 `assembleHap` 时自动调用 Metro 打包，
> 此时「手动 bundle」步骤可省略，直接 `cd harmony && hvigorw assembleHap` 即可。

## 5. 运行到设备 / 模拟器

- DevEco Studio 打开 `harmony/` 工程 → 签名 → 运行到鸿蒙设备 / 模拟器。
- `EntryAbility` 通过 `RNOHApp({ appKey: "zhihu--" })` 拉起 `ohos/index.tsx`
  （该文件用 `AppRegistry.registerComponent('zhihu--', ...)` 注册根组件）。

## 6. 同步上游更新

```bash
./scripts/sync-upstream.sh            # rebase upstream/main 到当前分支
./scripts/sync-upstream.sh --merge    # 改用 merge
```

冲突面刻意收敛到受控文件（`package.json` / `app.json` / `metro.config.js` /
`babel.config.js`）；业务代码 `app/ components/ store/ api/ utils/` 因走 Metro 别名层
基本无需改动，rebase 几乎无痛。

## 7. 已知缺口 / 后续工作

| 项目 | 状态 | 说明 |
|------|------|------|
| 路由表完整性 | 🟢 可用 | 所有主流程页面已在 `ohos/routeRegistry.ts` 注册 |
| 头部标题/模态/动画 | 🟢 已移植 | 原 `app/_layout.tsx` 的 `Stack.Screen` 声明已迁到 `ohos/App.tsx#optionsFor` |
| 双底栏问题 | 🟢 已修复 | `(tabs)` 直接映射 HomeScreen，不再套原生 Tab.Navigator |
| 深度链接 / 剪贴板 | 🟢 已移植 | 原根布局的 Linking/AppState 监听逻辑已迁到 `ohos/App.tsx` |
| 图片保存到相册 | 🟡 降级 | `expo-media-library` 垫片返回未授权 → 上层走系统分享 |
| 本地去重/曝光 | 🟡 依赖 | `expo-sqlite` 委托 `@react-native-ohos/sqlite-storage`（需安装，否则降级内存） |
| pager-view 横滑 | 🟡 依赖 | `react-native-pager-view` 需确认 RNOH 端口是否就绪 |
| Sentry | ⚪ 已省略 | OHOS 首版未接入 `@sentry/react-native`（原生依赖风险），待后续评估 |
| WebView 登录 | 🟢 可用 | `react-native-webview` 走 `@react-native-ohos/webview` 端口 |

## 8. 故障排查

- **bundle 找不到 `expo-*`**：确认 `HMOS_BUILD=1` 已导出，且 `metro.config.js` 别名层生效。
- **`appKey` 不匹配**：`ohos/index.tsx` 注册的 `'zhihu--'` 必须与
  `harmony/entry/src/main/ets/pages/index.ets` 中 `RNOHApp({ appKey })` 一致。
- **原生模块缺失**：检查 `harmony/oh-package.json5` 与 `harmony/entry/oh-package.json5`
  是否声明 `@rnoh/react-native-openharmony: 0.83.2`。
