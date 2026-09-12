# zhihu-- HarmonyOS 原生移植 —— 全面排查报告（v0.1 基线）

- 被查对象：`harmony-native/entry/src/main/ets/`（pages 35、api 27、components、store、utils）
- 上游基线：`zhihu--/`（HEAD bf28d4a，v0.6.0），路由以 `ohos/routeRegistry.ts` 36 条为准
- 排查维度：API 层 / 页面层（路由·参数·异常态）/ 解析层 / 交互层 / 路由缺口
- 分级：**高**=运行时必现崩溃或主链路不可用；**中**=功能缺失或静默错行为；**低**=边缘/装饰性

> 详细逐行见同目录 `audit_api.md` / `audit_pages.md` / `audit_interaction.md`。

---

## A. 真实缺陷（按修复优先级）

### 🔴 高

| # | 位置 | 现象 | 根因 | 修复 |
|---|------|------|------|------|
| H1 | `components/profile/profileMappers.ets:210-212` `feedDetailUrl` | 视频条目返回 `pages/VideoDetailPage`，工程只有 `VideoPage` → PeoplePage/UserLikesPage/CollectionDetailPage 点视频必现跳转失败白屏 | 路由名拼写不一致 | 改 `return 'pages/VideoPage'` |
| H2 | `pages/QuestionDetailPage.ets:146-151` `onWriteAnswer` | 「写回答」按钮登录后点了无任何反应 | 空函数占位；`PublishAnswerPage` 已支持 `questionId` 却未接 | 守卫通过后 `pushUrl('pages/PublishAnswerPage', { questionId: this.qId })` |
| H3 | `api/member.ts:237-241` `getRecentMemberActivities` | 用户主页「最近更新」时间线整段 404/空 | URL 在 memberId 后漏 `/activities` 段，打到 `/people/{id}` | 补 `/activities` |
| H4 | `api/appApi.ts:60-80` `buildZhihuAppRecommendUrl` | 未登录推荐流下拉刷新恒发 `action=down`，拿不到新内容；`action/refresh_scene/is_feed_first_request` 及分页参数全丢 | ArkTS 禁展开，只手拷了 session_token，漏合并其余入参 | 按字段 `if (params.x!==undefined) merged.x=params.x` 逐个覆盖 |

### 🟡 中

| # | 位置 | 现象 | 修复 |
|---|------|------|------|
| M1 | `api/feedParser.ts:44-50` `toFeedType` + `FeedListPage.ets:137-174` | 推荐流 `zvideo/video` 类型返回 null 被 forEach 丢弃，推荐 tab 永远刷不到视频卡 | `toFeedType` 加 `zvideo/video→'videos'`；openDetail 加 `videos→pages/VideoPage{id}` |
| M2 | `pages/PeoplePage.ets:243-246` `openMessage` | 发消息传 `urlToken`，ChatPage 只读 `userId/threadId` → 私信入口报「缺少会话参数」 | 改传 `{ userId: member.id, name: member.name }` |
| M3 | `pages/NotificationsPage.ets`（全文件） | 通知条目无 onClick，只看不能点 | 按 resource_type/url_token 分发 AnswerDetail/QuestionDetail/ArticleDetail/PeoplePage（上游 `notifications/index.tsx:154-168`） |
| M4 | 5 个死路由无入口：`VotersPage / UserLikesPage / InboxPage / ColumnPage`（VideoPage 随 H1/M1 通） | 赞同者、我的点赞、私信列表、专栏详情全工程无 pushUrl | Voters 挂 AnswerDetail 赞同数；UserLikes 挂 PeoplePage「赞同」；Inbox 挂 Profile 菜单「我的私信」；Column 挂 FollowManage 专栏行 |
| M5 | `api/appApi.ts:82-97` `buildZhihuAppMomentsUrl` | 完全不接收 params，moments 游客流刷新 action 丢失（同 H4 根因） | 合并 params 字段 |
| M6 | `api/question.ts:129` | 游客走 app 端点时误用 web 长 include 当缺省，应为 app 专属 `read_count,query_info,voteup_count,voting,can_vote` | guest 分支缺省改 `ZHIHU_APP_QUESTION_INCLUDE` |
| M7 | `api/httpClient.ts:580` `toMethod` | `PATCH` 被映射成 POST → `article.ts:82 updateArticleDraft` 发 POST 而非上游 PATCH，文章草稿保存可能失效 | 验证 zhuanlan 是否接受 POST；不支持则需自定义 method |
| M8 | `api/member.ts:252-297` 归一化 | `target.author/question/title/excerpt/content/voteup_count` 等字段丢失 | 保留原 target 再覆盖 id/type/created/relationship |
| M9 | `pages/InboxPage` | 私信会话列表无任何入口（上游 Profile「我的私信」菜单未移植） | ProfilePage 菜单加「我的私信」→ InboxPage（WebSocket 缺失属已知降级） |
| M10 | `pages/ProfilePage.ets:240-243` | 我的页统计行「回答/文章/粉丝」不可点，仅关注可点 | 回答/文章 → PeoplePage{urlToken, initialTab}；粉丝 → followers tab |

### 🟢 低

| # | 位置 | 现象 |
|---|------|------|
| L1 | `api/feedParser.ts:210` | 热榜配图丢 `children[0].thumbnail` 兜底，部分热榜卡配图空白（RawFeedItem 缺 children 字段） |
| L2 | `api/feedParser.ts:131/163` | 收藏数丢 `reaction.statistics.favorites` 兜底，部分形态恒为 0 |
| L3 | `api/feed.ts:282-308` / `feedParser.ts:152` | `isFollowingAuthor` 未映射（数据已拿到），feedFilter 保留关注作者规则暂缺信号 |
| L4 | `pages/PeoplePage.ets:282-288` | 用户主页统计列全不可点；缺「互相关注 N」chip |
| L5 | `pages/FollowManagePage.ets:282-330` | itemRow 无 onClick（专栏数据拉到点不进 ColumnPage）；catch 后空态/失败态不分 |
| L6 | `pages/DetailPage.ets:32-47` `targetUrl` | 判 `question/article/pin`，调用方传复数 `answers/articles/pins/video`，未命中一律拼 answer 链接 |
| L7 | 全工程无 `onPageShow` | 登录/写操作返回后关注态、已赞态、评论数不刷新（仅 aboutToAppear 拉一次） |
| L8 | `pages/LoginPage.ets:62-64` | Web onErrorReceive 无提示无重试，失败停白屏 |
| L9 | `api/questionFeed.ts:181-210` | 归一化不做 `...target` 透传，`reaction_relation/sticky_info` 等丢弃（UI 暂未消费） |
| L10 | `api/answer.ts:179-192` | `voteAnswer` body 由 JSON 改 form-urlencoded，与上游契约不符（知乎实际兼容，建议抓包复核） |
| L11 | `api/httpClient.ts:291/519` | 2xx 空 body 被当错误抛「响应为空」，DELETE/204 端点误报失败 |
| L12 | `api/index.ts` barrel | 只 re-export 7 个模块（当前均子路径直 import，无运行时影响） |
| L13 | `pages/Index.ets:38` | 顶栏缺「同城/local」频道，feed.ts local-feed 代码成死路径 |

---

## B. 功能缺失（上游有、HMOS 无）

| 缺失 | 上游位置 | 影响面 |
|------|---------|--------|
| 写回答编辑器接线 | `app/question/write/[id].tsx` | 随 H2 修复（页面已在） |
| 游客详情预览 `guest/detail` | `app/guest/detail.tsx` | 未登录点无 id 折叠卡片可能 404（中） |
| 互相关注列表 `user/[id]/mutual` | `app/user/[id]/mutual.tsx` | 他人主页无「互相关注 N」chip，页与入口双缺（低-中） |
| 全部回复独立分页 `comments/replies/[id]` | `app/comments/replies/[id].tsx` | CommentsPage 已内联展开前 2 条+折叠，长回复不可分页（低） |
| 通知 deep-link | `app/notifications/index.tsx:154-168` | 随 M3 修复 |
| appApi 未导出 4 个 builder + 2 个 include 常量 | `api/zhihu/appApi.ts` | question.ts/moments.ts 已内联复刻（功能不缺），但内联引入了 M6，建议回收统一 |
| 楼中楼回复二级页 | `app/comments/replies/[id].tsx` | 评论「查看回复」无二级楼 |

别名/模板无需移植（已确认）：`p/[id]`、`questions/[id]`、`question/[id]/answer/[answerId]`（均 redirect）、`modal.tsx`（Expo 占位）、`+html/+native-intent/+not-found`（框架文件）。

## C. 已知降级项（确认仍为降级，不计缺陷）

1. 日报正文 HTML 剥标签纯文本（`daily.ts htmlToPlainText`）✅
2. 发布图片上传 OSS 未实现（仅本地选择/占位）✅
3. 私信 ChatPage 无 WebSocket，HTTP 降级 ✅
4. 设置类部分静态（外观/通知等，仅 visibleTabs/defaultTab/theme/filter 持久化）✅
5. 富文本/LaTeX 纯文本渲染 ✅
6. FollowManagePage 后三子 tab（话题/问题/收藏夹）无接口走空态 ✅
7. 深色模式未逐屏真机核对；无真机未做运行时视觉回归 ✅

## D. 通过项（无需动）

- 所有请求 URL 均为完整 https，grep 无残留相对路径；baseURL 四个域名全部正确
- x-zse-96 签名仅 cookie 非空且 d_c0 存在时注入；zhuanlan 主机豁免；oauth/token-refresh 走 rawRequest 不被错签；daily 独立 client 不带签名
- main_pages.json 33 项与文件一一对应，无大小写问题；参数键名除 M2 外全部对齐；api import 无悬空导出
- 底栏 3 槽 + 中间发布入口、TabsController 三同步受控、热榜跳详情、Profile→People→各子页链路、guardLogin 未登录分支、下拉刷新+上拉加载
- feedParser 主字段（id/title/questionId/作者三兜底/excerpt 三兜底/盐选双信号/topics 过滤）与上游 `index.tsx:1390-1596` 逐字段一致
- zse96 签名模块与上游逐行对齐
