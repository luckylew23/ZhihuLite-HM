# ZhihuLite-HM（知乎Lite）

> **轻量级知乎第三方客户端 · HarmonyOS NEXT 原生版**
>
> 上游 [zhihu--](https://github.com/luckylew23/zhihu--)（v0.6.0，React Native / Expo）的完整原生移植：
> 复用上游纯 TypeScript 业务逻辑，UI 用 ArkTS 原生重写，界面与 Android 版一致。

[![版本](https://img.shields.io/badge/版本-v0.3.10-blue)](#版本历史) [![平台](https://img.shields.io/badge/平台-HarmonyOS%20NEXT-black)](#) [![架构](https://img.shields.io/badge/架构-原生ArkTS-green)](#架构概览)

---

## 简介

知乎Lite 是知乎的第三方鸿蒙客户端，主打**轻量、快速、功能完整**：

- **完整功能**：关注 / 推荐 / 热榜 / 日报 / 搜索 / 收藏 / 互动 / 创作（写回答、写文章、发想法、提问）
- **原生体验**：纯 ArkTS 重写，无 WebView 壳，点击响应快
- **界面一致**：对照 Android 版原样复制的深色主题与交互
- **独立身份**：应用名"知乎Lite"、独立包名 `com.zhihulite.hmos`，与原版互不冲突，可共存安装

## 特性速览

- **离线缓存**：热榜 / 日报进入即缓存，两天内断网也能看

| 模块 | 能力 |
|---|---|
| 首页栏目 | 关注 / 推荐 / 热榜 / 日报，可配置展示，默认推荐 |
| 内容详情 | 问题、回答、文章、想法、视频、专栏、话题（原生详情页） |
| 互动创作 | 点赞 / 收藏 / 关注 / 评论 / 写回答 / 写文章 / 发想法 / 提问 |
| 搜索 | 综合 / 用户双 tab，登录后使用 |
| 个人中心 | 我的收藏（内容+分类）、历史、通知、私信、赞同、他人主页 |
| 设置 | 主题（自动/浅色/深色）、栏目、默认首页、内容过滤 |
| 可发现性 | 包内搜索关键词（知乎/zhihu/lite/轻量/知乎第三方/知乎鸿蒙版等） |

## 快速开始

### 环境要求

- macOS + DevEco Studio（含 OpenHarmony SDK 6.0.2 / API 20）
- 真机需开启开发者模式；命令行构建无需 IDE GUI

### 构建

```bash
cd ~/workbuddy/zhihu--HMOS/harmony-native
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  assembleHap --mode module -p product=default --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-signed.hap`（华为签名，真机可装）。

### 安装

```bash
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC list targets                                   # 确认设备在线
$HDC -t <serial> install -r ZhihuLite-HM-v0.3.10-signed.hap
```

已交付 HAP 均保留在 `~/workbuddy/zhihu--HMOS/`，命名 `ZhihuLite-HM-v<版本>-signed.hap`。

## 架构概览

```
用户 ──▶ ZhihuLite-HM（ArkTS 原生 UI，36 页面）
              │
              ├── api/  27 个知乎 API 模块
              │     └── httpClient（Cookie Jar + x-zse-96 签名 + 401 自动刷新 + 请求日志）
              │     └── zse96/（签名算法，与上游逐行对齐）
              ├── store/  authStore / settingsStore（preferences 持久化）
              └── 知乎服务端（www / api / zhuanlan / oauth 四域名）
```

详细 C4 架构（系统上下文 / 容器 / 组件 / 代码）见 [projectdesign.md](projectdesign.md)。

## 项目结构

```
zhihu--HMOS/
├── harmony-native/        ★ 原生工程（当前主线）
│   ├── entry/src/main/ets/{pages,components,api,store,model,utils}
│   ├── PORTING_SPEC.md    移植规范（所有移植工作的事实来源）
│   ├── AUDIT_REPORT.md    缺陷审计报告（H/M/L 分级 + 降级项）
│   └── projectdesign.md   特性/C4/设计/测试/要求
├── harmony/               旧 WebView 壳（已否决，归档保留）
├── scripts/               构建 / 签名 / SDK 补丁脚本
├── HarmonyOS 版可行性分析.md
└── ZhihuLite-HM-v*.hap    各版本交付产物
```

## 文档索引

| 文档 | 内容 |
|---|---|
| [projectdesign.md](projectdesign.md) | 特性、C4 架构、设计、测试验证、要求（唯一事实来源） |
| [AUDIT_REPORT.md](harmony-native/AUDIT_REPORT.md) | 缺陷清单（H1-H4/M1-M10/L 系列）+ 已知降级项 |
| [PORTING_SPEC.md](harmony-native/PORTING_SPEC.md) | 移植规范、ArkTS 硬坑、页面约定 |
| [scripts/sdk-build-patch.md](scripts/sdk-build-patch.md) | 命令行构建打通与 SDK 补丁方案 |
| `~/vault/Notebook/Duobao/zhihu--HarmonyOS原生移植记录-v0.2.md` | 逐版本移植/修复/验证记录与经验 |

## 版本历史

| 版本 | 里程碑 |
|---|---|
| v0.1 | 自签包 1.1M，首版可跑（仅浏览） |
| v0.2 | 华为签名 2.5M，命令行构建打通，交互初修 |
| v0.3 | copyOption 全局减负 421→6，点击响应大幅提升 |
| v0.3.1 | 收藏夹修复（不再回落 me 路径）+ 错误详情可见 |
| v0.3.2 | 全局字号 +1 |
| v0.3.3 | 底栏字符化（⌂ / + / 👤） |
| v0.3.4 | 应用名"知乎Lite"+ 新图标（蓝底白知字 LITE） |
| v0.3.5 | 搜索登录提示（search_v3 强制登录） |
| v0.3.6 | 合集版：全量审计项修复 + 真机全面验证通过 |
| v0.3.7 | 全量 HTTP 日志，定位搜索解析崩溃 |
| v0.3.8 | 搜索修复：结果解析 null 全防护 + 搜索关键词配置 |
| v0.3.9 | 全回归修复：收藏夹解析防护 + pin.content 类型防护 + HTML 实体解码 + 热榜/日报两天离线缓存（进入即缓存、离线可看）+ DFX 设计（不闪退/深浅主题/点击≤3s）|
| v0.3.10 | 最近浏览闪退修复（extra/header/content/matrix 空引用全防护 + 逐条解析）+ 默认加载最近两天浏览记录 + 底栏发布按钮去圆圈改纯 + 号 |

## 已知限制

- 富文本/LaTeX 正文为纯文本渲染（剥 HTML 标签）
- 私信为 HTTP 轮询降级（无 WebSocket）
- 发布图片上传 OSS 未实现
- 日报正文纯文本、设置部分静态
- 应用市场搜索关键词主配置需在 AGC 发布后台补充

## 致谢

- [zhihu--](https://github.com/luckylew23/zhihu--)：上游 React Native 知乎客户端（MIT）
