# zhihu--HMOS

[zhihu--](https://github.com/luckylew23/zhihu--)（基于 React Native + Expo 的第三方知乎客户端）的 **HarmonyOS NEXT** 移植版：通过 [React Native OpenHarmony (RNOH)](https://github.com/react-native-ohos/react-native-openharmony) 在纯 ArkTS 运行时（无安卓兼容层）运行。

与上游 Expo 版相互独立，版本号和发布节奏自主管理，不影响原作者的主版本发布。

## 架构

zhihu-- 是 React Native (Expo) 应用，无法直接编译到 OpenHarmony。本工程通过以下三层实现移植：

- **ArkTS 壳工程（本仓库 `harmony/`）**：DevEco 工程，RNOH 通过 `EntryAbility` 拉起 `RNOHApp({ appKey: "zhihu--" })`，从 `rawfile` 加载 JS bundle
- **RNOH JS 入口（`ohos/`）**：`index.tsx` 用 `AppRegistry.registerComponent('zhihu--', ...)` 注册根组件，`routeRegistry.ts` 承担原 Expo Router 的路由表
- **兼容垫片层（`platform/ohos/shims/`）**：`metro.config.js` 在 `HMOS_BUILD=1` 时把 `expo-*` / 部分 RN 库的 import 重定向到鸿蒙兼容实现，从而复用 ~95% 业务代码

少数能力（`expo-media-library` 存相册、`expo-sqlite` 等）按文档降级处理，调用时走系统分享或内存兜底。

## 仓库组织

鸿蒙版由两个仓库协同，均不影响原作者的主版本发布：

| 仓库 | 分支 | 职责 |
|---|---|---|
| 原作者 zhihu--（上游） | main | 官方多平台发布，功能贡献（PR）合入这里 |
| luckylew23/zhihu--（fork） | main | 纯净镜像，只放能合回上游的改动，随时与上游同步 |
| luckylew23/zhihu--（fork） | hmos | 前端侧鸿蒙改动（`metro.config.js` 别名层、`babel.config.js`、`app.json`、`tsconfig.json`、源码头构建），不合 main、不发 PR |
| **luckylew23/zhihu--HMOS（本仓库）** | main | ArkTS 壳工程(RNOH) + 垫片 + 构建脚本 + 独立 Release，自有版本号 |

前端产物流向：fork 的 `hmos` 分支在 `HMOS_BUILD=1` 下经 `metro.config.js` 别名层打包（`scripts/build-ohos-bundle.js`，入口 `ohos/index.tsx`）→ 产物写入本仓库 `harmony/entry/src/main/resources/rawfile/` → `hvigorw assembleHap` 打 HAP → 独立发布。

> 设计取舍详见本仓库根目录的 `OHOS_*.md` 系列文档（`OHOS_REPO_STRUCTURES.md` 对比了单仓分支 / Monorepo / subtree / 快照四种方案，当前采用与上游解耦的 fork + 独立 HMOS 仓库模式）。

## 本仓库包含什么

- `harmony/` — DevEco ArkTS 壳工程（RNOH 宿主、签名脚本与公开证书链）
- `ohos/` — RNOH JS 入口与路由表（`index.tsx` / `App.tsx` / `routeRegistry.ts`）
- `platform/ohos/` — 鸿蒙兼容垫片层（`shims/` 与 `stubs/`）
- `scripts/` — 安装 / 构建 bundle / 构建 HAP / 同步上游 / 回归自检
- `metro.config.js`、`package.ohos.json`、`babel.config.js`、`app.json`、`tsconfig.json` — 鸿蒙构建受控配置
- `OHOS_*.md`、`EXPO_OHOS_MAPPING.md` — 架构 / 迁移 / 构建 / 仓库结构 / 模块映射文档

**前端业务源码（`app/` `components/` `store/` `api/` `utils/` `constants/` `hooks/` `assets/` `features/` `storage/` `types/` `patches/`）不存放于本仓库**，由 fork 的 `hmos` 分支构建而来。

## 环境要求

- Node.js 18+
- DevEco Studio（含 HarmonyOS SDK，API 12 / OHOS 5.0.0(12)）
- JDK 17（OHOS 构建强制要求）
- ohpm（DevEco 自带）

## 构建与签名

```bash
# 1. 安装依赖（用 package.ohos.json 临时覆盖 package.json，装完恢复）
./scripts/install-ohos.sh

# 2. 构建 JS bundle 并写入 harmony/entry/.../rawfile/
./scripts/build-ohos-bundle.js

# 3. 构建 HAP
cd harmony && ./hvigorw assembleHap

# 4. 签名（需要 signing/ 下有本地私钥，见下方说明）
./harmony/sign-hap.sh        # 或 harmony/signing/sign.sh
```

产物：`harmony/entry/build/default/outputs/default/entry-default-signed.hap`

## 签名说明

出于安全考虑，**仓库不包含签名私钥**（`*.p12` / `*.p7b` 已被 `.gitignore` 排除），仅保留证书链、`sign.sh` 和 `make-profile.py`（可用于重新生成自签调试证书）。

- 侧载安装：自签调试证书即可，设备需开启开发者模式
- 上架 AppGallery：需要华为开发者账号申请正式证书与 Profile

## 版本发布

- 版本号位于 `harmony/AppScope/app.json5`（`versionName` / `versionCode`），独立于上游 zhihu-- 的版本序列
- HAP 安装包发布到本仓库的 GitHub Release

## 同步上游

```bash
./scripts/sync-upstream.sh            # rebase upstream/main 到当前分支
./scripts/sync-upstream.sh --merge    # 改用 merge
```
