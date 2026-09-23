/**
 * components/detail/AnswerCard —— 问题回答列表里的单条回答卡片。
 *  - 作者行 + 纯文本摘要（点摘要进 AnswerDetailPage 看全文）
 *  - 赞同(乐观) / 评论(跳 CommentsPage) / 收藏(跳 CollectionPickerPage)
 * 富文本正文按 spec 降级：只渲染剥标签后的纯文本摘要，不做 WebView。
 */

import { router, promptAction } from '@kit.ArkUI';
import { AnswerDetail, voteAnswer } from '../../api/answer';
import { getAnswerCollectionStatus, removeFromCollection } from '../../api/collection';
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
  @State collected: boolean = false;
  @State collectionId: string = '';
  @StorageLink('collectPicked') @Watch('onCollectPicked') collectPicked: string = '';
  private summary: string = '';

  onCollectPicked(): void {
    if (this.collectPicked === String(this.item.id)) {
      this.collected = true;
      this.collectPicked = '';
    }
  }

  aboutToAppear(): void {
    this.voted = this.item.relationship?.voting ?? 0;
    this.voteCount = this.item.voteup_count ?? 0;
    const fromExcerpt: string = stripHtml(this.item.excerpt);
    this.summary = fromExcerpt.length > 0 ? fromExcerpt : stripHtml(this.item.content);
    this.refreshCollectionStatus();
  }

  /** 查询该回答是否已被收藏（对齐上游 collectedStatusMap） */
  private async refreshCollectionStatus(): Promise<void> {
    try {
      const st = await getAnswerCollectionStatus(String(this.item.id), 1);
      if (st.collected === true) {
        this.collected = true;
        const list = st.data ?? [];
        if (list.length > 0) {
          const first = list[0] as Record<string, object>;
          this.collectionId = String(first['id'] ?? '');
        }
      }
    } catch (e) {
      // 状态查询失败不阻塞页面，保持未收藏展示
    }
  }

  private openAnswer(): void {
    router.pushUrl({
      url: 'pages/AnswerDetailPage',
      params: { id: String(this.item.id) },
    });
  }

  private onDisagree(): void {
    if (!guardLogin()) {
      return;
    }
    const prev: number = this.voted;
    const next: number = prev === -1 ? 0 : -1;
    this.voted = next;
    voteAnswer(String(this.item.id), next === -1 ? 'down' : 'neutral')
      .catch(() => {
        this.voted = prev;
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

  private async onCollect(): Promise<void> {
    if (!guardLogin()) {
      return;
    }
    if (this.collected) {
      // 已收藏 → 直接取消收藏（对齐上游 toggleCollect）
      if (this.collectionId.length === 0) {
        await this.refreshCollectionStatus();
        if (this.collectionId.length === 0) {
          promptAction.showToast({ message: '无法获取收藏夹信息' });
          return;
        }
      }
      try {
        await removeFromCollection(this.collectionId, this.item.id);
        this.collected = false;
        this.collectionId = '';
        promptAction.showToast({ message: '已取消收藏' });
      } catch (e) {
        promptAction.showToast({ message: '取消收藏失败' });
      }
      return;
    }
    // 未收藏 → 选择收藏夹
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
          Text(this.voted === -1 ? '▼' : '▽')
            .fontSize(14)
            .fontColor(this.voted === -1 ? ZhihuColors.danger : ZhihuColors.textTertiary)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .onClick(() => {
          this.onDisagree();
        })

        Row({ space: 4 }) {
          Text('○')
            .fontSize(16)
            .fontColor(ZhihuColors.textTertiary)
          Text(formatCount(this.item.comment_count))
            .fontSize(15)
            .fontColor(ZhihuColors.textSecondary)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .onClick(() => {
          this.onComment();
        })

        Row({ space: 4 }) {
          Text(this.collected ? '★' : '☆')
            .fontSize(16)
            .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textTertiary)
          Text(this.collected ? '已收藏' : '收藏')
            .fontSize(15)
            .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textSecondary)
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
