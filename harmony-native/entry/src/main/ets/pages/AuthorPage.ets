/**
 * pages/AuthorPage —— 作者主页（简易版）
 * 展示作者基本信息，占位页面。
 */
import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../utils/theme';

@Entry
@Component
struct AuthorPage {
  @State authorId: string = '';
  @State authorName: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    this.authorId = params?.id ?? '';
    this.authorName = params?.name ?? '作者';
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(ZhihuColors.primary)
          .width(40)
          .onClick(() => router.back())
        Text(this.authorName)
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.text)
      }
      .width('100%')
      .height(52)
      .padding({ left: 12, right: 16 })
      .backgroundColor(ZhihuColors.backgroundSecondary)
      .alignItems(VerticalAlign.Center)

      Column({ space: 12 }) {
        Circle({ width: 60, height: 60 })
          .fill(ZhihuColors.backgroundTertiary)
        Text(this.authorName)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
        Text(`作者 ID: ${this.authorId}`)
          .fontSize(14)
          .fontColor(ZhihuColors.textTertiary)
      }
      .width('100%')
      .padding({ top: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
