/**
 * pages/AnswerDetailPage —— 回答详情。
 * 上游：app/answer/[id].tsx。
 * 结构：自绘导航栏 + 所属问题标题 + 作者 + 全文(纯文本降级) + 赞同/反对/收藏/评论。
 * 降级：HTML 正文剥标签后用 Text 渲染，不做 WebView。
 */

import { router, promptAction } from '@kit.ArkUI';
import { getAnswer, voteAnswer, AnswerDetail } from '../api/answer';
import { getAnswerCollectionStatus, removeFromCollection } from '../api/collection';
import { ZhihuColors } from '../utils/theme';
import { formatDate } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { formatCount, guardLogin, HtmlBlock, parseContent, readStringParam } from '../components/detail/detailUtils';
import { NetImage } from '../components/NetImage';
import { RichBody } from '../components/detail/RichBody';

@Entry
@Component
struct AnswerDetailPage {
  @State answerId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State answer: AnswerDetail | null = null;
  @State voting: number = 0;
  @State voteCount: number = 0;
  @State collected: boolean = false;
  @State collectionId: string = '';
  @StorageLink('collectPicked') @Watch('onCollectPicked') collectPicked: string = '';
  @State bodyBlocks: HtmlBlock[] = [];

  onCollectPicked(): void {
    if (this.collectPicked === this.answerId) {
      this.collected = true;
      this.collectPicked = '';
    }
  }

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.answerId = readStringParam(p, 'id');
    this.load();
  }

  // 从写操作/评论返回时刷新（首次由 aboutToAppear 加载）
  onPageShow(): void {
    if (this.shownOnce) {
      this.load();
    }
    this.shownOnce = true;
  }
  private shownOnce: boolean = false;

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.refreshCollectionStatus();
    try {
      const a: AnswerDetail = await getAnswer(this.answerId);
      this.answer = a;
      this.voting = a.relationship?.voting ?? 0;
      this.voteCount = a.voteup_count ?? 0;
      this.bodyBlocks = parseContent(a.content);
    } catch (e) {
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.loading = false;
    }
  }

  private async onVote(target: number): Promise<void> {
    if (!guardLogin()) {
      return;
    }
    const prev: number = this.voting;
    const prevCount: number = this.voteCount;
    // 再点一次取消；赞同 ↔ 反对互切。
    const next: number = prev === target ? 0 : target;
    this.voting = next;
    if (next === 1) {
      this.voteCount = prev === 1 ? prevCount : prevCount + 1;
    } else if (next === 0 && prev === 1) {
      this.voteCount = Math.max(0, prevCount - 1);
    }
    const type: 'up' | 'down' | 'neutral' = next === 1 ? 'up' : (next === -1 ? 'down' : 'neutral');
    try {
      await voteAnswer(this.answerId, type);
    } catch (e) {
      this.voting = prev;
      this.voteCount = prevCount;
    }
  }

  /** 赞同者列表（对齐上游 app/answer/[id].tsx 赞同数入口）。 */
  private openVoters(): void {
    router.pushUrl({
      url: 'pages/VotersPage',
      params: {
        contentType: 'answer',
        contentId: this.answerId,
        count: String(this.voteCount),
      },
    });
  }

  private onComment(): void {
    router.pushUrl({
      url: 'pages/CommentsPage',      params: { resourceType: 'answers', resourceId: this.answerId },
    });
  }

  /** 查询该回答是否已被收藏 */
  private async refreshCollectionStatus(): Promise<void> {
    if (this.answerId.length === 0) {
      return;
    }
    try {
      const st = await getAnswerCollectionStatus(this.answerId, 1);
      if (st.collected === true) {
        this.collected = true;
        const list = st.data ?? [];
        if (list.length > 0) {
          const first = list[0] as Record<string, object>;
          this.collectionId = String(first['id'] ?? '');
        }
      }
    } catch (e) {
      // 状态查询失败不阻塞页面
    }
  }

  private async onCollect(): Promise<void> {
    if (!guardLogin()) {
      return;
    }
    if (this.collected) {
      // 已收藏 → 取消收藏（对齐上游 toggleCollect）
      if (this.collectionId.length === 0) {
        await this.refreshCollectionStatus();
        if (this.collectionId.length === 0) {
          promptAction.showToast({ message: '无法获取收藏夹信息' });
          return;
        }
      }
      try {
        await removeFromCollection(this.collectionId, this.answerId);
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
      params: { resourceType: 'answer', resourceId: this.answerId },
    });
  }

  private metaText(): string {
    const a = this.answer;
    if (a === null) {
      return '';
    }
    const parts: string[] = [];
    if (a.created_time && a.created_time > 0) {
      parts.push('发布于 ' + formatDate(a.created_time));
    }
    if (a.updated_time && a.updated_time > 0) {
      parts.push('编辑于 ' + formatDate(a.updated_time));
    }
    if (a.ip_info !== undefined && a.ip_info.length > 0) {
      parts.push(a.ip_info);
    }
    return parts.join(' · ');
  }

  build() {
    Column() {
      DetailNavBar({ title: '回答' })

      if (this.loading) {
        StatusView({ loading: true })
      } else if (this.error.length > 0) {
        StatusView({ error: this.error, onRetry: () => { this.load(); } })
      } else if (this.answer !== null) {
        Scroll() {
          Column({ space: 12 }) {
            // 所属问题
            if (this.answer.question !== undefined && this.answer.question.title.length > 0) {
              Text(this.answer.question.title)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(ZhihuColors.text)
                .width('100%')
                .textAlign(TextAlign.Start)
            }

            // 作者行
            Row({ space: 10 }) {
              Image(this.answer.author.avatar_url)
                .width(40).height(40).borderRadius(20)
                .objectFit(ImageFit.Cover)
                .backgroundColor(ZhihuColors.backgroundTertiary)
              Column({ space: 2 }) {
                Text(this.answer.author.name)
                  .fontSize(17).fontWeight(FontWeight.Medium).fontColor(ZhihuColors.text)
                if (this.answer.author.headline && this.answer.author.headline.length > 0) {
                  Text(this.answer.author.headline)
                    .fontSize(14).fontColor(ZhihuColors.textTertiary)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            // 正文（结构化富文本：标题/粗体/列表/引用/代码/图片）
            RichBody({ blocks: this.bodyBlocks })

            if (this.metaText().length > 0) {
              Text(this.metaText())
                .fontSize(14)
                .fontColor(ZhihuColors.textTertiary)
                .width('100%')
            }
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(ZhihuColors.backgroundSecondary)

        // 操作条
        Row({ space: 4 }) {
          Row({ space: 4 }) {
            Text(this.voting === 1 ? '▲' : '△')
              .fontSize(16)
              .fontColor(this.voting === 1 ? ZhihuColors.primary : ZhihuColors.textSecondary)
            Text(formatCount(this.voteCount))
              .fontSize(16)
              .fontColor(this.voting === 1 ? ZhihuColors.primary : ZhihuColors.textSecondary)
              .onClick(() => {
                this.openVoters();
              })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onVote(1);
          })

          Row({ space: 4 }) {
            Text(this.voting === -1 ? '▼' : '▽')
              .fontSize(16)
              .fontColor(this.voting === -1 ? ZhihuColors.danger : ZhihuColors.textSecondary)
            Text('反对')
              .fontSize(16)
              .fontColor(this.voting === -1 ? ZhihuColors.danger : ZhihuColors.textSecondary)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onVote(-1);
          })

          Row({ space: 4 }) {
            Text('○')
            Text(formatCount(this.answer.comment_count))
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onComment();
          })

          Row({ space: 4 }) {
            Text(this.collected ? '★' : '☆')
              .fontSize(17)
              .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textSecondary)
            Text(this.collected ? '取消收藏' : '移至收藏')
              .fontSize(16)
              .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textSecondary)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onCollect();
          })
        }
        .width('100%')
        .backgroundColor(ZhihuColors.backgroundSecondary)
        .border({ width: { top: 0.5 }, color: ZhihuColors.border })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
