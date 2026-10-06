/**
 * components/detail/DetailActionBar —— 详情页底部操作栏（公共组件）
 * 五项极简线条图标：赞成 △/▲ / 反对 ▽/▼ / 评论 ○ / 收藏 ☆/★ / 保存 ⬇
 * 所有图标、数字统一字号，颜色随深浅主题自适应。
 */
import { ZhihuColors } from '../../utils/theme';
import { formatCount } from './detailUtils';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';

@Component
export struct DetailActionBar {
  @Prop upvoted: boolean = false;
  @Prop downvoted: boolean = false;
  @Prop upvoteCount: number = 0;
  @Prop commentCount: number = 0;
  @Prop collected: boolean = false;
  @Prop showDownvote: boolean = true;
  @Prop showCollect: boolean = true;
  @Prop showShare: boolean = true;
  @Prop shareLink: string = '';
  @Prop shareTitle: string = '';
  onUpvote: () => void = () => {};
  onDownvote: () => void = () => {};
  onComment: () => void = () => {};
  onCollect: () => void = () => {};
  onSave: () => void = () => {};
  onShare: () => void = () => {};

  private share(): void {
    if (this.shareLink.length > 0) {
      const pb = pasteboard.getSystemPasteboard();
      const text: string = this.shareTitle.length > 0 ? this.shareTitle + '\n' + this.shareLink : this.shareLink;
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pb.setData(data).then(() => {
        promptAction.showToast({ message: '链接已复制，快去分享吧', duration: 1500 });
      }).catch(() => {
        promptAction.showToast({ message: '复制失败', duration: 1500 });
      });
    } else {
      this.onShare();
    }
  }

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
      .padding({ top: 10, bottom: 10 })
      .onClick(() => this.onUpvote())

      // 反对（可隐藏）
      if (this.showDownvote) {
        Row({ space: 3 }) {
          Text(this.downvoted ? '▼' : '▽')
            .fontSize(15)
            .fontColor(this.downvoted ? ZhihuColors.danger : ZhihuColors.textTertiary)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .onClick(() => this.onDownvote())
      }

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
      .padding({ top: 10, bottom: 10 })
      .onClick(() => this.onComment())

      // 收藏（可隐藏）
      if (this.showCollect) {
        Row({ space: 3 }) {
          Text(this.collected ? '★' : '☆')
            .fontSize(15)
            .fontColor(this.collected ? ZhihuColors.primary : ZhihuColors.textTertiary)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .onClick(() => this.onCollect())
      }

      // 转发（可隐藏）
      if (this.showShare) {
        Row({ space: 3 }) {
          Text('↗')
            .fontSize(15)
            .fontColor(ZhihuColors.textTertiary)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .onClick(() => this.share())
      }

      // 保存
      Row({ space: 3 }) {
        Text('⇩')
          .fontSize(15)
          .fontColor(ZhihuColors.textTertiary)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 10, bottom: 10 })
      .onClick(() => this.onSave())
    }
    .width('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .border({ width: { top: 0.5 }, color: ZhihuColors.border })
  }
}
