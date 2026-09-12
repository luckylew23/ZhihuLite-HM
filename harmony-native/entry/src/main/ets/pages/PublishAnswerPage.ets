/**
 * pages/PublishAnswerPage —— 写回答。
 * 上游: ~/workbuddy/zhihu--/app/publish/answer.tsx
 * 说明: 上游首屏是“搜索问题/邀请回答”列表，且搜索/邀请接口（searchCreatorQuestions、
 *       getInvitedQuestions）未移植，因此按任务书简化为：问题 ID + 正文表单。
 *       可通过 router 参数 { questionId: '...' } 预填问题 ID。
 * 降级: 富文本编辑器未移植，正文为纯文本，按行序列化为 <p> 段落 HTML。
 */

import { router } from '@kit.ArkUI';
import { createAnswer } from '../api/answer';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { readStringParam } from '../components/detail/detailUtils';

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
struct PublishAnswerPage {
  @State questionId: string = '';
  @State content: string = '';
  @State submitting: boolean = false;
  @State error: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    const qid = readStringParam(p, 'questionId');
    if (qid.length > 0) {
      this.questionId = qid;
      return;
    }
    const id = readStringParam(p, 'id');
    if (id.length > 0) {
      this.questionId = id;
    }
  }

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    const qid: string = this.questionId.trim();
    const body: string = this.content.trim();
    if (qid.length === 0) {
      this.error = '请输入问题 ID（问题链接末尾的数字）';
      return;
    }
    if (body.length === 0) {
      this.error = '请输入回答内容';
      return;
    }
    this.submitting = true;
    this.error = '';
    try {
      await createAnswer(qid, toParagraphHtml(this.content), {});
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
      Text('写回答')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
      Blank()
      if (this.submitting) {
        LoadingProgress().width(20).height(20).color(ZhihuColors.primary)
      } else {
        Text('发布')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.primary)
          .onClick(() => {
            this.submit();
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
      Text('发布回答前请先登录知乎账号')
        .fontSize(14)
        .fontColor(ZhihuColors.textSecondary)
      Button('去登录')
        .width(200)
        .height(42)
        .fontSize(15)
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
        TextInput({ text: $$this.questionId, placeholder: '问题 ID（如 123456789）' })
          .width('100%')
          .height(52)
          .fontSize(16)
          .placeholderColor(ZhihuColors.textTertiary)
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .type(InputType.Number)
          .margin({ top: 8 })

        Divider().color(ZhihuColors.border)

        TextArea({ text: $$this.content, placeholder: '写下你的回答…' })
          .width('100%')
          .height(360)
          .fontSize(15)
          .placeholderColor(ZhihuColors.textTertiary)
          .backgroundColor(ZhihuColors.backgroundSecondary)

        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(13)
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
