/**
 * components/detail/AnswerCard —— 问题回答列表里的单条回答卡片。
 *  - 作者行 + 纯文本摘要（点摘要进 AnswerDetailPage 看全文）
 *  - 赞同(乐观) / 评论(跳 CommentsPage) / 收藏(跳 CollectionPickerPage)
 * 富文本正文按 spec 降级：只渲染剥标签后的纯文本摘要，不做 WebView。
 */

import { router } from '@kit.ArkUI';
import { AnswerDetail, voteAnswer } from '../../api/answer';
import { ZhihuColors } from '../../utils/theme';
import { formatCount, guardLogin, stripHtml } from './detailUtils';

@Component
export struct AnswerCard {
  @Prop item: AnswerDetail = {
    id: '',
    author: { id: '', name: '', avatar_url: '', type: '' },
    content: '',
    excerpt: '',
    created_time: 0,
    voteup_count: 0,
    comment_count: 0,
  } as AnswerDetail;
  @State voted: number = 0;
  @State voteCount: number = 0;
  private summary: string = '';

  aboutToAppear(): void {
    this.voted = this.item.relationship?.voting ?? 0;
    this.voteCount = this.item.voteup_count ?? 0;
    const fromExcerpt: string = stripHtml(this.item.excerpt);
    this.summary = fromExcerpt.length > 0 ? fromExcerpt : stripHtml(this.item.content);
  }

  private openAnswer(): void {
    router.pushUrl({
      url: 'pages/AnswerDetailPage',
      params: { id: String(this.item.id) },
    });
  }

  private onVote(): void {
    if (!guardLogin()) {
      return;
    }
    const prev: number = this.voted;
    const prevCount: number = this.voteCount;
    const next: number = prev === 1 ? 0 : 1;
    this.voted = next;
    this.voteCount = next === 1 ? prevCount + 1 : Math.max(0, prevCount - 1);
    voteAnswer(String(this.item.id), next === 1 ? 'up' : 'neutral')
      .catch(() => {
        this.voted = prev;
        this.voteCount = prevCount;
      });
  }

  private onComment(): void {
    router.pushUrl({
      url: 'pages/CommentsPage',
      params: { resourceType: 'answers', resourceId: String(this.item.id) },
    });
  }

  private onCollect(): void {
    if (!guardLogin()) {
      return;
    }
    router.pushUrl({
      url: 'pages/CollectionPickerPage',
      params: { resourceType: 'answer', resourceId: String(this.item.id) },
    });
  }

  build() {
    Column({ space: 10 }) {
      // 作者行
      Row({ space: 8 }) {
        Image(this.item.author.avatar_url)
          .width(34)
          .height(34)
          .borderRadius(17)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
        Column({ space: 2 }) {
          Text(this.item.author.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(ZhihuColors.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.item.author.headline && this.item.author.headline.length > 0) {
            Text(this.item.author.headline)
              .fontSize(14)
              .fontColor(ZhihuColors.textTertiary)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 摘要（点进去看全文）
      if (this.summary.length > 0) {
        Text(this.summary)
          .fontSize(17)
          .fontColor(ZhihuColors.text)
          .lineHeight(23)
          .maxLines(6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
          .onClick(() => {
            this.openAnswer();
          })
      }

      // 操作条
      Row({ space: 20 }) {
        Row({ space: 4 }) {
          Text('▲')
            .fontSize(14)
            .fontColor(this.voted === 1 ? ZhihuColors.primary : ZhihuColors.textTertiary)
          Text(formatCount(this.voteCount))
            .fontSize(15)
            .fontColor(this.voted === 1 ? ZhihuColors.primary : ZhihuColors.textSecondary)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .onClick(() => {
          this.onVote();
        })

        Row({ space: 4 }) {
          Text('💬')
          Text(formatCount(this.item.comment_count))
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .onClick(() => {
          this.onComment();
        })

        Row({ space: 4 }) {
          Text('★')
          Text('收藏')
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .onClick(() => {
          this.onCollect();
        })
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
