/**
 * pages/AnswerDetailPage —— 回答详情。
 * 上游：app/answer/[id].tsx。
 * 结构：自绘导航栏 + 所属问题标题 + 作者 + 全文(纯文本降级) + 赞同/反对/收藏/评论。
 * 降级：HTML 正文剥标签后用 Text 渲染，不做 WebView。
 */

import { router } from '@kit.ArkUI';
import { getAnswer, voteAnswer, AnswerDetail } from '../api/answer';
import { ZhihuColors } from '../utils/theme';
import { formatDate } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { formatCount, guardLogin, readStringParam, stripHtml } from '../components/detail/detailUtils';

@Entry
@Component
struct AnswerDetailPage {
  @State answerId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State answer: AnswerDetail | null = null;
  @State voting: number = 0;
  @State voteCount: number = 0;
  private bodyText: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.answerId = readStringParam(p, 'id');
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const a: AnswerDetail = await getAnswer(this.answerId);
      this.answer = a;
      this.voting = a.relationship?.voting ?? 0;
      this.voteCount = a.voteup_count ?? 0;
      this.bodyText = stripHtml(a.content);
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

  private onCollect(): void {
    if (!guardLogin()) {
      return;
    }
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
                .fontSize(19)
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
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor(ZhihuColors.text)
                if (this.answer.author.headline && this.answer.author.headline.length > 0) {
                  Text(this.answer.author.headline)
                    .fontSize(13).fontColor(ZhihuColors.textTertiary)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            // 正文（纯文本降级）
            Text(this.bodyText)
          .copyOption(CopyOptions.LocalDevice)
              .fontSize(17)
              .fontColor(ZhihuColors.text)
              .lineHeight(26)
              .width('100%')
              .textAlign(TextAlign.Start)

            if (this.metaText().length > 0) {
              Text(this.metaText())
                .fontSize(13)
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
              .fontSize(15)
              .fontColor(this.voting === 1 ? ZhihuColors.primary : ZhihuColors.textSecondary)
            Text(formatCount(this.voteCount))
              .fontSize(15)
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
              .fontSize(15)
              .fontColor(this.voting === -1 ? ZhihuColors.danger : ZhihuColors.textSecondary)
            Text('反对')
              .fontSize(15)
              .fontColor(this.voting === -1 ? ZhihuColors.danger : ZhihuColors.textSecondary)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onVote(-1);
          })

          Row({ space: 4 }) {
            Text('💬')
            Text(formatCount(this.answer.comment_count))
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onComment();
          })

          Row({ space: 4 }) {
            Text('★')
            Text('收藏')
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
