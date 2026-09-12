/**
 * components/HotCard —— 热榜卡片。
 */

import { HotItem } from '../api/feedParser';
import { ZhihuColors } from '../utils/theme';

function rankColor(rank: number): string {
  if (rank === 1) return ZhihuColors.hotRankFirst;
  if (rank === 2) return ZhihuColors.hotRankSecond;
  if (rank === 3) return ZhihuColors.hotRankThird;
  return ZhihuColors.textTertiary;
}

@Component
export struct HotCard {
  @Prop item: HotItem = {
    id: '',
    questionId: '',
    rank: 0,
    title: '',
    excerpt: '',
    image: null,
    hotValue: '',
    answerCount: 0,
    labelArea: null,
  } as HotItem;

  build() {
    Row({ space: 12 }) {
      // 排名
      Text(String(this.item.rank))
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(rankColor(this.item.rank))
        .width(32)
        .textAlign(TextAlign.Center)

      // 内容
      Column({ space: 6 }) {
        Row({ space: 6 }) {
          if (this.item.labelArea && this.item.labelArea.text) {
            Text(this.item.labelArea.text)
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(10)
              .fontColor(this.item.labelArea.normal_color ?? ZhihuColors.hotLabel)
              .border({ width: 0.5, color: this.item.labelArea.normal_color ?? ZhihuColors.hotLabel })
              .borderRadius(3)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          }
          Text(this.item.title)
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(ZhihuColors.text)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .textAlign(TextAlign.Start)
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')

        if (this.item.excerpt.length > 0) {
          Text(this.item.excerpt)
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .textAlign(TextAlign.Start)
        }

        Row({ space: 8 }) {
          if (this.item.hotValue.length > 0) {
            Text(this.item.hotValue)
              .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary)
          }
          if (this.item.answerCount > 0) {
            Text(String(this.item.answerCount) + ' 回答')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(13)
              .fontColor(ZhihuColors.textTertiary)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 配图
      if (this.item.image && this.item.image.length > 0) {
        Image(this.item.image)
          .width(96)
          .height(72)
          .borderRadius(6)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
  }
}
