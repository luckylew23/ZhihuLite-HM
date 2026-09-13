/**
 * components/interaction/CommentRow —— 单条评论行（一级评论 / 二级回复复用）。
 * 纯展示组件：点赞状态、回复、展开子评论通过回调上抛，状态由父页持有。
 * 富文本 content 按 spec 降级为纯文本（见 textUtil.stripHtml）。
 */

import { CommentItem } from '../../api/comment';
import { ZhihuColors } from '../../utils/theme';
import { formatRelativeTime } from '../../utils/date';
import { stripHtml } from './textUtil';

@Component
export struct CommentRow {
  @Prop item: CommentItem = {
    id: '',
    type: '',
    content: '',
    created_time: 0,
    child_comment_count: 0,
    child_comments: [],
    author: { member: { id: '', url_token: '', name: '', avatar_url: '' } },
  } as CommentItem;
  @Prop isChild: boolean = false;
  @Prop childExpanded: boolean = false;

  onLike: (item: CommentItem) => void = (item: CommentItem): void => {};
  onReply: (item: CommentItem) => void = (item: CommentItem): void => {};
  onExpand: (item: CommentItem) => void = (item: CommentItem): void => {};

  private memberName(): string {
    const m = this.item.author === undefined ? undefined : this.item.author.member;
    if (m === undefined || m === null) {
      return '匿名用户';
    }
    return m.name.length > 0 ? m.name : '匿名用户';
  }

  private avatarUrl(): string {
    const m = this.item.author === undefined ? undefined : this.item.author.member;
    if (m === undefined || m === null) {
      return '';
    }
    return m.avatar_url;
  }

  private liked(): boolean {
    const rel = this.item.relationship;
    return rel !== undefined && rel !== null && rel.voting === 1;
  }

  private likeCount(): number {
    const vc = this.item.vote_count;
    return vc === undefined ? 0 : vc;
  }

  private metaText(): string {
    const parts: string[] = [];
    if (this.item.created_time > 0) {
      parts.push(formatRelativeTime(this.item.created_time));
    }
    const addr = this.item.address_text;
    if (addr !== undefined && addr !== null && addr.length > 0) {
      parts.push(addr);
    }
    return parts.join(' · ');
  }

  build() {
    Row({ space: 10 }) {
      Image(this.avatarUrl())
        .width(this.isChild ? 22 : 34)
        .height(this.isChild ? 22 : 34)
        .borderRadius(this.isChild ? 11 : 17)
        .objectFit(ImageFit.Cover)
        .backgroundColor(ZhihuColors.backgroundTertiary)

      Column({ space: 4 }) {
        Text(this.memberName())
          .fontSize(15)
          .fontColor(ZhihuColors.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(stripHtml(this.item.content))
          .fontSize(17)
          .fontColor(ZhihuColors.text)
          .width('100%')
          .textAlign(TextAlign.Start)
          .lineHeight(22)

        Row({ space: 16 }) {
          if (this.metaText().length > 0) {
            Text(this.metaText())
              .fontSize(14)
              .fontColor(ZhihuColors.textTertiary)
              .layoutWeight(1)
          } else {
            Blank().layoutWeight(1)
          }

          Row({ space: 3 }) {
            Text(this.liked() ? '♥' : '♡')
              .fontSize(15)
              .fontColor(this.liked() ? ZhihuColors.primary : ZhihuColors.textTertiary)
            Text(String(this.likeCount()))
              .fontSize(14)
              .fontColor(ZhihuColors.textTertiary)
          }
          .onClick(() => {
            this.onLike(this.item);
          })

          if (!this.isChild) {
            Text('回复')
              .fontSize(14)
              .fontColor(ZhihuColors.textTertiary)
              .onClick(() => {
                this.onReply(this.item);
              })
          }
        }
        .width('100%')

        if (!this.isChild && this.item.child_comment_count > 0) {
          Text(this.childExpanded ? '收起回复' : '查看全部 ' + this.item.child_comment_count + ' 条回复')
            .fontSize(14)
            .fontColor(ZhihuColors.primary)
            .padding({ top: 6 })
            .onClick(() => {
              this.onExpand(this.item);
            })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding({ top: 12, bottom: 12 })
  }
}
