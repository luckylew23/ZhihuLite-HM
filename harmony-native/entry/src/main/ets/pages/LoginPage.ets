/**
 * pages/LoginPage —— 知乎 Web 登录。
 * 登录完成后从 WebCookieManager 抓取整域 Cookie（含 HttpOnly 的 z_c0），
 * 导入 zhihuClient 的 Cookie Jar 并持久化。
 */

import { webview } from '@kit.ArkWeb';
import { router } from '@kit.ArkUI';
import { zhihuClient } from '../api/httpClient';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';

const SIGNIN_URL: string = 'https://www.zhihu.com/signin';

@Entry
@Component
struct LoginPage {
  controller: webview.WebviewController = new webview.WebviewController();
  @State loading: boolean = true;
  @State logined: boolean = false;

  build() {
    Column() {
      Row() {
        Text('取消')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(16)
          .fontColor(ZhihuColors.primary)
          .onClick(() => {
            router.back();
          })
        Blank()
        Text('知乎登录')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
        Blank()
        Text('   ')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(16)
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .backgroundColor(ZhihuColors.backgroundSecondary)

      Stack() {
        Web({ src: SIGNIN_URL, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .databaseAccess(true)
          .fileAccess(true)
          .imageAccess(true)
          .onlineImageAccess(true)
          .mixedMode(MixedMode.All)
          .cacheMode(CacheMode.Default)
          .onPageBegin(() => {
            this.loading = true;
          })
          .onPageEnd(() => {
            this.loading = false;
            this.tryGrabCookies();
          })
          .onErrorReceive((event) => {
            this.loading = false;
          })

        if (this.loading && !this.logined) {
          LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
        }

        if (this.logined) {
          Column({ space: 16 }) {
            Text('登录成功')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(17)
              .fontColor(ZhihuColors.text)
            Button('返回')
              .width(160)
              .height(40)
              .backgroundColor(ZhihuColors.primary)
              .onClick(() => {
                router.back();
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#f0ffffff')
        }
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(ZhihuColors.backgroundSecondary)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  private async tryGrabCookies(): Promise<void> {
    try {
      // WebCookieManager 覆盖 HttpOnly cookie（z_c0 等），document.cookie 不含
      const cookie = await webview.WebCookieManager.getCookie('https://www.zhihu.com');
      if (typeof cookie === 'string' && cookie.length > 0) {
        zhihuClient.importCookies(cookie);
        if (authStore.isLoggedIn) {
          this.logined = true;
        }
      }
    } catch (e) {
      // 未登录完成时忽略
    }
  }
}
