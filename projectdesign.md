# ZhihuLite-HM 项目设计文档（基线版 v0.3.61）

> **项目**：ZhihuLite-HM（知乎Lite）—— 上游 [zhihu--](https://github.com/luckylew23/zhihu--) v0.6.0（React Native / Expo）的 HarmonyOS NEXT 原生移植
> **技术路线**：复用上游纯 TypeScript 业务逻辑 + ArkTS 原生重写 UI
> **本文件**：特性 / C4 架构 / 设计 / 测试验证 / 要求的唯一事实来源，随开发持续迭代更新
> **基线版本**：v0.3.61（versionCode 154）

---

## 1. 项目概述

| 项 | 值 |
|---|---|
| 应用显示名 | 知乎Lite |
| Bundle Name | `com.zhihulite.hmos`（与原版隔离，可共存安装） |
| 当前版本 | v0.3.61（versionCode 154） |
| 上游基线 | `~/workbuddy/zhihu--/`（v0.6.0） |
| 原生工程 | `~/Work/zhihuLite-HM/harmony-native/` |
| 远程仓库 | `git@github.com:luckylew23/ZhihuLite-HM.git`（main） |
| 页面数 | 37 个页面 |
| API 模块 | 27 个 |
| SDK | OpenHarmony SDK 6.0.2 / API 20 |
| 权限 | INTERNET / GET_NETWORK_INFO（无危险权限） |
| 签名 | 华为开发者签名链（真机可装） |

### 1.1 快速开始

```bash
# 构建
cd ~/Work/zhihuLite-HM/harmony-native
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  assembleHap --mode module -p product=default --no-daemon

# 产物：entry/build/default/outputs/default/entry-default-signed.hap
# 安装
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC list targets
$HDC -t <serial> install -r ZhihuLite-HM-v0.3.61-signed.hap
```

### 1.2 项目结构

```
zhihuLite-HM/
├── harmony-native/          ★ 原生工程（当前主线）
│   ├── entry/src/main/ets/
│   │   ├── pages/            37 个页面
│   │   ├── components/       detail / interaction / profile 分组组件
│   │   ├── api/              27 个 API 模块 + httpClient + zse96/
│   │   ├── store/            authStore / settingsStore
│   │   ├── model/zhihu.ts    知乎数据模型接口
│   │   └── utils/            theme / date / url / zhihuError / cacheStore / md5
│   └── ...
├── scripts/                 构建 / 签名脚本
├── HarmonyOS 版可行性分析.md
└── ZhihuLite-HM-v*.hap      各版本交付产物
```

---

## 2. 特性（Features）

### 2.1 首页与栏目
- **底栏三槽**：首页（⌂）/ 发布（+）/ 我的（👤）
- **首页内层 Tabs**：关注 / 推荐 / 热榜 / 日报，可配置展示，至少保留一栏
- **登录后状态刷新**：登录/登出翻转 `loginVersion`，主框架按 key 强制重建各列表页
- 下拉刷新 + 触底加载更多（cursor/offset 分页）

### 2.2 登录与会话
- WebView 内嵌知乎登录
- Cookie 持久化（preferences），启动恢复登录态
- `z_c0` 判定登录；401 自动刷新会话

### 2.3 内容浏览
- 推荐流 / 关注流 / 热榜 / 日报
- 问题详情、回答、文章、想法（pin）、视频、专栏、话题
- **富文本渲染**：HTML → HtmlBlock[] → 结构化渲染（标题/粗体/斜体/列表/引用/代码/图片/链接），支持 GFM
- **正文内链接**：蓝色下划线，点击在应用内打开（不跳浏览器）
- **图片**：正文大图占满、单击全屏双指缩放、长按保存原图/复制链接（右上角按钮）

### 2.4 互动与创作
- 赞成 / 反对 / 评论 / 收藏（收藏夹分类选择）/ 关注
- 写回答、写文章、发想法、提问
- **保存为 Markdown**：回答/文章/想法/日报均可保存为 .md 文件，通过系统 DocumentViewPicker 选择保存位置

### 2.5 搜索
- 综合 / 用户双 tab，强制登录
- 筛选：内容类型 / 排序 / 时间范围（默认三月内）
- 结果解析全 null 防护

### 2.6 个人中心
- 我的收藏（内容 + 分类）、历史、通知、私信、赞同
- 他人主页、赞同者列表

### 2.7 设置
- 主题（自动/浅色/深色）
- 栏目可见性配置
- 默认首页
- 内容过滤

### 2.8 可发现性
- 包内搜索关键词：知乎、zhihu、知乎Lite、轻量、知乎第三方、知乎鸿蒙版等

### 2.9 离线缓存
- **热榜/日报列表**：进入即缓存，stale-while-revalidate（先展示缓存，后台静默刷新）
- **文章详情预缓存**：列表加载后后台顺序预缓存所有条目详情（热榜=问题详情，日报=文章详情）
- **内容缓存有效期**：两天
- **断网可看**：有缓存时网络失败不显示错误页，直接展示缓存内容

---

## 3. C4 架构

### 3.1 上下文（C1）

```
用户 ──→ ZhihuLite-HM ──→ 知乎 API（www.zhihu.com / api.zhihu.com / zhuanlan.zhihu.com）
                              ↓
                        Cookie Jar + 签名头（zse96）
```

### 3.2 容器（C2）

| 层 | 职责 |
|---|---|
| UI 层（ArkTS） | 页面 + 组件，纯声明式渲染 |
| 业务层（api/） | HTTP 请求、签名、Cookie、数据解析 |
| 状态层（store/） | 登录态、设置项持久化 |
| 工具层（utils/） | 主题、日期、缓存、错误处理 |

### 3.3 组件（C3）

| 组件 | 职责 | 关键文件 |
|---|---|---|
| 主框架 | 底栏 + Tabs + 登录重建 | `pages/Index.ets` |
| 详情页族 | 问题/回答/文章/想法/视频/专栏/话题 | `*DetailPage.ets` |
| **公共操作栏** | 赞成▲/反对▼/评论○/收藏☆/保存⇩ 五项 | `components/detail/DetailActionBar.ets` |
| 富文本渲染 | HTML→Blocks→结构化渲染 | `components/detail/RichBody.ets` |
| 图片组件 | 网络图片 + 长按下载 + 全屏查看 | `components/NetImage.ets` |
| 发布页族 | 四类创作 | `Publish*Page.ets` |
| 个人中心族 | 收藏/历史/通知/私信 | `*Page.ets` |
| 搜索 | 综合/用户 + 筛选 | `SearchPage.ets` |

### 3.4 代码（C4）

```
entry/src/main/ets/
├── entryability/EntryAbility.ets
├── pages/                    37 个页面
├── components/detail/
│   ├── DetailActionBar.ets    ★ 公共五项操作栏
│   ├── AnswerCard.ets        回答卡片
│   ├── DetailNavBar.ets      导航栏
│   ├── detailUtils.ets       工具函数（blocksToMarkdown / saveMarkdownToFile / parseInline / stripHtml）
│   ├── RichBody.ets         富文本渲染
│   └── StatusView.ets       加载/错误/空态
├── api/                      27 个模块
├── store/                    authStore / settingsStore
├── model/zhihu.ts
└── utils/
    ├── theme.ts              ZhihuColors 双套色板
    ├── cacheStore.ts        ★ 缓存读写（列表 + 内容级）
    └── ...
```

---

## 4. 设计

### 4.1 UI 设计
- **主题**：`ZhihuColors` 双套色板（light/dark），auto 跟随系统，禁止硬编码
- **图标风格**：极简线条字符（△▲/▽▼/○/☆★/⇩），不用 emoji，深浅主题自适应
- **字号**：正文偏大（可读性优先），标题/正文/辅助文字分级
- **文字可选**：仅阅读场景保留 `copyOption`（正文/评论），列表/按钮全部禁用（性能）
- **品牌**：应用名"知乎Lite"、独立图标，底栏用字符 + 文字标签

### 4.2 网络设计
- 单例 HTTP client，自动处理 Cookie Jar → 签名头 → 请求 → 401 刷新 → 重试
- 签名：`zse96/hmac.ts` + `encryptZseV4`
- 设备态端点需专用头

### 4.3 数据与存储设计
- `preferences` 持久化：登录态、主题、栏目配置、默认首页、过滤项
- **文件缓存**：`cacheStore.ts`
  - 列表缓存：`hot_cache_v2` / `daily_cache_v2`
  - 内容缓存：`content_{type}_{id}`，有效期两天
  - 预缓存：列表加载后后台顺序预缓存所有条目详情
- **文件保存**：`saveMarkdownToFile()` → DocumentViewPicker → 用户选位置

### 4.4 DFX 设计

#### 4.4.1 可靠性（不闪退）
- 全量回归基线：推荐/关注/热榜/日报/详情/收藏/搜索/我的
- 解析全防护：逐条 try/catch + null 跳过
- 类型防护：`typeof` 前置判断

#### 4.4.2 主题适配
- 双套调色板，所有颜色走 `ZhihuColors`
- 深浅主题切换零页面改动

#### 4.4.3 性能（≤ 3s）
- 点击响应硬指标 ≤ 3s
- copyOption 最小化（性能杀手）
- 缓存命中秒出内容
- 列表懒加载、图片懒加载
- 预缓存后台顺序执行，不阻塞主流程

### 4.5 安全
- 华为签名链
- 无危险权限（仅网络）
- Cookie 沙箱存储

---

## 5. 测试与验证

### 5.1 回归清单（每次发版前真机验证）
1. 推荐流加载 + 文章详情打开
2. 关注流加载
3. 热榜加载 + 问题详情
4. 日报加载 + 日报文章详情
5. 搜索（登录后）
6. 收藏（收藏夹选择 + 状态刷新）
7. 保存为 Markdown
8. 图片查看（全屏 + 双指缩放 + 保存）
9. 我的页面
10. 断网缓存验证

### 5.2 工具
- `hdc`：安装/启动/截图
- `uitest dumpLayout`：控件定位
- `hilog`：日志抓取（grep ZhihuHttp / AppCrash）

---

## 6. 要求（Requirements）

### 6.1 硬约束
1. 完整移植不丢功能
2. UI 与 Android 版对齐
3. 包名/应用名不与原版冲突
4. 每次发版递增版本号
5. 文字阅读场景可选可复制
6. 默认字号偏大
7. 栏目可配置
8. 全功能正常不闪退
9. 深浅主题适配
10. 点击响应 ≤ 3s
11. 热榜/日报断网可看（缓存两天）

### 6.2 ArkTS 平台坑
| 坑 | 规避 |
|---|---|
| import 后不能有其他语句再接 import | interface 放所有 import 之后 |
| 禁裸对象字面量 | 显式声明 interface |
| 禁 any/unknown | 显式类型 + as 转换 |
| import 不带扩展名 | `from '../api/foo'` |
| copyOption 性能杀手 | 仅阅读场景保留 |
| 第三方应用不能直接写公共存储 | 用 DocumentViewPicker |

### 6.3 构建与发布流程
```bash
# 构建
cd ~/Work/zhihuLite-HM/harmony-native
hvigorw assembleHap --mode module -p product=default --no-daemon
# 复制产物
cp entry/build/.../entry-default-signed.hap ~/Work/zhihuLite-HM/ZhihuLite-HM-v<版本>-signed.hap
# 装机
hdc install -r <hap>
# 提交
git add -A && git commit && git push origin main
# Release
gh release upload v<版本> <hap> --clobber
```

---

## 7. 版本历史

| 版本 | 里程碑 |
|---|---|
| v0.1 | 首版可跑（仅浏览） |
| v0.2 | 命令行构建打通 |
| v0.3 | copyOption 减负，响应提速 |
| v0.3.1-v0.3.13 | 收藏/搜索/图片下载等功能修复 |
| v0.3.14-v0.3.15 | 正文大图/全屏看图/双指缩放 |
| v0.3.16-v0.3.44 | 富文本渲染（GFM）、文章内链接、收藏状态、反对按钮 |
| v0.3.45-v0.3.55 | 缓存体系（列表 + 内容级预缓存）、断网可看 |
| v0.3.56-v0.3.60 | 保存为 Markdown（DocumentViewPicker）、公共 DetailActionBar 组件 |
| **v0.3.61** | **基线版本**：公共操作栏统一线条图标、保存功能全覆盖（回答/文章/想法/日报）、内容预缓存、断网两天可读 |

---

## 8. 致谢

本项目初始版本参考复刻：[zhihu--](https://github.com/luckylew23/zhihu--)（上游 React Native 知乎客户端，MIT）
