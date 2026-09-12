/**
 * components/detail/DetailNavBar —— 详情族自绘顶部栏：左侧返回 + 中间标题。
 */

import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../../utils/theme';

@Component
export struct DetailNavBar {
  @Prop title: string = '';

  build() {
    Row() {
      Text('‹')
        .fontSize(30)
        .fontColor(ZhihuColors.text)
        .padding({ left: 6, right: 10 })
        .onClick(() => {
          router.back();
        })
      Text(this.title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Blank()
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 12 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }
}
