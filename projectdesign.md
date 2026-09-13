# ZhihuLite-HM 项目设计文档

> **项目**：ZhihuLite-HM（知乎Lite）—— 上游 [zhihu--](https://github.com/luckylew23/zhihu--) v0.6.0（React Native / Expo）的 HarmonyOS NEXT 原生移植
> **技术路线**：方案 B —— 复用上游纯 TypeScript 业务逻辑 + ArkTS 重写 UI（旧 WebView 壳方案已否决，`harmony/` 目录保留归档）
> **本文件**：特性 / C4 架构 / 设计 / 测试验证 / 要求的唯一事实来源，随开发持续迭代更新

---

## 1. 项目概述

| 项 | 值 |
|---|---|
| 应用显示名 | 知乎Lite |
| Bundle Name | `com.zhihulite.hmos`（与原版 `com.huamu013.ZhihuMinusMinus` 隔离，不冲突） |
| 当前版本 | v0.3.8（versionCode 143） |
| 上游基线 | `~/workbuddy/zhihu--/`（HEAD bf28d4a，v0.6.0） |
| 工程目录 | `~/workbuddy/zhihu--HMOS/harmony-native/` |
| 远程仓库 | `git@github.com:luckylew23/ZhihuLite-HM.git` |
| 页面 / API 模块 | 36 个页面（`main_pages.json` 33 条路由）、27 个 API 模块 |
| SDK | DevEco Studio 内置 OpenHarmony SDK 6.0.2 / API 20 |
| 签名 | 华为开发者签名链（真机可装）；自签仅模拟器信任 |

---

## 2. 特性（Features）

### 2.1 首页与栏目
- **底栏三槽**：首页（字符 ⌂ + 文字标签）/ 发布（+）/ 我的（字符 👤 + 文字标签）
- **首页内层可滑动 Tabs**：关注 / 推荐 / 热榜 / 日报，默认进推荐；栏目可见性可配置（`settingsStore.visibleTabs`），至少保留一栏、profile 常驻
- **登录后状态刷新**：登录/登出翻转 `loginVersion`，主框架按 key 强制重建各列表页
- 下拉刷新 + 触底加载更多（cursor/offset 分页）

### 2.2 登录与会话
- WebView 内嵌知乎登录（LoginPage，失败有错误提示 + 重试）
- Cookie 持久化（preferences），启动 bootstrap 恢复登录态
- `z_c0` 判定登录；401 自动刷新会话（token refresh + oauth sign_in）

### 2.3 内容浏览
- 推荐流 / 关注流 / 热榜（热度值+回答数）/ 日报（每日 5 篇带图）
- 问题详情、回答、文章、想法（pin）、视频、专栏、话题详情
- 富文本正文（回答/文章 HTML）**降级为纯文本渲染**（剥标签 + 解码实体，图片占位 `[图片]`）

### 2.4 互动与创作
- 点赞 / 收藏（收藏夹：我的收藏内容 + 分类）/ 关注 / 评论
- 写回答、写文章、发想法、提问（发布页入口 + 四类发布页）
- 赞同者列表、我的点赞、浏览历史

### 2.5 搜索
- 综合 / 用户两个 tab、筛选、时间范围、重置
- 搜索接口 `search_v3` **强制登录**（未登录明确提示）
- 结果解析对 `object` / `highlight` / `question` 等 null 字段全防护（v0.3.8 修复）

### 2.6 个人中心
- 我的统计（回答/文章/粉丝可点）、收藏、私信（HTTP 降级，无 WebSocket）、通知、历史、赞同
- 他人主页：时间线、统计、关注/私信入口、互相关注

### 2.7 设置
- 主题模式（auto / light / dark，默认 auto 深色）、栏目可见性、默认首页栏目、内容过滤
- 外观 / 筛选页持久化

### 2.8 搜索关键词（应用可发现性）
- 包内 `metadata.keywords`：知乎,zhihu,知乎Lite,ZhihuLite,zhihulite,轻量,知乎第三方,知乎鸿蒙版,知乎客户端,鸿蒙知乎,知乎轻量版,zhihu-lite,知乎minimal
- 应用描述 `description_application`（关于页可见，含关键词文案）
- 说明：应用市场搜索关键词主配置在 AGC 发布后台，包内 keywords/description 为辅助

---

## 3. C4 架构

### 3.1 系统上下文（C1）

```
┌──────────┐  使用   ┌──────────────────┐   HTTPS    ┌────────────────────────────┐
│  用户     │ ─────▶ │ ZhihuLite-HM 应用 │ ─────────▶ │ 知乎服务端（四个域名）        │
│ (真机)    │        │  (HarmonyOS HAP)  │ ◀───────── │ www.zhihu.com 网页端点       │
└──────────┘        └──────────────────┘   响应+签名  │ api.zhihu.com 设备态端点     │
                                                      │ zhuanlan.zhihu.com 专栏      │
                                                      │ api.zhihu.com/oauth 认证     │
                                                      └────────────────────────────┘
```

### 3.2 容器（C2）

```
ZhihuLite-HM (entry HAP)
│
├── UI 层（ArkTS）         36 pages + components（List/ForEach/Image，无 WebView 渲染内容）
│     ├── pages/Index.ets  主框架：底栏 3 槽 + 内层 Tabs + loginVersion 重建
│     ├── pages/*Detail*   详情页族（问题/回答/文章/想法/视频/专栏/话题）
│     ├── pages/Publish*   发布页族（问题/回答/文章/想法）
│     ├── pages/Profile*   个人中心族（我的/他人主页/收藏/历史/通知/私信）
│     └── components/      复用组件（FeedCard/HotCard/AnswerCard/CommentRow/...）
│
├── API 适配层（api/）      27 个模块：feed / question / answer / article / pin / daily /
│                          search / collection / me / member / chat / notification / ...
│     └── httpClient.ts    核心单例：@ohos.net.http 替代 axios
│                            · Cookie Jar（持久化 + 按 URL 取 cookie）
│                            · 自动签名头（x-zse-96 / x-zse-93 / X-Udid / x-xsrftoken）
│                            · 401 自动刷新会话
│                            · ApiError（status/code/body/message）+ 200+error 业务错误识别
│                            · hilog 全量请求/响应日志（URL+status+len+err）
│     └── zse96/           x-zse-96 签名算法（hmac / encryptZseV4 / zse_purity 常量）
│
├── 状态层（store/）        authStore（登录态+cookie 持久化）、settingsStore（主题/栏目/默认页）
│                            AppStorage 全局态（loginVersion 重建信号）
│
└── 基础设施
      ├── 存储：@kit.ArkData preferences（cookie / user_name / 设置项）
      ├── 日志：@kit.PerformanceAnalysisKit hilog（TAG ZhihuHttp / JSAPP）
      └── 网络：@kit.NetworkKit http（无 CORS 约束）
```

### 3.3 组件（C3）

| 组件 | 职责 | 关键文件 |
|---|---|---|
| 主框架 | 底栏 + 内层 Tabs + 栏目动态渲染 + 登录重建 | `pages/Index.ets` |
| 详情页族 | 类型分发（复数类型兼容）+ 各内容详情 | `DetailPage` / `QuestionDetailPage` / `AnswerDetailPage` / `ArticleDetailPage` / `PinDetailPage` / `VideoPage` / `ColumnPage` / `TopicPage` |
| 发布页族 | 四类创作入口与表单 | `PublishPage` + `PublishQuestion/Answer/Article/Pin` |
| 个人中心族 | 我的 / 他人主页 / 收藏 / 历史 / 通知 / 私信 | `ProfilePage` / `PeoplePage` / `CollectionsListPage` / `CollectionDetailPage` / `UserLikesPage` / `HistoryPage` / `NotificationsPage` / `InboxPage` / `ChatPage` |
| 搜索 | 综合/用户搜索 + 结果解析防护 | `SearchPage` |
| 列表卡片 | 信息流 / 热榜 / 评论 / 收藏 / 成员行 | `FeedCard` / `HotCard` / `CommentRow` / `CollectionRow` / `MemberRow` / `AnswerCard` |
| 会话 | 登录 WebView 页 | `LoginPage` |
| 设置 | 外观 / 栏目 / 过滤 | `SettingsAppearancePage` / `SettingsFilterPage` |

### 3.4 代码（C4）

```
harmony-native/entry/src/main/ets/
├── entryability/EntryAbility.ets      入口 Ability（setAppContext、暗色跟随）
├── pages/                             36 个页面
├── components/                        detail / interaction / profile 分组组件
├── api/                               27 个 API 模块 + httpClient + zse96/
├── store/                             authStore / settingsStore
├── model/zhihu.ts                     知乎数据模型接口
└── utils/                             theme / date / url / zhihuError / feedIdentity / md5
```

关键实现要点（代码层）：
- **签名算法**：`zse96/hmac.ts` + `encryptZseV4`，与上游逐行对齐；zhuanlan 主机豁免、oauth/token-refresh 走 rawRequest 不被错签
- **Cookie Jar**：`cookieStringFor(url)` 按域取 cookie；游客 bootstrap（`GET www.zhihu.com/` 种 d_c0）；登录后 z_c0 持久化
- **登录态判定**：`hasAuthenticationCookie`（`/(?:^|;\s*)z_c0=/`）
- **页面重建**：`AppStorage 'loginVersion'` + 组件 `key` 绑定，登录/登出后强制刷新列表

---

## 4. 设计

### 4.1 UI 设计
- **主题**：`utils/theme.ts` 导出 `ZhihuColors`（primary `#0084ff`），light/dark 双套；应用默认深色（auto 跟随系统）；颜色一律走主题，禁止硬编码
- **UI 对齐**：对照 Android 版截图（`screenshot/v0.6.0/`）原样复制布局与交互
- **字号**：默认正文偏大（v0.3.2 全局 +1，满足可读性）
- **文字可选**：仅阅读场景保留 `copyOption`（详情正文/评论），全局 421→6 处——copyOption 是性能毒药，列表/按钮/标签全部禁用
- **品牌**：应用名"知乎Lite"、图标蓝底白"知"字 + LITE 标；底栏用字符 ⌂ / 👤 + 文字标签
- **顶栏**：页面内自绘 Row（返回 ← + 标题），不依赖系统标题栏

### 4.2 网络设计
- 单例 `zhihuClient.get/post/send<T>`，`ApiResponse<T> = {status, headers, data}`
- 自动处理：Cookie Jar → 签名头 → 请求 → 401 刷新 → 重试；业务错误（200 + `{error}`）统一抛 `ApiError`
- 设备态端点（api.zhihu.com）需 `appApi.ts` 的专用头（`getZhihuAppEndpointHeaders`）
- 日志可观测：`hilog 'ZhihuHttp'` 打印 `method url status len err`，`hilog -x | grep ZhihuHttp` 可抓

### 4.3 数据与存储设计
- `preferences`（`@kit.ArkData`）持久化：`auth_cookie` / `user_name` / `theme_mode` / `visible_tabs` / `default_tab` / 过滤项
- 单账号模型（v1.0 简化）；卸载重装清登录态（Cookie 在应用沙箱）

### 4.4 性能设计
- copyOption 最小化（见 4.1）——ArkUI 文本选择能力注册开销大，是"点击半天不响应"的根因
- 登录重建机制（loginVersion + key）在"状态正确"与"重建开销"间取权衡
- 分页触底加载、图片懒加载（List 机制）

### 4.5 安全与签名
- 华为签名链（DevEco 自动签名，物料 `~/.ohos/config/default_harmony-native_*.p12/.p7b`）——真机安装必需
- 命令行签名链路已打通（见 `scripts/sdk-build-patch.md`），IDE 非必需
- 不携带任何额外权限（仅 INTERNET / GET_NETWORK_INFO）

---

## 5. 测试与验证

### 5.1 静态审计（AUDIT_REPORT.md）
- 分级：高=运行时必现崩溃/主链路不可用；中=功能缺失/静默错行为；低=边缘/装饰
- **高（H1-H4）已修**：视频路由名、写回答接线、活动时间线 URL、推荐刷新参数合并
- **中（M1-M10）已修**：视频卡类型、私信参数、通知分发、5 个死路由入口、moments 参数、question guest 缺省、PATCH 映射、member 归一化、私信入口、我的统计可点
- **低（L 系列）**：L1/L6/L7/L8/L11 已修（热榜配图兜底、详情类型分发、onPageShow 刷新、登录错误提示、2xx 空 body）；其余记录在案

### 5.2 构建验证
- 命令行构建：`hvigorw assembleHap --mode module -p product=default --no-daemon`
- 编译期问题全为 ArkTS 规则（见 6.2 平台坑），构建输出 `entry-default-signed.hap`
- 资源/配置变更后必须重新构建验证（如 string.json 格式错误会阻断构建）

### 5.3 真机验证（自动化 + 真人）
- 工具链：`hdc`（`/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc`）
- `uitest dumpLayout -p <json>` 拿控件真实 bounds（比猜坐标可靠）；`uitest uiInput click/swipe/keyEvent Back/Home` 可自动化
- 无文本注入手段 → 搜索等需输入场景交真人验证
- 页面栈残留会误导测试 → 先 `aa force-stop` 冷启动
- **v0.3.6 全面验证通过**：四 tab 有内容 / 热榜→原生详情 / 收藏夹 1303+7 分类 / 底栏/名称/图标正常
- **v0.3.8**：搜索请求 200+192KB 数据、解析 null 崩溃修复（真机日志确认 `TypeError: Cannot read property 'title' of null` 消失）

### 5.4 已知降级项（确认仍为降级，不计缺陷）
1. 日报正文 HTML 剥标签纯文本
2. 发布图片上传 OSS 未实现（仅本地选择/占位）
3. 私信无 WebSocket，HTTP 降级
4. 设置部分静态（外观/通知，仅 visibleTabs/defaultTab/theme/filter 持久化）
5. 富文本/LaTeX 纯文本渲染
6. FollowManagePage 后三子 tab（话题/问题/收藏夹）空态
7. 深色模式未逐屏真机视觉回归（待补）

---

## 6. 要求（Requirements）

### 6.1 硬约束（用户明确要求，不可退让）
1. **完整移植不丢功能**：zhihu-- 整个项目移完整植，未登录/登录后功能都要有
2. **UI 与 Android 版原样复制**（对照 `screenshot/v0.6.0/`）
3. **包名/应用名不与原版冲突**：bundleName `com.zhihulite.hmos`、应用名"知乎Lite"、图标独立
4. **构建包名用应用名称**：产物命名 `ZhihuLite-HM-v<版本>-signed.hap`
5. **文字可选可复制**：至少阅读场景（正文/评论）可选中复制
6. **默认字号调大**（参考原版可读性）
7. **栏目可配置**：关注/推荐/热榜/日报等可配置是否展现
8. **搜索关键词**：知乎、zhihu、lite、轻量、知乎第三方、知乎鸿蒙版等（已配置，见 2.8）
9. **每次发版递增版本号**（versionCode 递增，versionName 语义化）
10. **搜索功能可用**（v0.3.8 起搜索解析全防护）

### 6.2 平台坑清单（ArkTS / HarmonyOS）
| 坑 | 规避 |
|---|---|
| import 不带扩展名 | `from '../api/foo'` |
| 无浏览器 URL 类 | `@kit.ArkTS` 的 `url.URL` + `searchParams` |
| 禁止对象/数组展开 | 逐字段赋值 / push 循环 |
| `@State` 不能叫 `id` | 改名 `itemId` 等 |
| 类型严格、禁隐式 any | 显式 `as X`，可空用 `| null` |
| 禁裸对象字面量（`arkts-no-untyped-obj-literals`） | 显式声明类型；空对象用 nullable + 条件判断 |
| 禁 `Object.create`（`arkts-limited-stdlib`） | 不用标准库受限 API |
| 禁 `unknown`（`arkts-no-any-unknown`） | 用宽类型 + 显式转换 |
| AppStorage V1 为全局 API（SDK 6.0.2 Kit 不导出） | 直接全局用，不从 Kit import |
| Stack 内自定义组件链式报错 | 外层包 Column |
| `@ohos.net.http` 无 PATCH | POST 替代或验证服务端兼容 |
| copyOption 性能杀手 | 仅阅读场景保留 |

### 6.3 构建与发布流程
```bash
# 构建（工程目录内）
cd ~/workbuddy/zhihu--HMOS/harmony-native
/Applications/DevEco-Studio.app/Contents/tools/node/bin/node \
  /Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw.js \
  assembleHap --mode module -p product=default --no-daemon
# 产物 → 按应用名+版本交付
cp entry/build/default/outputs/default/entry-default-signed.hap \
   ~/workbuddy/zhihu--HMOS/ZhihuLite-HM-v0.3.8-signed.hap
# 安装（真机在线）
HDC=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc
$HDC list targets
$HDC -t <serial> install -r <hap>
# 冷启动测试
$HDC -t <serial> shell aa force-stop com.zhihulite.hmos
$HDC -t <serial> shell aa start -a EntryAbility -b com.zhihulite.hmos
```

### 6.4 文档迭代要求（持续）
- 本文件（projectdesign.md）= 特性/C4/设计/测试/要求的唯一事实来源，随开发同步更新
- `README.md` = 项目对外说明，发版时刷新
- `AUDIT_REPORT.md` / `PORTING_SPEC.md` / 移植记录（`~/vault/Notebook/Duobao/`）同步维护
- 每次任务完成沉淀经验教训，防重踩
