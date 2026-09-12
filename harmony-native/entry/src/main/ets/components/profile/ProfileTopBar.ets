/**
 * components/profile/ProfileTopBar —— 自绘顶部栏（← 返回 + 标题 + 可选右侧按钮）。
 */

import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../../utils/theme';

@Component
export struct ProfileTopBar {
  title: string = '';
  rightText: string = '';

  onRightClick: () => void = () => {};

  build() {
    Row({ space: 8 }) {
      Text('←')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(22)
        .fontColor(ZhihuColors.text)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .onClick(() => {
          router.back();
        })
      Text(this.title)
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ZhihuColors.text)
        .layoutWeight(1)
      if (this.rightText.length > 0) {
        Text(this.rightText)
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(16)
          .fontColor(ZhihuColors.primary)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .onClick(() => {
            this.onRightClick();
          })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 8, right: 8 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }
}
