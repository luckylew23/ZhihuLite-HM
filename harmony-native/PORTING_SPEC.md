# zhihu-- → HarmonyOS NEXT 原生移植规范（所有移植子代理必读）

本文件是所有移植工作的**唯一事实来源**。开工前先读完，并阅读下列已存在的基线文件，严格沿用其写法，不要自创风格。

## 0. 路径
- 上游 RN 源码（只读参考）：`~/workbuddy/zhihu--/`
  - 页面：`app/<route>.tsx`、`app/(tabs)/*.tsx`
  - API：`api/zhihu/<module>.ts`
  - 组件：`components/*.tsx`、`features/**`
  - store：`store/use*Store.ts`
- 目标工程（你写代码的地方）：`~/workbuddy/zhihu--HMOS/harmony-native/`
  - 源码根：`entry/src/main/ets/`
  - 页面放：`entry/src/main/ets/pages/`
  - 你专属的组件放：`entry/src/main/ets/components/<你的片名>/`（不要直接往 components/ 根堆文件，避免冲突）
  - API 模块放：`entry/src/main/ets/api/`

## 1. 已就绪、禁止改动的基础设施（直接 import 使用）
- `api/httpClient.ts`：导出 `zhihuClient`（单例）。方法：
  - `zhihuClient.get<T>(url, options?) : Promise<ApiResponse<T>>`
  - `zhihuClient.post<T>(url, options?)`，`options.data` 为 **raw string**（表单要自己 `encodeURIComponent` 拼好）
  - `ApiResponse<T> = { status, headers, data: T }`；非 2xx 抛 `ApiError`（`.status/.code/.body/.message`）
  - 已自动：Cookie Jar、签名头 x-zse-96/93/X-Udid/x-xsrftoken、游客 bootstrap、401 刷新。**你不要再管签名/cookie**。
  - 登录态判断：`import { authStore, hasAuthenticationCookie } from '../store/authStore'`；`authStore.isLoggedIn` / `authStore.cookies` / `authStore.userName`。
- `api/appApi.ts`：导出 `ZHIHU_APP_API_BASE_URL`、`getZhihuAppEndpointHeaders(url)`、各 `build*Url`。设备态端点（api.zhihu.com）需要这些头，调用时合并进 options.headers。
- `api/feed.ts` / `api/me.ts` / `api/feedParser.ts`：已移植，勿改。
- `model/zhihu.ts`：已有大量接口（ZhihuAnswer/ZhihuQuestion/ZhihuArticle/ZhihuPin/ZhihuTopic/ZhihuAuthor/ZhihuSearchResultItem 等）。**不要编辑本文件**；你需要的新接口定义在你自己的 api 模块文件里。
- `utils/theme.ts`：导出 `ZhihuColors`（primary=#0084ff 等），颜色一律用它，不要硬编码新色。
- `utils/date.ts`、`utils/url.ts`、`utils/zhihuError.ts`、`utils/feedIdentity.ts`：已存在，按需复用。

## 2. ArkTS 硬坑（务必遵守，否则编译失败）
1. **import 不带扩展名**：`import { x } from '../api/foo'`，不要写 `.ts`/`.ets`。
2. **无浏览器 URL 类**：需要解析 URL 时 `import { url } from '@kit.ArkTS'`，再 `new url.URL(...)`、`new url.URL(rel, base)`，用 `.searchParams.set(...)`。
3. **禁止对象展开/数组展开**（`{...a}`、`[...a]`）。合并对象用显式逐字段赋值或 `Object.assign`；合并数组用 `push` 循环。
4. **`@State` 变量名不能叫 `id`**（与组件内置属性冲突），改名如 `@State itemId`。
5. **类型严格**：`Record<string, object>` 取值后要显式 `as X` 转型；不能隐式 any；可选链 `?.` 可用但空值要兜底。
6. **字符串正则**可用 `str.match(/.../)`，返回 `RegExpMatchArray | null`，判空后取 `[1]`。
7. **打开外部链接**：不要用 openLink。需要时用 `common.UIAbilityContext` + `startAbility`（Want action `ohos.want.action.viewData` + entity `ohos.want.entity.browsable`）。多数详情页是应用内页，直接 router 跳转即可。
8. **router 导航**：`import { router } from '@kit.ArkUI'`；跳转 `router.pushUrl({ url: 'pages/XxxPage', params: {...} })`；目标页 `const p = router.getParams() as Record<string, object>` 后逐字段 `as string` 取出。返回 `router.back()`。
9. 列表用 `List`/`ForEach`；`ForEach` 第二参 key 必须稳定唯一。
10. 网络图片用 `Image(url)`；头像圆角用 `.borderRadius()`。

## 3. 页面编写约定
- 每个页面一个 `@Entry @Component struct XxxPage` 文件，放 `pages/`。
- **未登录态引导**：进入需要登录的页面时，先 `if (!authStore.isLoggedIn)` 显示"请先登录"占位 + 按钮跳 `pages/LoginPage`，不要直接发请求后崩溃。
- 加载态：`@State loading: boolean`，加载中显示 `Loading` 或 `Row(){LoadingProgress()}`。
- 错误态：catch `ApiError`，显示 `err.message` + 重试按钮。
- 空态：友好文案。
- 下拉刷新/加载更多：用 `List` 的 `onReachEnd` 触底加载下一页（上游用 cursor/offset 分页，照搬）。
- 富文本正文（回答/文章 HTML）：**降级为纯文本渲染**——用正则剥掉 `<[^>]+>` 标签、解码 `&nbsp;` 等实体即可，不要引入 WebView/LaTeX 渲染器。图片占位可保留为"[图片]"。这是明确允许的降级。
- 顶部导航栏：页面内自绘 `Row`（返回箭头 `←` + 标题），不要依赖系统标题栏。

## 4. 你**不得**做的事
- 不要编辑 `main_pages.json`（集成阶段统一注册）。
- 不要编辑 `httpClient.ts / authStore.ts / zse96/ / feedParser.ts / appApi.ts / feed.ts / me.ts / model/zhihu.ts / utils/theme.ts / EntryAbility.ets / module.json5`。
- 不要编辑别人负责的文件。各片文件归属见派发任务书，严格遵守。
- 不要假装真机验证过：无 hdc 设备。纯逻辑可用 `node --experimental-strip-types` 在 /tmp 副本对拍（import 需加 `.ts` 扩展名）；API 可用真实请求冒烟（游客态即可）。在汇报里如实写"验证了什么/没验证什么"。
- 不要改版本号、不要动已交付的 `zhihu--hmos-native-1.0.0-signed.hap`。

## 5. 自检与汇报
- 写完后，至少保证**你新增的文件自身语法自洽**（import 路径正确、无展开运算符、类型显式）。
- 汇报必须包含：①新建/修改的文件绝对路径清单；②每个文件对应上游哪个源文件；③你做了哪些降级及原因；④你如何验证的（node 对拍/真实请求/仅静态阅读）；⑤遗留问题。
