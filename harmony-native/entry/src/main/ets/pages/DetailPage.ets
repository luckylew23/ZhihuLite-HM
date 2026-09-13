/**
 * pages/DetailPage —— 内容详情（v1.0：标题 + 摘要 + 原网页）。
 * 后续版本：移植 api/zhihu/question|answer|article 原生详情渲染。
 */

import { router } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { ZhihuColors } from '../utils/theme';

@Entry
@Component
struct DetailPage {
  @State contentId: string = '';
  @State contentType: string = '';
  @State title: string = '';
  @State excerpt: string = '';
  @State url: string = '';
  @State questionId: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    if (p) {
      this.contentId = String(p['id'] ?? '');
      this.contentType = String(p['type'] ?? '');
      this.title = String(p['title'] ?? '');
      this.excerpt = String(p['excerpt'] ?? '');
      this.url = String(p['url'] ?? '');
      this.questionId = String(p['questionId'] ?? '');
    }
  }

  private targetUrl(): string {
    if (this.url && this.url.length > 0) {
      return this.url;
    }
    if (this.contentType === 'question') {
      const qid = this.questionId.length > 0 ? this.questionId : this.contentId;
      return 'https://www.zhihu.com/question/' + qid;
    }
    if (this.contentType === 'article') {
      return 'https://zhuanlan.zhihu.com/p/' + this.contentId;
    }
    if (this.contentType === 'pin') {
      return 'https://www.zhihu.com/pin/' + this.contentId;
    }
    return 'https://www.zhihu.com/answer/' + this.contentId;
  }

  private openInBrowser(): void {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: this.targetUrl(),
      };
      context.startAbility(want);
    } catch (e) {
      // ignore
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(24)
          .fontColor(ZhihuColors.text)
          .padding({ left: 4, right: 8 })
          .onClick(() => {
            router.back();
          })
        Text('详情')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: 12, right: 12 })
      .backgroundColor(ZhihuColors.backgroundSecondary)

      Scroll() {
        Column({ space: 12 }) {
          if (this.title.length > 0) {
            Text(this.title)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(ZhihuColors.text)
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          if (this.excerpt.length > 0) {
            Text(this.excerpt)
          .copyOption(CopyOptions.LocalDevice)
              .fontSize(16)
              .fontColor(ZhihuColors.textSecondary)
              .width('100%')
              .textAlign(TextAlign.Start)
              .lineHeight(24)
          }

          Button('在浏览器打开原文')
            .width('100%')
            .height(44)
            .fontSize(16)
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.openInBrowser();
            })

          Text('完整详情（回答/文章正文、评论、赞同）将在下一版本接入')
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
            .width('100%')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
