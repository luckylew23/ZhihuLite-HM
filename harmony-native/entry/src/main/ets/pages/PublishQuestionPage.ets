/**
 * pages/PublishQuestionPage —— 提问题。
 * 上游: ~/workbuddy/zhihu--/app/publish/question.tsx
 * 降级: 上游 PublishingEditor（富文本/Markdown/图片上传）未移植，正文为纯文本，
 *       按行序列化为 <p> 段落 HTML 后提交；图片上传不可用。
 */

import { router } from '@kit.ArkUI';
import { createQuestion } from '../api/question';
import { authStore } from '../store/authStore';
import { ZhihuColors, isDarkNow } from '../utils/theme';
import { savePublishDraft, loadPublishDraft, clearPublishDraft } from '../utils/publishDraft';
import { getZhihuErrorMessage } from '../utils/zhihuError';

/** 纯文本 → 极简 HTML：每行一个 <p>。 */
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
struct PublishQuestionPage {
  @State title: string = '';
  @State content: string = '';
  @State submitting: boolean = false;
  @State error: string = '';
  @State draftNotice: string = '';

  private canPublish(): boolean {
    return this.title.trim().length > 5 && !this.submitting;
  }

  aboutToAppear(): void {
    const d = loadPublishDraft(getContext(this), 'question');
    if (d.title.length > 0 || d.content.length > 0) {
      this.title = d.title;
      this.content = d.content;
      this.draftNotice = '已恢复上次草稿';
    }
  }

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    const t: string = this.title.trim();
    if (t.length === 0) {
      this.error = '请输入问题标题';
      return;
    }
    this.submitting = true;
    this.error = '';
    try {
      await createQuestion(t, toParagraphHtml(this.content));
      clearPublishDraft(getContext(this), 'question');
      router.back();
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
      Text('提问题')
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
      Blank()
      if (this.submitting) {
        LoadingProgress().width(20).height(20).color(ZhihuColors.primary)
      } else {
        Text('发布')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.canPublish() ? ZhihuColors.primary : ZhihuColors.textTertiary)
          .onClick(() => {
            if (this.canPublish()) {
              this.submit();
            }
          })
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
      Text('发布内容前请先登录知乎账号')
        .fontSize(16)
        .fontColor(ZhihuColors.textSecondary)
      Button('去登录')
        .width(200)
        .height(42)
        .fontSize(17)
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
        TextInput({ text: this.title, placeholder: '输入问题并以问号结尾' })
          .onChange((v: string) => {
            this.title = v;
            savePublishDraft(getContext(this), 'question', this.title, this.content);
          })
          .width('100%')
          .height(56)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.text)
          .caretColor(ZhihuColors.primary)
          .placeholderColor(ZhihuColors.textTertiary)
          .backgroundColor(isDarkNow() ? '#3a3a44' : '#f5f6f7')
          .border({ width: 1, color: isDarkNow() ? '#4a4a55' : '#d8d9de' })
          .margin({ top: 8 })

        Divider().color(ZhihuColors.border)

        TextArea({ text: this.content, placeholder: '补充问题背景和细节（可选）' })
          .onChange((v: string) => {
            this.content = v;
            savePublishDraft(getContext(this), 'question', this.title, this.content);
          })
          .width('100%')
          .height(320)
          .fontSize(17)
          .fontColor(ZhihuColors.text)
          .caretColor(ZhihuColors.primary)
          .placeholderColor(ZhihuColors.textTertiary)
          .backgroundColor(isDarkNow() ? '#3a3a44' : '#f5f6f7')
          .border({ width: 1, color: isDarkNow() ? '#4a4a55' : '#d8d9de' })

        if (this.draftNotice.length > 0) {
          Text(this.draftNotice)
            .fontSize(15)
            .fontColor(ZhihuColors.primary)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(15)
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
