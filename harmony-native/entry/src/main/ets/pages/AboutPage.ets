/**
 * pages/AboutPage —— 关于。
 * 内容：应用图标 + 名称 + 版本号 + 简介。
 * 上游: 原 FeedbackPage（意见反馈，功能不完整已移除）。
 */

import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../utils/theme';
import { APP_NAME, APP_VERSION, APP_DESC, APP_AUTHOR, APP_SOURCE, APP_HOMEPAGE } from '../utils/appInfo';

@Entry
@Component
struct AboutPage {
  @Builder
  topBar() {
    Row() {
      Text('‹')
        .fontSize(26)
        .fontColor(ZhihuColors.text)
        .width(40)
        .onClick(() => {
          router.back();
        })
      Blank()
      Text('关于')
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
      Blank()
      Text('   ')
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  build() {
    Column() {
      this.topBar()
      Scroll() {
        Column({ space: 12 }) {
          Image($r('app.media.app_icon'))
            .width(72)
            .height(72)
            .borderRadius(16)
            .margin({ top: 36 })

          Text(APP_NAME)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor(ZhihuColors.text)
            .margin({ top: 4 })

          Text('版本 ' + APP_VERSION)
            .fontSize(15)
            .fontColor(ZhihuColors.textTertiary)
            .margin({ top: 2 })

          Divider()
            .strokeWidth(0.5)
            .color(ZhihuColors.divider)
            .margin({ top: 24, bottom: 16 })

          Text(APP_DESC)
            .fontSize(16)
            .fontColor(ZhihuColors.textSecondary)
            .lineHeight(24)
            .width('100%')

          Text('作者：' + APP_AUTHOR)
            .fontSize(16)
            .fontColor(ZhihuColors.textSecondary)
            .width('100%')
            .margin({ top: 4 })

          Text('GitHub 主页：' + APP_HOMEPAGE)
            .fontSize(15)
            .fontColor(ZhihuColors.primary)
            .width('100%')
            .margin({ top: 2 })

          Text(APP_SOURCE)
            .fontSize(14)
            .fontColor(ZhihuColors.textTertiary)
            .width('100%')
            .margin({ top: 16 })

          Blank()
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 40 })
        .alignItems(HorizontalAlign.Center)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
