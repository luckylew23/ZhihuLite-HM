/**
 * components/interaction/CollectionRow —— 收藏夹选择列表中的一行。
 * 纯展示：文件夹图标 + 标题/描述 + 右侧勾选状态；点击整行上抛切换。
 */

import { ZhihuColors } from '../../utils/theme';

@Component
export struct CollectionRow {
  @Prop title: string = '';
  @Prop description: string = '';
  @Prop isPublic: boolean = true;
  @Prop isFavorited: boolean = false;
  @Prop pending: boolean = false;

  onToggle: (title: string) => void = (title: string): void => {};

  build() {
    Row({ space: 12 }) {
      Row() {
        Text(this.isPublic ? '📁' : '📂')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .borderRadius(12)
      .backgroundColor(ZhihuColors.backgroundTertiary)
      .justifyContent(FlexAlign.Center)

      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.pending) {
        LoadingProgress().width(20).height(20).color(ZhihuColors.primary)
      } else {
        Text(this.isFavorited ? '●' : '○')
          .fontSize(20)
          .fontColor(this.isFavorited ? ZhihuColors.primary : ZhihuColors.textTertiary)
      }
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .onClick(() => {
      this.onToggle(this.title);
    })
  }
}
