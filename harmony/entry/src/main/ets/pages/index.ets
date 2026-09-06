// pages/index.ets —— ArkWeb 壳页面
// ----------------------------------------------------------------------------
// 加载 rawfile 下的**单文件内联** index.html（由 scripts/build-web.sh 生成）。
//
// 为什么必须单文件内联：
//   $rawfile 的文档源是 resource://rawfile/...。该 scheme 下 **ES module** 子资源
//   （<script type="module">、<link rel="modulepreload">）会被 CORS 拒绝，
//   分包的 .js / .css / 字体 / 图片也会因跨 scheme 取不到 → 只剩白屏。
//   所以构建脚本把 JS / CSS / 字体 / 图片全部内联进一个 index.html，
//   并把 module 脚本降级为普通 IIFE 脚本，完成后还会自检。
//
// 这里的 Web 配置与 Tydora-HMOS/Index.ets 保持一致（已验证可用）。
// ----------------------------------------------------------------------------
import { webview } from '@kit.ArkWeb';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'ZhihuWeb';

@Entry
@Component
struct Index {
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Web({ src: $rawfile('index.html'), controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .databaseAccess(true)
        .fileAccess(true)
        .imageAccess(true)
        .onlineImageAccess(true)
        .mixedMode(MixedMode.All)
        .cacheMode(CacheMode.Default)
        .zoomAccess(false)
        .darkMode(WebDarkMode.Auto)
        .onPageBegin(() => {
          hilog.info(DOMAIN, TAG, 'web page begin');
        })
        .onPageEnd(() => {
          hilog.info(DOMAIN, TAG, 'web page end');
        })
        .onErrorReceive((event) => {
          if (event && event.error && event.error.getErrorInfo()) {
            hilog.error(DOMAIN, TAG, 'web error: %{public}s', event.error.getErrorInfo());
          }
        })
        .onHttpErrorReceive((event) => {
          if (event && event.response) {
            hilog.error(DOMAIN, TAG, 'http error: %{public}s',
              JSON.stringify(event.response.getResponseCode()));
          }
        })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }

  // 返回键：优先让 Web 内部路由回退（expo-router 走 history，可 back），
  // 已在首页时才把事件交还系统（退出应用）。
  onBackPress(): boolean {
    if (this.controller.accessBackward()) {
      this.controller.backward();
      return true;
    }
    return false;
  }
}
