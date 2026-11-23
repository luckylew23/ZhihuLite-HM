/**
 * components/detail/AnswerActionBar —— 回答卡片内联操作条（轻量版）
 * 与 DetailActionBar 风格一致，但适配卡片场景：无保存按钮、收藏带文字。
 * 样式基准与 DetailActionBar 统一：图标 fontSize 15、数字 fontSize 13，
 * 赞同态图标+数字 primary、反对态 danger、收藏态 warning。
 * 使用普通成员变量（不使用 @Prop/@State），避免在列表项中触发 ArkTS 编译限制。
 */
import { ZhihuColors } from '../../utils/theme';
import { formatCount } from './detailUtils';

@Component
export struct AnswerActionBar {
  @Prop voted: number = 0;        // 0=未投, 1=赞成, -1=反对
  @Prop voteCount: number = 0;
  @Prop commentCount: number = 0;
  @Prop collected: boolean = false;
  onVote: () => void = () => {};
  onDisagree: () => void = () => {};
  onComment: () => void = () => {};
  onCollect: () => void = () => {};

  build() {
    Row({ space: 20 }) {
      // 赞成
      Row({ space: 3 }) {
        Text(this.voted === 1 ? '▲' : '△')
          .fontSize(15)
          .fontColor(this.voted === 1 ? ZhihuColors.primary : ZhihuColors.textTertiary)
        Text(formatCount(this.voteCount))
          .fontSize(13)
          .fontColor(this.voted === 1 ? ZhihuColors.primary : ZhihuColors.textSecondary)
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .onClick(() => {
        this.onVote();
      })

      // 反对
      Row({ space: 3 }) {
        Text(this.voted === -1 ? '▼' : '▽')
          .fontSize(15)
          .fontColor(this.voted === -1 ? ZhihuColors.danger : ZhihuColors.textTertiary)
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .onClick(() => {
        this.onDisagree();
      })

      // 评论
      Row({ space: 3 }) {
        Text('○')
          .fontSize(15)
          .fontColor(ZhihuColors.textTertiary)
        Text(formatCount(this.commentCount))
          .fontSize(13)
          .fontColor(ZhihuColors.textSecondary)
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .onClick(() => {
        this.onComment();
      })

      // 收藏
      Row({ space: 3 }) {
        Text(this.collected ? '★' : '☆')
          .fontSize(15)
          .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textTertiary)
        Text(this.collected ? '已收藏' : '收藏')
          .fontSize(13)
          .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textSecondary)
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .onClick(() => {
        this.onCollect();
      })
    }
    .width('100%')
  }
}
