# HarmonyOS 原生移植 —— 解析层 / 交互层 / 路由缺口排查报告

- 被查对象：`entry/src/main/ets/`
- 对照基线：`zhihu--/app/`（约 46 路由）+ `zhihu--/ohos/routeRegistry.ts`（官方原生路由映射表）
- 范围：解析层（feedParser 三函数）、交互层（Index/FeedCard/HotCard/详情与个人主页链路）、路由缺口
- 已知降级项（日报纯文本、OSS 未传、私信无 WebSocket、设置静态、富文本纯文本、FollowManage 空态、深色未核对）不再重复报告

---

## A. 真实缺陷

### A1 推荐流「视频卡片」被静默丢弃（高）
- 文件：`ets/api/feedParser.ts:44-50`（`toFeedType`）、`ets/pages/FeedListPage.ets:137-174`（`openDetail`）
- 现象：推荐流中 `type: 'zvideo' | 'video'` 的条目，`toFeedType` 返回 `null` → `parseRecommendData` 返回 `null` → `applyPage` 的 `forEach` 直接 `continue`，用户在「推荐」tab 永远刷不到任何视频卡片。
- 根因：上游 `FeedItem.type` 联合类型含 `'videos'`（`zhihu--/api/zhihu/feed.ts:339`），上游 `components/FeedCard.tsx:108` `isVideoType = item.type === 'videos'` 并跳转 `/video/[id]`；HMOS 移植时漏了 video 分支，且 `openDetail` 无 `videos` 分发。
- 修复建议：
  1. `toFeedType` 增加 `if (type === 'zvideo' || type === 'video') return 'videos'`；
  2. `FeedItem.type` 放开为含 `'videos'`；
  3. `FeedListPage.openDetail` / `FollowingPage.openDetail` 增加 `videos → pages/VideoPage { id }` 分支（VideoPage 已在 main_pages.json，目前无入口）。
- 严重度：中（内容缺失而非崩溃；但推荐流视频位长期为空白）。

### A2 问题详情页「写回答」按钮是空操作占位（高）
- 文件：`ets/pages/QuestionDetailPage.ets:146-151`（`onWriteAnswer`）、`:393`（按钮挂载）
- 现象：底部操作行「写回答」点击后，仅执行 `guardLogin()`，登录态下什么都不发生（注释自承"写回答编辑器暂未在本期移植，仅占位入口"）。上游 `app/question/write/[id].tsx` 是完整作答编辑器。
- 根因：`PublishAnswerPage` 已存在且原生支持 `questionId` 预填参数（`PublishAnswerPage.ets:37,43-51`），只是未接通跳转。
- 修复建议：`onWriteAnswer` 在守卫通过后改为：
  `router.pushUrl({ url: 'pages/PublishAnswerPage', params: { questionId: this.qId } });`
- 严重度：高（主链路按钮，高频可点区域，点了无反馈）。

### A3 通知列表点击无跳转（中）
- 文件：`ets/pages/NotificationsPage.ets`（全文件）
- 现象：通知条目行无 `onClick` 跳转；全页仅三处跳转：返回、去登录、重试。
- 根因：上游 `app/notifications/index.tsx:154-168` 按通知类型分别 `router.push('/answer/:id')` / `/question/:id` / `/article/:id` / `/user/:id`；HMOS 只移植了列表渲染，未移植 deep-link 分发。
- 修复建议：在通知行 `onClick` 中按通知 resource_type/url_token 分发到 AnswerDetailPage/QuestionDetailPage/ArticleDetailPage/PeoplePage（参数解析可复用上游对应分支）。
- 严重度：中（消息页变成"只看不能点"）。

### A4 热榜卡片配图丢失 children[0].thumbnail 兜底（低）
- 文件：`ets/api/feedParser.ts:210`（`parseHotData` image 行）
- 现象：热榜条目缩略图在 `image_area.url`、`image_url` 之外还有一种形态挂在 `item.children[0].thumbnail`，HMOS 未取，导致部分热榜条目右侧配图空白。
- 对照：上游 `(tabs)/index.tsx:1587-1591`：
  `target.image_area?.url || item.children?.[0]?.thumbnail || item.image_url || null`
- 根因：`RawFeedItem`（`feed.ts:237-264`）未声明 `children` 字段。
- 修复建议：`RawFeedItem` 增加 `children?: Array<{ thumbnail?: string }>`，parser image 行补回 `item.children?.[0] ?? null` 兜底。
- 严重度：低。

### A5 收藏数丢 reaction.statistics.favorites 兜底（低）
- 文件：`ets/api/feedParser.ts:131`（following）、`:163`（recommend）
- 现象：部分接口形态下收藏数恒为 0，FeedCard 统计行、FollowingPage 动态卡的 ☆ 计数都不显示。
- 对照：上游两处均为 `target.favorite_count || target.reaction?.statistics?.favorites || 0`（following）与 `target.favlists_count || target.favorite_count || target.reaction?.statistics?.favorites || 0`（recommend）。
- 根因：`RawFeedTarget`（`feed.ts:156-235`）未声明 `reaction?: { statistics?: { favorites?: number } }`。
- 修复建议：补类型声明 + parser 两处加兜底。
- 严重度：低。

### A6 推荐流过滤信号 isFollowingAuthor 未映射（低-中）
- 文件：`ets/api/feed.ts:282-308`（FeedItem）、`ets/api/feedParser.ts:152-181`
- 现象：上游 `FeedItem.isFollowingAuthor`（`api/zhihu/feed.ts:356`）由 `author.is_following` 映射（`index.tsx:1545`），供 `utils/feedFilter.ts:111` `keepFollowing` 规则使用；HMOS FeedItem 无此字段、parser 未赋值（`RawFeedAuthor.is_following` 已在 `feed.ts:119` 声明，数据其实拿到了）。
- 影响面：若「过滤与推荐」设置页后续启用"保留关注作者内容"类规则，信号缺失会把关注作者的内容一并过滤。当前 SettingsFilterPage 未消费该字段，暂未发作。
- 修复建议：FeedItem 加 `isFollowingAuthor?: boolean`，parseRecommendData 加 `isFollowingAuthor: Boolean(target.author?.is_following)`。
- 严重度：低（当前不发作，属埋点式欠账）。

### A7 「我的」页统计行三个入口不可点（中低）
- 文件：`ets/pages/ProfilePage.ets:240-243`
- 现象：统计 4 列中仅「关注」可点（→ FollowManagePage）；「回答 / 文章 / 粉丝」`statItem(..., false)`，点击无任何反应。
- 对照：上游 `(tabs)/profile.tsx:319-354` 四项均可点：回答→`/user/:id?tab=answers`、文章→`?tab=articles`、粉丝→`/user/:id/followers`。
- 修复建议：回答/文章 → `PeoplePage { urlToken, initialTab }`（PeoplePage 已支持 6 tab，加个初始 tab 参数即可）；粉丝 → PeoplePage followers tab（或独立 FollowersPage）。
- 严重度：中低。

### A8 PeoplePage 统计行整体不可点、互相关注 chip 缺失（低-中）
- 文件：`ets/pages/PeoplePage.ets:282-288`（`statItem` 无 onClick）、headerBlock `:372-380`
- 现象：用户主页「关注者/关注/赞同/回答」四列均不可点；上游 `app/user/[id]/index.tsx:849-855` 非本人且有互关数时显示「互相关注 N」chip → `/user/:id/mutual`，HMOS 无此 chip。
- 修复建议：统计列接 PeoplePage 内部 tab 切换；互关 chip 需要 `mutual_followees_count` 字段 + 互关列表页（见 B2）。
- 严重度：低-中。

### A9 InboxPage（私信会话列表）无入口（中）
- 文件：`ets/pages/InboxPage.ets`（注册于 main_pages.json:28）
- 现象：全工程无任何 `router.pushUrl → pages/InboxPage`（grep 确认）。用户只能从 PeoplePage「私信」按钮直接进单聊 ChatPage，会话列表永远进不去。
- 对照：上游 `(tabs)/profile.tsx:420-427`「我的私信」菜单（`enablePrivateMessaging` 开关）→ `/inbox`。
- 修复建议：ProfilePage 菜单组 2 增加「我的私信」行 → `pages/InboxPage`（私信 WebSocket 未实现属已知降级，列表页本身可先通）。
- 严重度：中。

### A10 UserLikesPage（我的点赞）无入口（低）
- 文件：`ets/pages/UserLikesPage.ets`（注册于 main_pages.json:17）
- 现象：全工程无引用；上游 `user/likes.tsx`（"我的点赞"）在 routeRegistry 中登记，PeoplePage「赞同」统计为其天然入口（HMOS 侧统计不可点，见 A8）。
- 修复建议：PeoplePage 头部「赞同」统计可点 → UserLikesPage。
- 严重度：低。

### A11 顶栏缺失「同城 / local」频道（低）
- 文件：`ets/pages/Index.ets:38`（`topTabOrder` 固定 `following/recommend/hot/daily`）、`ets/store/settingsStore.ts`（无 local 键）
- 现象：上游 TABS 含 `'local'`（`zhihu--/app/(tabs)/index.tsx:93-101`，走 `zhihu://local-feed`，`feed.ts:374-401` 已实现本地 feed 协议与 next URL 改写）；HMOS 顶栏无同城项，feed.ts 里的 local-feed 代码成为死路径。
- 修复建议：`topTabOrder` 与 `settingsStore.getVisibleTabs` 补 `local`，`pageForKey` 加 `FeedListPage({ feedMode: 'local' })` 分支。
- 严重度：低。

---

## B. 功能缺失（含上游位置）

| # | 缺失功能 | 上游位置 | 用户从哪点会落空 | 严重度 |
|---|---------|---------|----------------|--------|
| B1 | 游客预览详情页 guest/detail | `app/guest/detail.tsx`（feed 卡片 payload 整包预览） | 未登录时点推荐流无 id 的折叠/卡片形态条目，HMOS 直接拿 id 跳原生详情 API，接口可能 404 | 中 |
| B2 | 互相关注列表 user/[id]/mutual | `app/user/[id]/mutual.tsx`（入口：他人主页「互相关注 N」chip） | 非本人用户主页无 chip，入口与页面双缺 | 低-中 |
| B3 | 全部回复独立页 comments/replies/[id] | `app/comments/replies/[id].tsx` | HMOS CommentsPage 已内联展开前 2 条 + `handleExpand` 折叠展开（`CommentsPage.ets:357-370`），长回复场景不可分页加载全部 | 低 |
| B4 | 独立 followers 列表页 user/[id]/followers | `app/user/[id]/followers.tsx` | HMOS 用 PeoplePage 内联 followers tab 覆盖，功能已等价；唯一缺口是「我的」页粉丝统计不可点（见 A7） | 低 |
| B5 | 写回答编辑器入口未接通 | `app/question/write/[id].tsx` | 问题详情页「写回答」空操作（见 A2）；PublishAnswerPage 本体已移植 | 高（随 A2 修复） |
| B6 | VideoPage 无入口 | `app/video/[id].tsx` 已注册 main_pages.json | 推荐流 video 卡片被 parser 丢弃（见 A1），VideoPage 孤儿 | 中（随 A1 修复） |
| B7 | 通知 deep-link | `app/notifications/index.tsx:154-168` | 通知点击无跳转（见 A3） | 中 |

**别名/模板页，无需移植（对齐确认）：**
- `app/index.tsx`（Redirect → (tabs)）、`p/[id].tsx`（→ article/[id]）、`questions/[id].tsx`（→ question/[id]）、`question/[id]/answer/[answerId].tsx`（→ answer/[id]）均为别名重定向；
- `app/modal.tsx` 是 Expo 模板占位屏（仅显示 "Modal" 字样），无实际功能；
- `+html.tsx` / `+native-intent.tsx` / `+not-found.tsx` 为框架级文件，非业务页。

---

## C. 路由缺口表

上游以 `ohos/routeRegistry.ts` 的 ROUTES 为权威清单（共 36 条业务路由），对照 HMOS `main_pages.json` 33 项：

| 上游路由 | HMOS 承接页 | 状态 |
|---------|------------|------|
| login | LoginPage | ✅ |
| article/[id] | ArticleDetailPage | ✅ |
| question/[id] | QuestionDetailPage | ✅ |
| answer/[id] | AnswerDetailPage | ✅ |
| feedback | FeedbackPage | ✅ |
| search | SearchPage | ✅ |
| notifications | NotificationsPage | ✅（点击跳转缺，A3） |
| inbox | InboxPage | ✅ 已注册（无入口，A9） |
| history | HistoryPage | ✅ |
| collections | CollectionsListPage | ✅ |
| collections/[id] | CollectionDetailPage | ✅ |
| comments/[id] | CommentsPage | ✅ |
| topic/[id] | TopicPage | ✅ |
| people/[id] | PeoplePage | ✅ |
| column/[id] | ColumnPage | ✅ |
| pin/[id] | PinDetailPage | ✅ |
| user/[id] | PeoplePage | ✅ |
| user/[id]/stream | PeoplePage（动态 tab） | ✅ 内联覆盖 |
| user/[id]/following | FollowManagePage | ✅（空态为已知降级） |
| user/likes | UserLikesPage | ✅ 已注册（无入口，A10） |
| chat/[id] | ChatPage | ✅ |
| publish/answer \| article \| pin \| question | PublishAnswer/Article/Pin/QuestionPage | ✅ |
| publish（四宫格） | PublishPage | ✅ |
| settings/appearance \| filter | SettingsAppearance/FilterPage | ✅ |
| video/[id] | VideoPage | ✅ 已注册（无入口，A1/B6） |
| following/recommend/hot/daily 流 | FollowingPage/FeedListPage/DailyPage | ✅（组件内实现，非路由） |
| **guest/detail** | — | ❌ 缺失（B1） |
| **user/[id]/mutual** | — | ❌ 缺失（B2） |
| **user/[id]/followers**（独立页） | PeoplePage 内联 tab | ⚠️ 等价覆盖，统计入口断（A7/A8） |
| **comments/replies/[id]** | CommentsPage 内联展开 | ⚠️ 功能近似，无分页全部回复（B3） |
| **question/write/[id]** | PublishAnswerPage（已存在） | ⚠️ 页在但入口空操作（A2/B5） |
| p/[id]、questions/[id]、question/[id]/answer/[answerId] | 别名重定向 | ➖ 无需独立页 |
| modal | — | ➖ 模板占位，忽略 |

**HMOS 多出的页（上游无对应路由，属原生壳自有）：** DetailPage（旧 WebView 兜底详情）、CollectionPickerPage、VotersPage、DailyDetailPage。均在工程内有引用，不构成缺口。

---

## D. 对齐确认项（一行通过）

- 底栏 3 槽「首页组 / 圆形+发布 / 我的」与上游自定义底栏（`index.tsx:588+`）一致；中间 + → PublishPage 四宫格，四发布子页接通。
- 内层 TabsController 受控写法正确：`index: innerIndex` + `tabsCtrl.changeIndex` + `onChange 回写 innerIndex` 三同步（Index.ets:153,168-170），顶栏点击与滑动联动一致。
- 顶栏「关注/推荐/热榜/日报」key→页面映射、默认 tab 回落、回首页重置默认栏逻辑与上游 visibleTabs/defaultTab 模型对齐（仅缺 local，A11）。
- 热榜卡片点击 → QuestionDetailPage（FeedListPage.ets:176-182），与上游一致。
- ProfilePage → PeoplePage（url_token，缺失时 toast 不跳空页）→ FollowManage/CollectionsList/History/Settings*/Notifications/Feedback/Login 链路全部连通；未登录 guestView 分支正确。
- 登录守卫一致：PeoplePage 关注/私信、QuestionDetailPage 写回答、NotificationsPage 均 `guardLogin() → LoginPage`。
- 下拉刷新（Refresh + onRefreshing）+ 上拉加载（onReachEnd + loadingMore + isEnd footer）在 FeedListPage / FollowingPage / PeoplePage 均已实现，首屏 loading 与错误重试态齐全。
- parse 主字段对齐：id/title/questionId（question.id || 自身 id）/author（含 url_token、默认头像）/excerpt（excerpt || content[0].content || content 三兜底）/image（thumbnail || content_img[0]）/voteup_count||like_count/comment_count/relationship.voting/answer_type 大写归一 + paid_info 双信号/topics 过滤——与上游 `(tabs)/index.tsx:1390-1596` 逐字段一致。
