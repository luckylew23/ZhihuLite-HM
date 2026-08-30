# HarmonyOS NEXT 适配总体方案 — Zhihu--

> 目标：把原作者的 React Native (Expo) 项目 **zhihu--** 转成可在 **HarmonyOS NEXT**
> （纯 ArkTS 运行时，API 12 / OHOS 5.0.0）运行的版本，同时做到 **不影响原作者仓库**、
> 且能持续从上游同步更新。
>
> 📌 **路线说明**：HarmonyOS NEXT 是纯 ArkTS 运行时，**不再兼容安卓 APK**。把 RN 应用搬上
> NEXT 的唯一可行路线是 **React Native OpenHarmony（RNOH）** 端口——用 RNOH 的 ArkTS 宿主工程
> 承载 RN 的 JS 运行时，产物为 HAP/APP（非 APK）。本方案即采用此路线。

---

## 1. 转换路线

采用 **React Native OpenHarmony（RNOH）端口** 方案（HarmonyOS NEXT 唯一可行的 RN 路线）：

- 保留 ~95% 的 TS/JS 业务代码（`api/`、`store/`、`components/`、`utils/`、`app/`），
  仅替换「原生层 + Expo 专属模块」为 HarmonyOS 兼容实现。
- 不采用全量 ArkTS 重写（成本极高且与上游无法共享代码）。
- **不产出安卓 APK**：NEXT 是纯 ArkTS 运行时，构建目标 `runtimeOS: "HarmonyOS"`，
  产物为 HAP/APP，由 RNOH 的 ArkTS 宿主工程承载 RN JS 运行时。

技术核心：**Metro `resolver.resolveRequest` 别名层** —— 在 OHOS 构建时（`HMOS_BUILD=1`），
把业务代码里对 `expo-*` / 部分 RN 第三方库的 import 重定向到 `platform/ohos/shims/*` 下的鸿蒙垫片，
同时解析 tsconfig 的 `@/*` 路径别名。因此 `app/`、`components/` 等源码 **逐字节不变**，
与上游 rebase 时几乎零冲突。

> 为何不用 `resolver.extraNodeModules`：它只能按「包名」整体替换，无法处理
> `expo-file-system/legacy`、`expo-router/entry` 这类**带子路径**的模块名；
> `resolveRequest` 接收完整请求名，可精确匹配子路径与自定义前缀。

---

## 2. 仓库结构与分支模型（同步机制）

```
                        upstream = luckylew23/zhihu--   (原作者，只读，禁止推送)
                                    │  fork
                                    ▼
                        origin  = <你的 fork>            (转换成果推送目的地)
                                    │
        ┌───────────────────────────┴───────────────────────────┐
        ▼                                                        ▼
   main 分支（上游镜像）                                    hmos 分支（转换工作）
   - 仅 `git merge upstream/main` 或跟踪                      - 在 upstream/main 基础上
   - 不在此做改动                                            - 叠加 OHOS 适配（新增文件为主）
                                                              - 定期 `sync-upstream.sh` rebase
```

### 关键约定
1. **`upstream` 指向原作者**，且已执行 `git remote set-url --push upstream no-push`，任何推送都会被拒绝。
   原作者的 `main` 永远不被我们改动。
2. **`main` 分支只做上游镜像**（可选；也可以直接在 `hmos` 上 rebase）。
3. **所有转换改动都在 `hmos` 分支**，且以「新增文件」为主（`platform/`、`ohos/`、`harmony/`、`scripts/`、
   `*.ohos.json`、文档）。对上游已有文件的修改被刻意压到最少（仅 `metro.config.js` 一个受控文件）。
4. **同步命令**：`./scripts/sync-upstream.sh`
   - `git fetch upstream` → `git rebase upstream/main`（冲突面极小）。
   - 若当前有未提交改动，自动 `stash`；冲突时提示手动解决。
   - 支持 `--merge` 用 merge 代替 rebase。

### 为什么要这样设计
- 原项目是 Expo Router 文件路由 + 大量 `expo-*` 模块。若直接改 `app/` 里的 import，
  每次上游更新这些文件都会产生冲突。别名层把「平台差异」收敛到 `platform/ohos/shims/`，
  业务代码保持与上游同构，rebase 几乎无痛。

---

## 3. 目录结构（本仓库新增部分）

```
zhihu--/
├── app/  components/  store/  api/  utils/  constants/   # ← 上游源码，OHOS 下【不改】
│
├── platform/                     # ★ 平台抽象层（转换核心）
│   ├── index.ts                 # isOHOS 运行时判断
│   └── ohos/shims/              # ★ 鸿蒙兼容垫片（Metro 别名目标）
│       ├── expoSecureStore.ts   # expo-secure-store
│       ├── expoCrypto.ts        # expo-crypto（纯 JS MD5/SHA256，见 cryptoImpl.ts）
│       ├── expoClipboard.ts     # expo-clipboard
│       ├── expoFileSystem.ts    # expo-file-system
│       ├── expoFileSystemLegacy.ts
│       ├── expoLinking.ts  expoWebBrowser.ts  expoSharing.ts
│       ├── expoIntentLauncher.ts  expoHaptics.ts  expoMediaLibrary.ts
│       ├── expoBlur.tsx  expoLinearGradient.tsx  expoStatusBar.tsx
│       ├── expoScreenOrientation.ts  expoSplashScreen.ts  expoConstants.ts
│       ├── expoSqlite.ts        # 委托 @react-native-ohos/sqlite-storage
│       ├── reactNativeCookies.ts# @react-native-cookies/cookies
│       ├── reactNativeRootSiblings.tsx
│       ├── expoRouter.tsx       # ★ expo-router 兼容层（基于 React Navigation）
│       ├── expoRouterHtml.tsx
│       └── _kv.ts               # 共享 KV 存储底座
│
├── ohos/                        # ★ OHOS 专属 JS 入口
│   ├── index.tsx                # AppRegistry.registerComponent('zhihu--', ...)
│   ├── App.tsx                  # NavigationContainer + Stack + Tab 容器
│   └── routeRegistry.ts        # URL ↔ 路由名 映射表（仿 expo-router 路径）
│
├── harmony/                     # ★ DevEco 原生工程（RN OHOS 宿主）
│   ├── AppScope/  entry/  oh-package.json5  build-profile.json5  hvigorfile.ts ...
│
├── scripts/
│   ├── setup-remotes.sh         # 配置 origin(fork) + upstream(只读)
│   └── sync-upstream.sh         # 将 upstream/main rebase 到当前分支
│
├── package.ohos.json            # OHOS 专用依赖清单（与原 package.json 解耦）
├── metro.config.js              # ★ 唯一的受控改动：HMOS_BUILD=1 时启用别名层
├── EXPO_OHOS_MAPPING.md        # 模块级映射表
└── OHOS_MIGRATION.md           # 本文件
```

---

## 4. 构建流程（本机需 DevEco Studio + 鸿蒙 SDK + JDK17）

> ⚠️ 当前开发机缺 JDK，未做真机编译验证；以下步骤为标准 RN OHOS 流程。

### 4.1 安装 OHOS 依赖
```bash
# 基于 package.ohos.json 安装（react-native 已被 @react-native-ohos/react-native 替代）
npm install --no-save -f package.ohos.json   # 或按文档手动合并依赖
cd harmony && ohpm install
```

### 4.2 生成 Metro Bundle（✅ 已在本机跑通）

```bash
node scripts/build-ohos-bundle.js          # 生产包（minify, dev=false）
node scripts/build-ohos-bundle.js --dev    # 调试包
```

产物（**已实测生成成功**）：

| 文件 | 说明 |
|------|------|
| `harmony/entry/src/main/resources/rawfile/bundle.harmony.js` | JS bundle，**3.76 MB / 2006 个模块** |
| `harmony/entry/src/main/resources/rawfile/bundle.harmony.map` | sourcemap |
| `harmony/entry/src/main/resources/rawfile/assets/…` | **30 个**资源（react-navigation 图标 + vector-icons 字体） |

> 该目录已被 `.gitignore` 忽略（构建产物），构建 HAP 前请先执行上面的脚本。

#### 为什么产物路径是 `rawfile/bundle.harmony.js`
RNOH 的 `ResourceJSBundleProvider` 默认 `path = 'bundle.harmony.js'` 并从 **rawfile** 读取
（见 `harmony/oh_modules/@rnoh/react-native-openharmony/src/main/ets/RNOH/JSBundleProvider.ts:134`）。
若改文件名，需同步修改 `EntryAbility`。

#### 关于资源(assets)
Metro 0.83 的 `build` 命令**不再输出资源**（已移除 `--assets-dest`，`--legacy-bundler` 同样不输出），
因此脚本自行解析 bundle 内的 `registerAsset` 记录并拷贝资源。
路径对齐 RNOH：`RAWFILE_PREFIX = "resource://RAWFILE/assets/"`，
Metro 的 `httpServerLocation = "/assets/" + dirname(相对路径)`，
故 `destination = rawfile + httpServerLocation` 正好落在 `rawfile/assets/<相对路径>`。

### 4.3 构建 HAP 并运行
```bash
cd harmony && hvigorw assembleHap --mode module -p product=default
```
- 或用 DevEco Studio 打开 `harmony/` 工程 → 签名 → 运行到鸿蒙设备。
- `EntryAbility` 通过 `RNOHApp({ appKey: "zhihu--" })` 拉起 `ohos/index.tsx`。

> ⚠️ HAP 编译与真机运行尚未在本机验证（需 JDK + 鸿蒙 SDK + 签名）。
> 已验证到「JS bundle 与资源产物正确生成」为止。

---

## 5. 已知缺口 / 后续工作

| 项目 | 状态 | 说明 |
|------|------|------|
| 路由表完整性 | 🟢 完成 | `ohos/routeRegistry.ts` 已覆盖 `app/` 下全部可导航路由（含 `comments/replies/[id]`、`question/[id]/answer/[answerId]`、`question/write/[id]`、`modal`） |
| 底部 Tab | 🟢 可用 | `(tabs)` 直接挂载 `app/(tabs)/index`：其内部的 PagerView + 自定义底部栏已自管 Tab，因此**不再**包一层 BottomTabNavigator（否则会出现两套 Tab 栏） |
| 图片保存到相册 | 🟡 降级 | `expo-media-library` 垫片返回未授权 → 自动走「系统分享」 |
| 本地去重/曝光 | 🟡 依赖 | `expo-sqlite` 垫片委托 `@react-native-ohos/sqlite-storage`；该包未发布，缺失时明确报错，仅影响非核心功能 |
| 登录 Cookie 注入 | 🟢 可用 | `reactNativeCookies` 垫片（KV Cookie Jar）+ 沿用现有 zse96 签名逻辑 |
| 毛玻璃/渐变 | 🟢 可用 | `BlurView` 降级半透明；`LinearGradient` 用 SVG 实现 |
| MD5 / SHA-256 | 🟢 已验证 | `cryptoImpl.ts` 纯 JS 实现；对照 Node `crypto`，21 组输入（含中文、emoji、55/56/57/63/64/119/120 字节等分组边界）× 2 种算法 **42/42 全部一致** |
| JS bundle 产物 | 🟢 已跑通 | `scripts/build-ohos-bundle.js` 实测生成 **3.76 MB / 2006 个模块** + **30 个资源**，输出到 `rawfile/` |
| HAP 编译 / 真机 | ⚪ 未验证 | 需 JDK17 + 鸿蒙 SDK + 签名，本机不具备；已验证到「bundle 与资源产物正确」为止 |
| 图标字体 (Ionicons) | 🟡 降级 | 走 `expo-font` → `expo-modules-core` 原生桥；OHOS 已用垫片兜底（字体文件已随资源拷贝），字形渲染需接入原生字体加载后确认 |

详细模块映射见 **EXPO_OHOS_MAPPING.md**。

---

## 6. 自检脚本

每次改动垫片或别名层后建议运行（只读，不改动任何文件）：

```bash
node scripts/verify-ohos.js
```

它做三件事（当前 **143 项检查全部通过**，覆盖 130 个源码文件）：

- **A. 垫片 API 契约审计**：逐个比对「垫片导出的符号」与「源码里实际调用的 API」，
  提前发现类似「`CookieManager.get()` 少 `name` 字段导致登录静默失败」的契约错配。
- **B. Metro 别名层校验**：别名目标文件是否真实存在、`@/*` 路径别名能否解析、
  源码里出现的每个平台模块是否都被覆盖（垫片或已声明的 npm 包）。
- **C. 关键垫片行为测试**：MD5/SHA-256 对照 Node 原生 `crypto` 逐例比对（含中文、
  emoji、55/56/57/63/64/119/120 字节等分组边界）；CookieManager 复刻
  `app/login/index.tsx` 的真实合并流程，验证 `z_c0` / `d_c0` 能被正确检出。
