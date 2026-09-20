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
    // 有原生详情页的类型直接跳转，不再停留占位页
    const t = this.contentType;
    if ((t === 'article' || t === 'articles') && this.contentId.length > 0) {
      router.replaceUrl({ url: 'pages/ArticleDetailPage', params: { id: this.contentId } });
      return;
    }
    if ((t === 'answer' || t === 'answers') && this.contentId.length > 0) {
      router.replaceUrl({ url: 'pages/AnswerDetailPage', params: { id: this.contentId, questionId: this.questionId } });
      return;
    }
    if ((t === 'question' || t === 'questions') && this.contentId.length > 0) {
      router.replaceUrl({ url: 'pages/QuestionDetailPage', params: { id: this.contentId } });
      return;
    }
    if ((t === 'pin' || t === 'pins') && this.contentId.length > 0) {
      router.replaceUrl({ url: 'pages/PinDetailPage', params: { id: this.contentId } });
      return;
    }
  }

  private targetUrl(): string {
    if (this.url && this.url.length > 0) {
      return this.url;
    }
    const qid = this.questionId.length > 0 ? this.questionId : this.contentId;
    if (this.contentType === 'question') {
      return 'https://www.zhihu.com/question/' + qid;
    }
    // 调用方（SearchPage/FeedListPage）传复数类型，统一兼容
    if (this.contentType === 'article' || this.contentType === 'articles') {
      return 'https://zhuanlan.zhihu.com/p/' + this.contentId;
    }
    if (this.contentType === 'pin' || this.contentType === 'pins') {
      return 'https://www.zhihu.com/pin/' + this.contentId;
    }
    if (this.contentType === 'video' || this.contentType === 'videos') {
      return 'https://www.zhihu.com/zvideo/' + this.contentId;
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
          .fontSize(18)
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
              .fontSize(17)
              .fontColor(ZhihuColors.textSecondary)
              .width('100%')
              .textAlign(TextAlign.Start)
              .lineHeight(24)
          }

          Button('在浏览器打开原文')
            .width('100%')
            .height(44)
            .fontSize(17)
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.openInBrowser();
            })

          Text('完整详情（回答/文章正文、评论、赞同）将在下一版本接入')
            .fontSize(14)
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
