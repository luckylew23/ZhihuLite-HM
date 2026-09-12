# HarmonyOS 原生移植 —— API 层排查报告

- 被查对象：`harmony-native/entry/src/main/ets/api/`（27 个 .ts + `zse96/`）
- 上游参照：`zhihu--/api/zhihu/`（24 模块）+ `zhihu--/api/client.ts` + `zhihu--/api/zse96/`
- 结论：URL 全部为完整 https（无残留相对路径，grep 0 命中）；baseURL 常量正确；签名注入逻辑与上游一致。发现 **3 个高危、3 个中危、4 个低危**，另有 1 组上游导出缺失（已内联复刻但带 bug）。

---

## A. 真实缺陷

### A1〔高〕`member.ts:237-241` — getRecentMemberActivities URL 漏 `/activities` 段
- **现象**：HMOS 请求 `https://api.zhihu.com/moments/recent/people/{id}?action=down&offset=..&page_num=..`；上游 `member.ts:168` 为 `https://api.zhihu.com/moments/recent/people/{id}/activities?action=down&offset=..&page_num=..`。
- **根因**：拼接 URL 时在 memberId 后漏掉了 `/activities`，打到了错误的端点。
- **修复**：在 `encodeURIComponent(String(memberId))` 后补 `/activities` 再接 `?action=down...`。
- **严重度**：高 ——「最近更新 / 用户主页时间线」整段流会 404/空。

### A2〔高〕`appApi.ts:60-80` — buildZhihuAppRecommendUrl 丢弃调用方全部入参（除 session_token）
- **现象**：HMOS 先放死默认值，再仅 `if (params.session_token !== undefined) merged['session_token']=...`，**没有**像上游那样 `...params`。`feed.ts:363` 传入的 `action / refresh_scene / is_feed_first_request`（以及可由调用方覆盖的 `after_id / end_offset / page_number / start_type / device / include_guide_relation` 等）全部被静默丢弃。
- **根因**：ArkTS 禁对象展开，移植时只补了 session_token，漏了其余字段合并。
- **影响**：未登录推荐流**下拉刷新**本应 `action=up / refresh_scene=1 / is_feed_first_request=0`，实际发出去仍是默认 `action=down / refresh_scene=0 / is_feed_first_request=1`，刷新拿不到新内容；翻页分页参数也无法透传。
- **修复**：把 `params` 每个可空字段按 `if (params.x !== undefined) merged.x = params.x` 逐个覆盖。
- **严重度**：高。

### A3〔中〕`appApi.ts:82-97` — buildZhihuAppMomentsUrl 完全不接收调用方入参
- **现象**：`merged` 只放默认值，函数末尾直接 `return buildApiUrl('/moments_v3', merged)`，`feed.ts:369` 传入的 `action`（刷新时应为 `up`）被丢弃；`offset / page_num / session_id / ad_index / ad_slot_position` 同样无法透传。
- **根因**：同 A2，未合并 `params`。
- **影响**：未登录「关注/moments」游客流下拉刷新恒为 `action=down`（首次加载无差异，刷新语义错）。
- **修复**：把 `params` 字段覆盖进 `merged`。
- **严重度**：中（当前唯一调用点只传 action，爆炸半径小于 A2）。

### A4〔中〕`question.ts:129` — 游客态 getQuestion 用错 include 常量
- **现象**：游客走设备态 `https://api.zhihu.com/questions/{id}`，HMOS 传 `include ?? QUESTION_INCLUDE`（web 长串 `detail,excerpt,answer_count,...`）；上游 `question.ts:65` 调 `buildZhihuAppQuestionUrl(id, include)`，其缺省值是 app 专属 `ZHIHU_APP_QUESTION_INCLUDE='read_count,query_info,voteup_count,voting,can_vote'`。
- **根因**：在 question.ts 内联复刻 `buildZhihuAppQuestionUrl` 时，把 web 的 `QUESTION_INCLUDE` 当成了 app 端点缺省 include。
- **修复**：guest 分支缺省改用 app 专属 include（与上游 `buildZhihuAppQuestionUrl` 默认参数一致）。
- **严重度**：中。

### A5〔中〕`httpClient.ts:580` — PATCH 被静默映射成 POST
- **现象**：`toMethod` 中 `case 'PATCH': return http.RequestMethod.POST;`。唯一调用点 `article.ts:82` `updateArticleDraft` 对 `https://zhuanlan.zhihu.com/api/articles/{id}/draft` 发的是 POST，而上游 `article.ts:62` 是 PATCH。
- **根因**：`@ohos.net.http.RequestMethod` 枚举无 PATCH，被降级映射。
- **修复**：确认所用 API 版本是否支持自定义 method 字符串；若不支持，需抓包验证 zhuanlan 是否接受 POST，否则「文章草稿保存/编辑」功能失效。
- **严重度**：中。

### A6〔中〕`member.ts:252-297` — getRecentMemberActivities 归一化丢失 target 字段
- **现象**：上游用 `{ ...activity, target: { ...target, id, type, created, relationship } }`；HMOS 重建 target 时只显式赋 `id / type / url / created / relationship`，`target.author / target.question / title / excerpt / content / image_url / voteup_count` 等全部丢失（接口虽声明 `author? / question?` 但未赋值，运行时为 undefined）。
- **根因**：禁展开运算符后只补了 id/type/created/relationship，漏了原 target 的其余字段。
- **修复**：归一化时保留原 target 再覆盖 `id/type/created/relationship`，或把 author/question/title/excerpt/content 等用到的字段逐一拷贝。
- **严重度**：中。

### A7〔低〕`questionFeed.ts:181-210` — normalizeZhihuAppQuestionFeeds 不做 `...target` 透传
- **现象**：上游 `answer = { ...target, id, type, ... }` 保留 app 卡片全部原始字段；HMOS 仅显式列出字段，`admin_closed_comment / is_normal / content_mark / reaction_relation / sticky_info` 等透传字段被丢弃。
- **修复**：若 UI 需要这些字段，补到 `AnswerDetail` 并在归一化时拷贝。
- **严重度**：低。

### A8〔低〕`answer.ts:179-192` — voteAnswer body 由 JSON 改成 form-urlencoded
- **现象**：上游 `post('/answers/{id}/voters', { type })`（axios 默认 JSON）；HMOS 发 `type=up`（`application/x-www-form-urlencoded`）。
- **说明**：知乎该端点实际兼容 form，可能是有意修正，但与上游契约不一致，建议抓包复核；`comment.ts`/`voters.ts` 的同类 vote 端点均无此问题。
- **严重度**：低。

### A9〔低〕`httpClient.ts:291-293 / 519-529` — 2xx 空 body 被当成错误
- **现象**：`status<400` 但响应体为空时，`parseJson` 抛 `ApiError('响应为空', status=0)`。DELETE / 部分 204 端点（如 deleteAnswer、unreactAnswerSegment 若返回空体会误报失败）。
- **修复**：2xx 且 body 为空时返回空对象 `{}`，不抛错。
- **严重度**：低。

### A10〔低〕`index.ts` — barrel 导出不完整
- **现象**：HMOS `index.ts` 只 re-export `search/member/following/topic/history/voters/image`；上游 `index.ts` 导出全部 24 个模块。`from './api'` 的消费方拿不到 answer/article/comment/...。
- **说明**：当前 UI 多按子路径直接 import（question.ts→answer.ts、feed.ts→appApi 等），无运行时影响；仅作对齐提示。
- **严重度**：低。

---

## B. 功能缺失（上游有、HMOS 缺）

| 上游文件 | 缺失导出 | HMOS 现状 | 建议 |
|---|---|---|---|
| `appApi.ts` | `buildZhihuAppQuestionUrl` | question.ts:74 内联复刻 | 回收进 appApi，并修掉 A4 的 include 默认值 |
| `appApi.ts` | `buildZhihuAppQuestionFeedsUrl` | question.ts:86 内联复刻 | 回收进 appApi，参数与上游 `{include, order, show_detail, ...}` 对齐 |
| `appApi.ts` | `buildZhihuAppRelatedObjectsUrl` | question.ts:104 内联复刻 | 回收进 appApi |
| `appApi.ts` | `buildZhihuAppMomentOriginUrl` | moments.ts:56 内联复刻 | 回收进 appApi |
| `appApi.ts` | 常量 `ZHIHU_APP_QUESTION_INCLUDE` / `ZHIHU_APP_QUESTION_FEEDS_INCLUDE` | question.ts:39-41 内联重复定义 | 与 appApi 统一来源（同时是 A4 的根因） |

> 说明：以上 4 个 builder 虽未导出，但 HMOS 在 question.ts/moments.ts 内联实现，运行时功能不缺；真正的问题是内联实现引入了 A4。其余 24 个模块导出函数清单与上游逐一对齐，无缺失。

---

## C. 已对齐 / 逐项确认（无需修复）

- **URL 绝对路径**：全量 grep `zhihuClient.(get|post|put|delete|patch)(' 以 `/` 开头 = 0 命中；所有请求均为 `https://www.zhihu.com/api/v4`、`https://zhuanlan.zhihu.com/api`、`https://api.zhihu.com`、`https://daily.zhihu.com` 完整 URL。✅
- **baseURL**：`httpClient.ts:22 ZHIHU_BASE=https://www.zhihu.com`；各模块 `API_V4=.../api/v4`、`ZHUANLAN_API_URL=.../api`、`ZHIHU_APP_API_BASE_URL=https://api.zhihu.com`、`IMAGE_API_URL=https://api.zhihu.com/images`、`DAILY_BASE=https://daily.zhihu.com` —— 域名与路径均正确。✅
- **签名注入逻辑（httpClient.buildHeaders）**：x-zse-96 / x-zse-93 / X-Udid / x-xsrftoken / Referer / x-requested-with 仅在 **cookie 非空且 d_c0 存在** 时注入；`zhuanlan.zhihu.com` 主机豁免签名（与上游一致）；oauth sign_in / token refresh 走 `rawRequest` 不经 buildHeaders，不会被错误签名；daily.ts 用独立 DailyClient，不带主站签名（与上游独立 axios 实例一致）。✅
- **逐文件对齐**：answer.ts（除 A8）、article.ts、chat.ts、collection.ts、column.ts、comment.ts、daily.ts、feed.ts(getFeed 主流程)、following.ts、history.ts、image.ts(getImage)、me.ts、moments.ts、notification.ts、pin.ts、publishing.ts、question.ts（除 A4）、questionFeed.ts、search.ts、topic.ts、voters.ts —— 请求 method、query 参数名、include 串、分页参数（offset/limit/after/page_num）均与上游一致。✅
- **zse96/**：`signRequest96 / ZSE_VERSION=101_3_3.0 / hmacSha1Hex / encryptZseV4` 与上游逐行对齐（仅 URL 解析改为纯字符串，等价）。✅

### 已知降级项（按要求不计为缺陷，仅确认）
- chat.ts：纯 HTTP（getInbox/getMessages/sendMessage），无 WebSocket 轮询，与上游一致。✅
- image.ts / publishing 图片：`uploadImage` 保留签名但直接抛「不支持上传」，OSS 链路未移植。✅
- daily.ts：正文经 `htmlToPlainText` 剥标签为纯文本。✅
