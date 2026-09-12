/**
 * pages/FeedbackPage —— 意见反馈。
 * 上游: ~/workbuddy/zhihu--/app/feedback/index.tsx
 * 状态: 静态 UI + 本地表单。没有可用的反馈提交接口，
 *       点击“提交”仅本地提示“已记录”，不会真正发送到服务端（未接真实接口）。
 */

import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../utils/theme';

@Entry
@Component
struct FeedbackPage {
  @State contact: string = '';
  @State content: string = '';
  @State submitting: boolean = false;
  @State submitted: boolean = false;
  @State error: string = '';

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (this.content.trim().length === 0) {
      this.error = '请填写反馈内容';
      return;
    }
    this.submitting = true;
    this.error = '';
    // 无真实反馈接口：模拟一次本地提交。
    try {
      await new Promise<void>((resolve) => {
        setTimeout(() => {
          resolve();
        }, 300);
      });
      this.submitted = true;
    } catch (e) {
      this.error = '提交失败，请稍后重试';
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  topBar() {
    Row() {
      Text('←')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(22)
        .fontColor(ZhihuColors.text)
        .width(40)
        .onClick(() => {
          router.back();
        })
      Blank()
      Text('反馈与建议')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
      Blank()
      Text('   ')
        .copyOption(CopyOptions.LocalDevice).fontSize(22).width(40)
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
        Column({ space: 14 }) {
          Text('遇到问题或有功能建议？填写下面的表单告诉我们。')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
            .width('100%')

          Column({ space: 10 }) {
            TextInput({ text: $$this.contact, placeholder: '联系方式（邮箱 / 手机号，可选）' })
              .width('100%')
              .height(48)
              .fontSize(14)
              .placeholderColor(ZhihuColors.textTertiary)
              .backgroundColor(ZhihuColors.backgroundSecondary)

            TextArea({ text: $$this.content, placeholder: '请描述你遇到的问题或建议…' })
              .width('100%')
              .height(200)
              .fontSize(14)
              .placeholderColor(ZhihuColors.textTertiary)
              .backgroundColor(ZhihuColors.backgroundSecondary)

            if (this.error.length > 0) {
              Text(this.error)
                .copyOption(CopyOptions.LocalDevice)
                .fontSize(13)
                .fontColor(ZhihuColors.danger)
                .width('100%')
            }

            if (this.submitted) {
              Text('已收到你的反馈（仅本地记录，未接入真实反馈通道）。')
                .copyOption(CopyOptions.LocalDevice)
                .fontSize(13)
                .fontColor(ZhihuColors.success)
                .width('100%')
            }

            if (this.submitting) {
              Row({ space: 8 }) {
                LoadingProgress().width(18).height(18).color(ZhihuColors.primary)
                Text('提交中…')
                  .copyOption(CopyOptions.LocalDevice).fontSize(14).fontColor(ZhihuColors.textSecondary)
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
            } else {
              Button('提交反馈')
                .width('100%')
                .height(44)
                .fontSize(15)
                .backgroundColor(ZhihuColors.primary)
                .onClick(() => {
                  this.submit();
                })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .borderRadius(12)

          Text('说明：当前版本未接入知乎反馈接口，提交不会发送到服务端。')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(12)
            .fontColor(ZhihuColors.textTertiary)
            .width('100%')
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
