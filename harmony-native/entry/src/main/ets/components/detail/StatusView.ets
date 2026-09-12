/**
 * components/detail/StatusView —— 居中的加载 / 错误(重试) / 空态块。
 * 首屏或局部加载失败时使用。
 */

import { ZhihuColors } from '../../utils/theme';

@Component
export struct StatusView {
  @Prop loading: boolean = false;
  @Prop error: string = '';
  @Prop emptyText: string = '';
  onRetry: () => void = () => {
  };

  build() {
    if (this.loading) {
      Column({ space: 10 }) {
        LoadingProgress().width(40).height(40).color(ZhihuColors.primary)
        Text('加载中…')
          .copyOption(CopyOptions.LocalDevice).fontSize(14).fontColor(ZhihuColors.textTertiary)
      }
      .width('100%')
      .padding(40)
    } else if (this.error.length > 0) {
      Column({ space: 16 }) {
        Text(this.error)
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(15)
          .fontColor(ZhihuColors.textSecondary)
          .textAlign(TextAlign.Center)
        Button('重试')
          .fontSize(15)
          .backgroundColor(ZhihuColors.primary)
          .onClick(() => {
            this.onRetry();
          })
      }
      .width('100%')
      .padding(40)
    } else if (this.emptyText.length > 0) {
      Text(this.emptyText)
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(15)
        .fontColor(ZhihuColors.textTertiary)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding(40)
    }
  }
}
