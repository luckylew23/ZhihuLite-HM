/**
 * pages/PublishArticlePage —— 写文章。
 * 上游: ~/workbuddy/zhihu--/app/publish/article.tsx
 * 流程: 标题 + 正文。
 *   · 保存草稿: createArticleDraft(title) → updateArticleDraft(id, {title,content})
 *   · 发布:     同上后再 publishArticleDraft(id, {}, false)
 * 降级: 上游要求至少一个话题（topics），话题搜索/绑定接口虽已移植但未在本页接入，
 *       因此发布时不带话题（知乎可能要求补充话题，失败会回显错误）；
 *       富文本/图片未移植，正文按行序列化为 <p> 段落 HTML。
 */

import { router } from '@kit.ArkUI';
import {
  createArticleDraft,
  updateArticleDraft,
  publishArticleDraft,
} from '../api/article';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { getZhihuErrorMessage } from '../utils/zhihuError';

function toParagraphHtml(text: string): string {
  const trimmed = text.trim();
  if (trimmed.length === 0) {
    return '';
  }
  const lines: string[] = trimmed.split('\n');
  let html: string = '<p>';
  for (let i = 0; i < lines.length; i++) {
    if (i > 0) {
      html += '</p><p>';
    }
    html += lines[i];
  }
  html += '</p>';
  return html;
}

@Entry
@Component
struct PublishArticlePage {
  @State title: string = '';
  @State content: string = '';
  @State submitting: boolean = false;
  @State error: string = '';
  @State notice: string = '';
  private draftId: string = '';

  private async run(andPublish: boolean): Promise<void> {
    if (this.submitting) {
      return;
    }
    const t: string = this.title.trim();
    const body: string = this.content.trim();
    if (t.length === 0) {
      this.error = '请输入文章标题';
      return;
    }
    if (body.length === 0) {
      this.error = '请输入文章正文';
      return;
    }
    this.submitting = true;
    this.error = '';
    this.notice = '';
    try {
      let did: string = this.draftId;
      if (did.length === 0) {
        const draft = await createArticleDraft(t);
        did = String(draft.id);
        this.draftId = did;
      }
      await updateArticleDraft(did, {
        title: t,
        content: toParagraphHtml(this.content),
        delta_time: 0,
        can_reward: false,
      });
      if (andPublish) {
        await publishArticleDraft(did, {}, false);
        router.back();
      } else {
        this.notice = '草稿已保存';
      }
    } catch (e) {
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  topBar() {
    Row() {
      Text('←')
        .fontSize(22)
        .fontColor(ZhihuColors.text)
        .width(40)
        .onClick(() => {
          router.back();
        })
      Blank()
      Text('写文章')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
      Blank()
      if (this.submitting) {
        LoadingProgress().width(20).height(20).color(ZhihuColors.primary)
      } else {
        Row({ space: 14 }) {
          Text('存草稿')
            .fontSize(16)
            .fontColor(ZhihuColors.textSecondary)
            .onClick(() => {
              this.run(false);
            })
          Text('发布')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(ZhihuColors.primary)
            .onClick(() => {
              this.run(true);
            })
        }
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  loginPrompt() {
    Column({ space: 16 }) {
      Blank()
      Text('写文章前请先登录知乎账号')
        .fontSize(15)
        .fontColor(ZhihuColors.textSecondary)
      Button('去登录')
        .width(200)
        .height(42)
        .fontSize(16)
        .backgroundColor(ZhihuColors.primary)
        .onClick(() => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  form() {
    Scroll() {
      Column({ space: 12 }) {
        TextInput({ text: $$this.title, placeholder: '请输入标题' })
          .width('100%')
          .height(64)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .placeholderColor(ZhihuColors.textTertiary)
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .margin({ top: 8 })

        Divider().color(ZhihuColors.border)

        TextArea({ text: $$this.content, placeholder: '正文内容' })
          .width('100%')
          .height(400)
          .fontSize(16)
          .placeholderColor(ZhihuColors.textTertiary)
          .backgroundColor(ZhihuColors.backgroundSecondary)

        if (this.notice.length > 0) {
          Text(this.notice)
            .fontSize(14)
            .fontColor(ZhihuColors.success)
            .width('100%')
        }
        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(14)
            .fontColor(ZhihuColors.danger)
            .width('100%')
        }
      }
      .width('100%')
      .padding(16)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  build() {
    Column() {
      this.topBar()
      if (!authStore.isLoggedIn) {
        this.loginPrompt()
      } else {
        this.form()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
