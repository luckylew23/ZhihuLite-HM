# HarmonyOS 页面层移植排查报告

排查范围：`entry/src/main/ets/pages/`（36 个 .ets）、`main_pages.json`（33 项注册）、全量 `router.pushUrl` 调用与 `router.getParams()` 取值、`api/` 导出、生命周期。
对照上游：`/Users/admin/workbuddy/zhihu--/app/`（TSX 路由）。
已知降级项（设置静态页、FollowManagePage 后三子 tab 空态、富文本纯文本、无真机视觉回归）不计为缺陷。

---

## 一、路由注册核对（第 1 项）

- main_pages.json 33 项，全部能在 pages/ 下找到对应文件，无"注册了但文件不存在"项。
- pages/ 下存在但未注册：`DailyPage.ets`、`FeedListPage.ets`、`ProfilePage.ets`。
  - **结论：非缺陷**。这三个文件是 `Index.ets` 的内嵌子组件（`@Component export struct`，无 `@Entry`），由 Index 以 `FeedListPage({feedMode})` / `DailyPage()` / `ProfilePage()` 方式组合进 Tab，本就不应进路由表。
- 拼写/大小写：注册名与文件名逐字一致，无大小写不一致项。
- **死路由（注册了但全工程无任何 pushUrl 调用）**：见 A3。

---

## 二、A 类：真实缺陷

### A1【高】视频 Feed 跳转打到不存在的路由名
- 位置：`components/profile/profileMappers.ets:210-212`（`feedDetailUrl`）
- 现象：视频类型返回 `'pages/VideoDetailPage'`，但工程里只有 `VideoPage.ets`（注册名 `pages/VideoPage`）。
- 根因：命名拼写不一致（VideoDetailPage vs VideoPage）。HarmonyOS 路由名大小写敏感且未在 main_pages.json 注册，命中后 pushUrl 失败/落空白屏。所有走 `feedDetailUrl(item)` 的入口（PeoplePage:251、UserLikesPage:91、CollectionDetailPage:100）点到视频条目必现。
- 修复：把 `return 'pages/VideoDetailPage'` 改为 `return 'pages/VideoPage'`。
- 严重度：高。

### A2【中】个人页"发消息"跳 ChatPage 参数键名不匹配
- 位置：`pages/PeoplePage.ets:243-246`（openMessage）
- 现象：pushUrl 传 `{ urlToken: this.token }`；而 `pages/ChatPage.ets:32-37` 只取 `userId` / `threadId`，取不到即 `otherId=''`，页面直接走"缺少会话参数"错误分支，私信发不出去。
- 根因：调用方用 urlToken，接收方约定 userId/threadId。InboxPage:69 跳 ChatPage 传的是 `{ name, userId }`，是对的；PeoplePage 这一处漏改。
- 修复：openMessage 改传 `{ userId: this.member?.id ?? '', name: this.member?.name ?? '' }`（上游 chat/[id] 用的是用户 id；确认 `getMessages` 是否接受 url_token，必要时在 mapper 层补 id）。
- 严重度：中。

### A3【中】5 个已注册页面无任何入口（死路由）
- 全工程 grep 无 pushUrl 指向：
  - `pages/VideoPage` —— 因 A1 拼写错误永远到不了（修 A1 后仍无调用方，Feed 里 video 类型经 feedDetailUrl 才能到，修 A1 即通）。
  - `pages/VotersPage` —— 赞同者列表页。`AnswerDetailPage` 赞同数/"查看全部赞同者"未挂跳转。
  - `pages/UserLikesPage` —— "我赞过的内容"。Profile 菜单/PeoplePage 均无入口。
  - `pages/InboxPage` —— 私信会话列表。消息通知页（NotificationsPage）无私信入口。
  - `pages/ColumnPage` —— 专栏详情。FollowManagePage 专栏 tab 行不可点（见 A4），Feed/文章头也无专栏跳转。
- 修复：在对应列表项 onClick 补 pushUrl，并按各页 getParams 约定传参（VotersPage 要 `contentId/contentType/count`；InboxPage 无需参；ColumnPage 要 `id`）。
- 严重度：中。

### A4【低】FollowManagePage 列表行不可点击 + 无错误态
- 位置：`pages/FollowManagePage.ets:282-330`（itemRow）、`loadTab` catch 分支 132-135。
- 现象：itemRow 没有 onClick，专栏/话题/问题/收藏夹点击无任何反应；loadColumns/loadTopics/loadQuestions 已能拉到数据，但点不进 ColumnPage/TopicPage/CollectionDetailPage。catch 后直接 `items=[]` 渲染"暂无数据"，与"接口失败"无法区分，也无重试。
- 根因：只渲染未挂事件；错误态与空态共用一个分支。
- 修复：itemRow 按 currentTab 分发跳转（专栏→ColumnPage id、话题→TopicPage id、收藏夹→CollectionDetailPage id）；loadTab 增加 `tabError: string[]` 状态，失败时展示错误文案 + 重试。
- 严重度：低。

### A5【低】DetailPage 兜底链接类型判断与传入值不一致
- 位置：`pages/DetailPage.ets:32-47`
- 现象：`targetUrl()` 判断 `contentType==='question'/'article'/'pin'`，但兜底来源（FeedListPage:162、FollowingPage:159、SearchPage:302）传入的 `type` 是 feed 类型 `'answers'/'articles'/'pins'/'questions'/'video'`。未命中时一律拼 `https://www.zhihu.com/answer/<id>`，video 等类型会打开错误链接。
- 修复：分支按 feed 复数类型映射（questions→question、articles→article、pins→pin、其它→answer），与 feedDetailUrl 保持同一套映射。
- 严重度：低。

### A6【低】LoginPage Web 加载失败无错误态/重试
- 位置：`pages/LoginPage.ets:62-64`（onErrorReceive）
- 现象：仅 `loading=false`，网络/WebView 加载失败时画面停在白屏，无提示无重试按钮。
- 修复：onErrorReceive 设 `@State webError`，build 中叠一个"加载失败，点击重试"（`this.controller.refresh()`）。
- 严重度：低。

### A7【低】全工程无 onPageShow，登录/写操作返回后不刷新
- 现象：所有详情页、PeoplePage、CommentsPage 都只在 `aboutToAppear` 拉一次数据，无 `onPageShow`。经 `guardLogin()` pushUrl 到 LoginPage 再 router.back() 返回后，关注态/已赞态/评论数仍是旧值；ProfilePage 作为 Index 内嵌组件，登录返回后是否重拉 getMe 依赖条件渲染重建，不可靠。
- 修复：PeoplePage/AnswerDetailPage/QuestionDetailPage/ProfilePage 增加 `onPageShow()`，对"可能被外部改变"的字段（isFollowing、voting、评论数、me 信息）做轻量刷新。
- 严重度：低。

---

## 三、B 类：上游有、本页缺的交互

- B1 楼中楼回复未移植：上游 `app/comments/replies/[id].tsx` 在 Harmony 无对应页；CommentsPage 点评论"查看回复"无二级回复楼。
- B2 写回答未接线：`pages/QuestionDetailPage.ets:146-151` `onWriteAnswer` 是空函数占位（注释自承认）；上游 `app/question/write/[id].tsx` 针对具体问题写回答，而 `PublishAnswerPage` 从 PublishPage 四宫格进入时不传 `questionId`/`id`，无法关联问题。
- B3 PeoplePage 的 mutual（互相关注）tab 未做（上游 user/[id]/mutual.tsx）；followers/following/stream/answers/articles/pins 已内嵌为 tab。
- B4 NotificationsPage 通知卡片点击不跳详情（文件头注释自承认：赞同/评论/关注通知点了无反应）。
- B5 私信会话列表 InboxPage 无入口（同 A3）。
- B6 上游 `app/guest/detail.tsx`、`+not-found.tsx`：Harmony 用 DetailPage 兜底，可接受，不单列缺陷。

---

## 四、参数键名一致性核对结论（第 2 项）

| 目标页 | 调用方传键 | 页面读取键 | 结论 |
|---|---|---|---|
| AnswerDetailPage | id | id | 一致 |
| ArticleDetailPage | id | id | 一致 |
| PinDetailPage | id | id | 一致 |
| QuestionDetailPage | id | id | 一致 |
| TopicPage | id | id | 一致 |
| ColumnPage | id | id | 一致（但无调用方，见 A3） |
| CollectionDetailPage | id | id | 一致 |
| CollectionsListPage | 无 | 无 | 一致 |
| DailyDetailPage | id, title | id, title | 一致 |
| CommentsPage | resourceType, resourceId（单数/复数都兼容） | resourceType, resourceId, text | 一致 |
| CollectionPickerPage | resourceType('answer'/'article'), resourceId | 同 | 一致 |
| PeoplePage | urlToken（兼容 memberId） | urlToken, memberId | 一致 |
| ChatPage | InboxPage: name, userId；PeoplePage: **urlToken** | name, threadId, userId | **PeoplePage 处不匹配（A2）** |
| DetailPage | excerpt,id,questionId,title,type,url | 同 | 一致（type 取值见 A5） |
| SearchPage | 无（仅 Index/FeedListPage 跳） | 不读路由参 | 一致 |
| VotersPage | 无调用方 | contentId, contentType, count | 入口缺失（A3） |
| PublishAnswerPage | PublishPage 无参 | id, questionId | 缺问题上下文（B2） |
| VideoPage | feedDetailUrl 路由名错（A1），调用方仅传 id/questionId | id,title,author,description | 修 A1 后 title/author/desc 仍为空，需补传 |

无 `url_token`/`urlToken` 与 `id`/`answerId`/`questionId` 在目标页拼写错配之外的其它键名错配。

---

## 五、其它检查项结论（3/4/5/6）

- @Entry 与文件命名：除上述 3 个内嵌组件（DailyPage/FeedListPage/ProfilePage，设计如此）外，其余页面 @Entry/@Component 齐全，struct 名与文件名一致。
- 异步 try/catch / loading / 空态 / 错误态：
  - 已具备 try/catch + loading + error 重试：AnswerDetailPage、ArticleDetailPage、ChatPage、CollectionDetailPage、CollectionPickerPage、CollectionsListPage、ColumnPage、CommentsPage、DailyDetailPage、FollowingPage、HistoryPage、InboxPage、NotificationsPage、PeoplePage、PinDetailPage、QuestionDetailPage（answersError）、SearchPage、UserLikesPage、VotersPage。
  - 纯静态/无网络页：DetailPage、VideoPage、PublishPage、SettingsAppearancePage、SettingsFilterPage（后两者为已知降级）。
  - 缺错误态：FollowManagePage（A4）、LoginPage（A6）、ProfilePage（getMe 失败静默空态，可接受）。
- api import：全量校验 pages/ 与 components/ 中 `import {…} from '../api/x'` 的命名导出名，**全部解析成功，无悬空导出名/路径**（api/index.ts 为 barrel，无独立具名导出，正常）。
- 生命周期：无 onPageShow（A7）；栈操作均为 pushUrl/router.back()，未见误用 replaceUrl 致栈深异常；guardLogin 未登录跳 LoginPage 后 back 返回逻辑正常。

---

## 六、对齐确认（无缺陷）

AnswerDetailPage、ArticleDetailPage、PinDetailPage、QuestionDetailPage、TopicPage、CommentsPage、CollectionPickerPage、CollectionDetailPage、CollectionsListPage、DailyDetailPage、DailyPage(内嵌)、FeedListPage(内嵌)、FollowingPage、HistoryPage、Index、LoginPage、NotificationsPage、PeoplePage、PublishArticlePage、PublishPinPage、PublishQuestionPage、PublishPage、SearchPage、SettingsAppearancePage(已知静态)、SettingsFilterPage(已知静态)、ProfilePage(内嵌) —— 路由/参数/异常态对齐。
