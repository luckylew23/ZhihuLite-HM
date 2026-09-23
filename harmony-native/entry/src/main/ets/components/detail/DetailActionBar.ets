/**
 * components/detail/DetailActionBar —— 详情页底部操作栏（公共组件）
 * 五项极简线条图标：赞成 △/▲ / 反对 ▽/▼ / 评论 ○ / 收藏 ☆/★ / 保存 ⬇
 * 所有图标、数字统一字号，颜色随深浅主题自适应。
 */
import { ZhihuColors } from '../../utils/theme';
import { formatCount } from './detailUtils';

@Component
export struct DetailActionBar {
  @State upvoted: boolean = false;
  @State downvoted: boolean = false;
  @Prop upvoteCount: number = 0;
  @Prop commentCount: number = 0;
  @Prop collected: boolean = false;
  onUpvote: () => void = () => {};
  onDownvote: () => void = () => {};
  onComment: () => void = () => {};
  onCollect: () => void = () => {};
  onSave: () => void = () => {};

  build() {
    Row({ space: 2 }) {
      // 赞成
      Row({ space: 3 }) {
        Text(this.upvoted ? '▲' : '△')
          .fontSize(15)
          .fontColor(this.upvoted ? ZhihuColors.primary : ZhihuColors.textTertiary)
        Text(formatCount(this.upvoteCount))
          .fontSize(13)
          .fontColor(ZhihuColors.textSecondary)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ vertical: 10 })
      .onClick(() => this.onUpvote())

      // 反对
      Row({ space: 3 }) {
        Text(this.downvoted ? '▼' : '▽')
          .fontSize(15)
          .fontColor(this.downvoted ? ZhihuColors.danger : ZhihuColors.textTertiary)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ vertical: 10 })
      .onClick(() => this.onDownvote())

      // 评论
      Row({ space: 3 }) {
        Text('○')
          .fontSize(15)
          .fontColor(ZhihuColors.textTertiary)
        Text(formatCount(this.commentCount))
          .fontSize(13)
          .fontColor(ZhihuColors.textSecondary)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ vertical: 10 })
      .onClick(() => this.onComment())

      // 收藏
      Row({ space: 3 }) {
        Text(this.collected ? '★' : '☆')
          .fontSize(15)
          .fontColor(this.collected ? ZhihuColors.primary : ZhihuColors.textTertiary)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ vertical: 10 })
      .onClick(() => this.onCollect())

      // 保存
      Row({ space: 3 }) {
        Text('⇩')
          .fontSize(15)
          .fontColor(ZhihuColors.textTertiary)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ vertical: 10 })
      .onClick(() => this.onSave())
    }
    .width('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .border({ width: { top: 0.5 }, color: ZhihuColors.border })
  }
}
