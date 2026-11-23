/**
 * pages/PublishQuestionPage —— 提问题（原生表单，直接调用知乎 API）。
 *
 * 历史：/api/v4/content/publish 曾对第三方客户端返回 4000「invalid character 'b'」，
 * 当时改为 WebView 官方页。后续发现文章发布走同一接口可成功（HTTP 200），
 * 根因是请求缺少 web 端必带的 extra_info.publisher=pc / pc_business_params；
 * 补齐后问题发布同样可用。本页恢复为原生表单（直接弹表单，不再绕 WebView）。
 *
 * 兜底：若服务端仍拒绝，错误区提供「改用网页版发布」入口（PublishQuestionWebPage）。
 */

import { router } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
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
    // 知乎服务端要求问题标题至少 10 字（过短返回"问题标题过短"），本地先校验
    return this.title.trim().length >= 10 && !this.submitting;
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
      const result = await createQuestion(t, toParagraphHtml(this.content));
      clearPublishDraft(getContext(this), 'question');
      const id: string = result.id !== undefined ? String(result.id) : '';
      if (id.length > 0) {
        router.replaceUrl({ url: 'pages/QuestionDetailPage', params: { id: id } });
      } else {
        router.back();
      }
    } catch (e) {
      // 直调 API 已被知乎 4000 风控拦截（返回 200 + {"code":4000,...} 伪装业务错误，
      // 与 payload 无关）。不再让用户重试 API——直接带草稿转 WebView 官方提问弹窗，
      // 官方页环境指纹合法，发布可成功。
      hilog.warn(0x0002, 'ZhihuHttp', 'question api publish failed, fallback to webview: %{public}s',
        JSON.stringify(e as object));
      router.replaceUrl({
        url: 'pages/PublishQuestionWebPage',
        params: { title: t, detail: this.content.trim() },
      });
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
        TextInput({ text: this.title, placeholder: '问题标题（10 字以上，建议以问号结尾）' })
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
