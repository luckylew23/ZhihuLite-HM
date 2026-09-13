/**
 * components/FeedCard —— 普通 Feed 卡片（回答/文章/想法/问题）。
 */

import { FeedItem } from '../api/feed';
import { ZhihuColors } from '../utils/theme';

function formatCount(count: number): string {
  if (count >= 100000000) {
    return (count / 100000000).toFixed(1) + '亿';
  }
  if (count >= 10000) {
    return (count / 10000).toFixed(1) + '万';
  }
  return String(count);
}

@Component
export struct FeedCard {
  @Prop item: FeedItem = {
    id: '',
    type: 'answers',
    title: '',
    excerpt: '',
    author: { id: '', name: '', avatar: '' },
    image: null,
    voteCount: 0,
    commentCount: 0,
    voted: 0,
  } as FeedItem;

  build() {
    Column({ space: 6 }) {
      // 作者行
      Row({ space: 8 }) {
        Image(this.item.author.avatar)
          .width(36)
          .height(36)
          .borderRadius(18)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
        Column({ space: 2 }) {
          Text(this.item.author.name)
            .fontSize(15)
            .fontColor(ZhihuColors.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.item.actionText && this.item.actionText.length > 0) {
            Text(this.item.actionText)
              .fontSize(13)
              .fontColor(ZhihuColors.textTertiary)
              .maxLines(1)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.item.isLabeled) {
          Text('广告')
            .fontSize(10)
            .fontColor(ZhihuColors.textTertiary)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .border({ width: 0.5, color: ZhihuColors.border })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 标题
      if (this.item.title.length > 0) {
        Text(this.item.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
      }

      // 摘要
      if (this.item.excerpt.length > 0) {
        Text(this.item.excerpt)
          .fontSize(15)
          .fontColor(ZhihuColors.textSecondary)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
          .lineHeight(21)
      }

      // 配图
      if (this.item.image && this.item.image.length > 0) {
        Image(this.item.image)
          .width('100%')
          .height(180)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
      }

      // 统计行
      Row({ space: 16 }) {
        Row({ space: 4 }) {
          Text('▲')
            .fontSize(13).fontColor(ZhihuColors.textTertiary)
          Text(formatCount(this.item.voteCount))
            .fontSize(14).fontColor(ZhihuColors.textSecondary)
        }
        Row({ space: 4 }) {
          Text('评论')
            .fontSize(13).fontColor(ZhihuColors.textTertiary)
          Text(formatCount(this.item.commentCount))
            .fontSize(14).fontColor(ZhihuColors.textSecondary)
        }
        if (this.item.favlistsCount && this.item.favlistsCount > 0) {
          Text(formatCount(this.item.favlistsCount) + ' 收藏')
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
        }
        Blank()
        if (this.item.answerType === 'PAID') {
          Text('盐选')
            .fontSize(10)
            .fontColor(ZhihuColors.textInverse)
            .backgroundColor(ZhihuColors.primary)
            .borderRadius(4)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }
}
