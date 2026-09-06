# zhihu--HMOS

> HarmonyOS NEXT 版知乎第三方客户端（[zhihu--](https://github.com/luckylew23/zhihu--)）的鸿蒙壳工程。
>
> **当前路线：ArkWeb WebView 壳**（与 [Tydora-HMOS](../Tydora-HMOS) 同一条已验证路线）。
> 早期尝试的 RNOH 原生移植路线已废弃，原因见下方「为什么不是 RNOH」。

## 架构

zhihu-- 是 React Native (Expo) 应用，无法直接编译到 OpenHarmony。本工程分三步把它带到鸿蒙：

```
zhihu-- (Expo / react-native-web)
   │  expo export --platform web          ← scripts/build-web.sh
   ▼
dist-web/ （多文件静态站点）
   │  scripts/inline-single-file.mjs      ← JS/CSS/字体/图片全部内联，module→IIFE
   ▼
harmony/entry/src/main/resources/rawfile/index.html   ← 单文件，自包含
   │  ArkWeb: Web({ src: $rawfile('index.html') })
   ▼
hvigorw assembleHap（纯 ArkTS 编译 + 资源打包，秒级）
   │  harmony/signing/sign.sh             ← 本地自签
   ▼
zhihu---default-signed.hap
```

- **ArkTS 壳（`harmony/`）**：`EntryAbility` 拉起 `pages/index`，页面只有一个 `Web` 组件
- **单文件内联**：`$rawfile` 的文档源是 `resource://rawfile/...`，该 scheme 下 ES module 子资源
  （`<script type="module">` / `<link rel="modulepreload">`）会被 CORS 拒绝，分包资源也会跨 scheme 取不到。
  所以构建脚本把所有 JS / CSS / 字体 / 图片内联进一个 `index.html`，并把 module 脚本降级为普通 IIFE 脚本，
  完成后做自检（零本地子资源引用、零 `type="module"`），不通过直接失败。

### 为什么不是 RNOH

RNOH（React Native OpenHarmony）方案在本项目上有两个硬伤：

1. **构建耗时**：RNOH 的 har 内含 boost / folly / glog / libevent / fast_float 的全量 C++ 源码，
   且 `libs/` 为空（没有预编译 `.so`），`assembleHap` 会触发一次完整的 CMake 原生构建（数十分钟级）。
2. **版本错配**：zhihu-- 的 JS 侧是 `react-native@0.83.2`，而 ohpm 上可获取的 RNOH 为 `0.84.3`
   （无 0.83.x），`@react-native-oh/react-native-harmony@0.84.3` 的 peer 是精确的 `react-native@0.84.1`。

此外 RNOH 0.82+ 的 har 已不再随包发布 hvigor 构建插件（只有 ArkTS 运行时导出），
旧写法 `import { appTasks } from '@rnoh/react-native-openharmony'` 必然 MODULE_NOT_FOUND。

RNOH 相关的历史资料仍保留在 `OHOS_*.md` 与 `platform/ohos/`，但已不参与构建。

## 环境要求

- Node.js ≥ 20.19（Metro 要求；脚本默认用 WorkBuddy 托管的 22.22.2）
- DevEco Studio（含 OpenHarmony SDK，API 20 / `6.0.0(20)`）
- DevEco 自带 JDK（jbr）

## 构建

```bash
# 一键：Web 导出 → 单文件内联 → assembleHap → 本地自签
bash scripts/build-ohos.sh            # 默认 release；传 debug 出 debug 包

# 分步
bash scripts/build-web.sh             # 只做 Web 产物 + rawfile
SKIP_WEB=1 bash scripts/build-ohos.sh # 复用已有 rawfile，只重打 hap
bash scripts/build-hap.sh release     # 只打包 + 签名
```

产物：

- 未签名 `harmony/entry/build/default/outputs/default/entry-default-unsigned.hap`
- 已签名 `harmony/entry/build/default/outputs/default/zhihu--default-signed.hap`

环境变量：

| 变量 | 默认 | 说明 |
|---|---|---|
| `ZHIHU_SRC` | `../zhihu--` | 上游 Expo 工程目录（要能跑 `expo export --platform web`） |
| `NODE_BIN` | WorkBuddy 托管 22.22.2 | node 所在目录 |
| `DEVECO_HOME` | `/Applications/DevEco-Studio.app/Contents` | DevEco 安装位置 |

## 安装

```bash
hdc install harmony/entry/build/default/outputs/default/zhihu--default-signed.hap
```

自签调试包需要设备开启开发者模式。

## 已知限制

- **CORS**：文档源是 `resource://rawfile`，页面内的跨域 XHR/fetch 会带该 Origin。
  上游直连知乎接口的部分请求可能被 CORS 拒绝，需要走请求代理或改用原生桥转发。
- **原生能力**：纯 Web 壳拿不到 `expo-secure-store` / `expo-sqlite` / `expo-haptics` 等原生模块，
  需要时通过 `javaScriptProxy` 挂 ArkTS 桥（参考 Tydora-HMOS 的 `bridge/TauriBridge.ets`）。
- 单文件 HTML 体积较大（含内联的 katex 字体等），首次加载略慢。

## 签名说明

`harmony/signing/sign.sh` 完全离线自签，不需要华为开发者帐号：

```
Root CA → 二级 CA(App/Profile) → App 证书 → Profile 证书 → p7b → sign-app → verify-app
```

出于安全考虑，**仓库不包含签名私钥**（`*.p12` / `*.p7b` 已被 `.gitignore` 排除），
仅保留证书链、`sign.sh` 和 `make-profile.py`。首次运行会自动生成整套物料（口令 `123456`）。

上架 AppGallery 需要换成华为开发者账号申请的正式证书与 Profile。

## 仓库组织

| 仓库 / 分支 | 职责 |
|---|---|
| 上游 zhihu-- `main` | 官方多平台发布 |
| luckylew23/zhihu-- `main` | 纯净镜像，只放能合回上游的改动 |
| luckylew23/zhihu-- `hmos` | 前端侧鸿蒙改动，不合 main、不发 PR |
| **本仓库 `main`** | ArkTS 壳工程 + 构建脚本 + 独立 Release，自有版本号 |

版本号位于 `harmony/AppScope/app.json5`（`versionName` / `versionCode`）。
