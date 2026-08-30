# 鸿蒙（HarmonyOS）转换 · 仓库结构设计

> 目标：把 `luckylew23/zhihu--`（基于 React Native + Expo 的第三方知乎客户端）
> 转换成能在 **HarmonyOS NEXT**（纯 ArkTS 运行时，无安卓兼容层）运行的版本，
> **且不影响原作者仓库代码**。
>
> 本文给出 **4 种仓库结构方案**，并给出推荐。配套文档：
> - 架构分析 → [`OHOS_ARCHITECTURE.md`](./OHOS_ARCHITECTURE.md)
> - 总体迁移方案 → [`OHOS_MIGRATION.md`](./OHOS_MIGRATION.md)
> - 模块级映射表 → [`EXPO_OHOS_MAPPING.md`](./EXPO_OHOS_MAPPING.md)
> - 构建指南 → [`OHOS_BUILD.md`](./OHOS_BUILD.md)

---

## 共同约束（所有方案都遵守）

- **源项目代码零改动**：`app/ components/ store/ api/ utils/ constants/ hooks/` 等
  上游文件逐字节保留，只在新增文件里做适配。
- **与原作者解耦**：`upstream` 指向 `luckylew23/zhihu--` 且 `push` 被禁用；
  所有改动推送到你自己的 fork（`origin`）。
- **适配核心手段一致**：靠 `metro.config.js` 在 `HMOS_BUILD=1` 时的
  **模块别名重定向**（`expo-*` → `platform/ohos/shims/*`），把上游对 Expo / 部分 RN
  库的 import 重定向到鸿蒙兼容垫片，从而复用 ~95% 业务代码。

---

## 方案 A — 单仓库 + `hmos` 分支 + 别名垫片层（**当前采用 · 推荐**）

```
zhihu--(你的 fork)
├── main                 # 上游镜像分支（仅 git merge/rebase upstream/main，不改动）
└── hmos                # 转换工作分支（当前所在）
    ├── app/ components/ store/ api/ utils/ ...   # ← 上游源码，OHOS 下【不改】
    ├── platform/ohos/shims/*                       # ★ 鸿蒙兼容垫片（Metro 别名目标）
    ├── ohos/        (index.tsx, App.tsx, routeRegistry.ts)  # ★ OHOS JS 入口/导航
    ├── harmony/     (DevEco 工程: entry/ AppScope/ hvigor ...)  # ★ 原生宿主
    ├── scripts/     (setup-remotes / sync-upstream / install-ohos / build-ohos)
    ├── package.ohos.json          # OHOS 专用依赖清单（解耦原 package.json）
    ├── metro.config.js            # ★ 唯一受控改动：HMOS_BUILD=1 启用别名层
    └── *.md (本批设计/构建文档)
```

- **与上游同步**：`./scripts/sync-upstream.sh` → `git fetch upstream && git rebase upstream/main`。
  冲突面收敛到受控文件，业务代码几乎零冲突。
- ✅ 优点：代码复用率最高；同步最省力；无需 monorepo 工具链；当前已落地可用。
- ❌ 缺点：转换代码与原 Expo 代码同居一仓，分支一多略显拥挤；生态新增平台（如 macOS）
  时隔离性偏弱。
- 📌 适用：个人 / 小团队，追求“持续追随上游”的快速移植。

---

## 方案 B — Monorepo 工作区（packages 拆分）

```
zhihu-monorepo/
├── packages/
│   ├── zhihu-core/        # 共享的 Expo/RN 源码（app/ components/ store/ ...）
│   │                      # 以 git subtree 从 upstream/main 同步，自身不写适配
│   ├── zhihu-ohos/        # ★ harmony/ 原生 + ohos/ 入口 + platform/ohos/shims
│   │                      # 通过 workspace 别名把 core 里的 expo-* import 指到本包 shims
│   └── zhihu-web/         # （可选）若将来想复用同一份 core 出 Web 版
├── package.json           # workspaces 配置
└── pnpm-workspace.yaml
```

- **别名机制**：在 `zhihu-ohos` 内用 `metro.config.js` 别名（同方案 A），
  或在 `zhihu-core` 的 `tsconfig`/`babel` 里用 `module-resolver` 把 `@expo/*` 指向 ohos 包的垫片。
- ✅ 优点：平台隔离清晰，职责边界明确；多平台团队可并行；core 与平台解耦最彻底。
- ❌ 缺点：monorepo 工具链（pnpm/nx/turbo）有学习与维护成本；subtree 同步需额外脚本；
  别名跨包配置更繁琐。
- 📌 适用：需要长期维护多端（OHOS/iOS/Web/桌面）或有多人分平台协作。

---

## 方案 C — 独立仓库 + git subtree

```
zhihu--ohos (独立仓库，可独立发布)
├── <核心源码 app/ components/ store/ ...>   # 由 git subtree 从上游拉入，只读镜像
├── platform/ohos/shims/*
├── ohos/  harmony/  scripts/  package.ohos.json
```

- **同步**：`git subtree pull --prefix=<core> upstream main`，把上游目录作为子树并入；
  适配改动放在 `platform/ohos` 等非核心目录，冲突时手解。
- ✅ 优点：OHOS 仓库完全独立、可单独开源/发布；不依赖 fork 分支管理。
- ❌ 缺点：subtree 合并历史重、冲突处理比 rebase 麻烦；核心源码与上游“同目录但不同 git”，
  容易忘记同步导致漂移。
- 📌 适用：想把鸿蒙版作为独立项目长期运营，与原 Expo 项目分家。

---

## 方案 D — 独立仓库 + 快照 vendoring（rsync 快照）

```
zhihu--ohos (独立仓库)
├── vendor/zhihu-core/   # 上游某次快照（定期 rsync 导出，配 .guard 白名单）
├── platform/ohos/shims/*
├── ohos/  harmony/  scripts/  package.ohos.json
```

- **同步**：脚本定期把上游 `app/ components/ ...` 导出到 `vendor/`，再用白名单文件
  决定哪些文件允许覆盖、哪些保留本地修改，避免误删适配。
- ✅ 优点：完全隔离，上游的任何破坏性变更都不会自动污染本仓库；对“只想要一份能跑的鸿蒙版”最稳。
- ❌ 缺点：漂移最严重，需手动 merge；vendor 目录冗余。
- 📌 适用：一次性发布、不打算长期追随上游的“冻结版”。

---

## 对比总表

| 维度 | A 单仓分支 | B Monorepo | C subtree | D 快照 |
|------|-----------|-----------|-----------|--------|
| 代码复用率 | ★★★★★ | ★★★★★ | ★★★★ | ★★★ |
| 上游同步成本 | 最低 | 中 | 中高 | 高（手动） |
| 平台隔离度 | 中 | 最高 | 高 | 高 |
| 工具链复杂度 | 无 | 高 | 中 | 低 |
| 可独立发布 | 需 fork | 易 | 易 | 易 |
| 影响源项目代码 | 否 | 否 | 否 | 否 |
| 当前落地状态 | ✅ 已落地 | — | — | — |

## 推荐

- **首选方案 A**：改动最小、同步最省、已在本仓库 `hmos` 分支落地，适合“持续追随上游”的移植目标。
- 若后续要维护 **OHOS + iOS + Web 多端** 或有多人分平台协作，再平滑演进到 **方案 B**（把
  `app/` 等抽成 `packages/zhihu-core`，`platform/ohos` 与 `harmony/` 抽成 `packages/zhihu-ohos`），
  别名层机制完全可复用，迁移成本低。
- 方案 C / D 仅在“鸿蒙版要彻底分家 / 冻结发布”时考虑。
