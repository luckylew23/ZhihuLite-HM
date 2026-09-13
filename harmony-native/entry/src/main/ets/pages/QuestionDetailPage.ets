/**
 * pages/QuestionDetailPage —— 问题详情（对齐 Android v0.6.0 截图 10）。
 * 自上而下：标题 / 话题 chips / 媒体报道卡片(预留骨架,接口无数据则隐藏) /
 *           网友自述(图片+长文,展开全文/收起) / 关注·浏览 / 关注·评论·写回答三按钮 /
 *           回答数+排序(默认/时间) / 回答卡片列表。
 * 数据请求与字段映射沿用既有 getQuestion/getQuestionAnswers/followQuestion，仅调整布局。
 */

import { router } from '@kit.ArkUI';
import { NetImage } from '../components/NetImage';
import { Want, common } from '@kit.AbilityKit';
import {
  getQuestion,
  getQuestionAnswers,
  followQuestion,
  unfollowQuestion,
  ZhihuQuestionDetail,
} from '../api/question';
import { AnswerDetail } from '../api/answer';
import { ZhihuTopic } from '../model/zhihu';
import { ZhihuColors } from '../utils/theme';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { AnswerCard } from '../components/detail/AnswerCard';
import {
  formatCount,
  guardLogin,
  readStringParam,
  stripHtml,
} from '../components/detail/detailUtils';

const ANSWER_INCLUDE: string =
  'data[*].content,excerpt,voteup_count,comment_count,favlists_count,author.name,author.avatar_url,author.headline,author.is_following,relationship.voting,relationship.is_author,created_time,updated_time,ip_info,segment_infos';

@Entry
@Component
struct QuestionDetailPage {
  @State qId: string = '';
  @State loadingQ: boolean = true;
  @State qError: string = '';
  @State question: ZhihuQuestionDetail | null = null;
  @State following: boolean = false;
  @State followerCount: number = 0;

  @State answers: AnswerDetail[] = [];
  @State answersLoading: boolean = false;
  @State answersError: string = '';
  @State isEnd: boolean = false;
  @State nextParam: string = '';
  @State sortBy: string = 'default';
  @State detailExpanded: boolean = false;
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.qId = readStringParam(p, 'id');
    this.loadQuestion();
    this.loadAnswers(true);
  }

  // 从写回答/评论/点赞返回时刷新（首次由 aboutToAppear 加载，避免双请求）
  onPageShow(): void {
    if (this.shownOnce) {
      this.loadQuestion();
    }
    this.shownOnce = true;
  }
  private shownOnce: boolean = false;

  private async loadQuestion(): Promise<void> {
    this.loadingQ = true;
    this.qError = '';
    try {
      const q: ZhihuQuestionDetail = await getQuestion(this.qId);
      this.question = q;
      this.following = q.relationship?.is_following ?? false;
      this.followerCount = q.follower_count ?? 0;
    } catch (e) {
      this.qError = getZhihuErrorMessage(e as object);
    } finally {
      this.loadingQ = false;
    }
  }

  private async loadAnswers(reset: boolean): Promise<void> {
    if (this.inFlight) {
      return;
    }
    this.inFlight = true;
    if (reset) {
      this.answersLoading = true;
      this.answersError = '';
      this.nextParam = '';
    }
    try {
      const pageParam: number | string = reset ? 0 : this.nextParam;
      const resp = await getQuestionAnswers(
        this.qId,
        pageParam,
        this.sortBy === 'created' ? 'created' : 'default',
        ANSWER_INCLUDE,
      );
      this.nextParam = resp.paging?.next ?? '';
      this.isEnd = resp.paging?.is_end ?? true;
      this.answers = reset ? resp.data : this.answers.concat(resp.data);
    } catch (e) {
      if (reset) {
        this.answersError = getZhihuErrorMessage(e as object);
      }
    } finally {
      this.answersLoading = false;
      this.inFlight = false;
    }
  }

  private async toggleFollow(): Promise<void> {
    if (!guardLogin()) {
      return;
    }
    const prev: boolean = this.following;
    const prevCount: number = this.followerCount;
    this.following = !prev;
    this.followerCount = prev ? Math.max(0, prevCount - 1) : prevCount + 1;
    try {
      if (prev) {
        await unfollowQuestion(this.qId);
      } else {
        await followQuestion(this.qId);
      }
    } catch (e) {
      this.following = prev;
      this.followerCount = prevCount;
    }
  }

  private onSortChange(mode: string): void {
    if (this.sortBy === mode) {
      return;
    }
    this.sortBy = mode;
    this.loadAnswers(true);
  }

  private openTopic(topic: ZhihuTopic): void {
    router.pushUrl({ url: 'pages/TopicPage', params: { id: String(topic.id) } });
  }

  private openComments(): void {
    router.pushUrl({
      url: 'pages/CommentsPage',
      params: { resourceType: 'questions', resourceId: this.qId },
    });
  }

  private onWriteAnswer(): void {
    if (!guardLogin()) {
      return;
    }
    router.pushUrl({
      url: 'pages/PublishAnswerPage',
      params: { questionId: this.qId },
    });
  }

  /** 用系统浏览器打开外部链接（媒体报道等）。 */
  private openLink(url: string): void {
    if (url.length === 0) {
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    const w: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url,
    };
    ctx.startAbility(w);
  }

  /** 媒体报道数据：本接口暂无专门字段，预留读取 link_card_info，无数据时整块隐藏。 */
  private mediaUrl(): string {
    const lc = this.question?.link_card_info;
    if (lc === undefined) {
      return '';
    }
    const u = lc['url'];
    return u === undefined ? '' : u;
  }

  private mediaTitle(): string {
    const lc = this.question?.link_card_info;
    if (lc === undefined) {
      return '';
    }
    const t = lc['title'];
    return t === undefined ? '' : t;
  }

  /** 从 detail HTML 中抽取图片地址（网友自述配图）。 */
  private detailImages(): string[] {
    const raw: string = this.question?.detail ?? '';
    const urls: string[] = [];
    if (raw.length === 0) {
      return urls;
    }
    const re: RegExp = /<img[^>]+src="([^">]+)"/g;
    let m: RegExpExecArray | null = re.exec(raw);
    while (m !== null) {
      urls.push(m[1]);
      m = re.exec(raw);
    }
    return urls;
  }

  private detailText(): string {
    const q = this.question;
    if (q === null) {
      return '';
    }
    const raw: string = this.detailExpanded ? (q.detail ?? '') : (q.excerpt ?? '');
    return stripHtml(raw);
  }

  @Builder
  mediaReportBlock() {
    // 媒体报道卡片：浅色卡片 + 外部链接图标，点击 openLink。接口无数据时不渲染。
    if (this.mediaUrl().length > 0) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text('媒体报道')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(ZhihuColors.text)
          Text(this.mediaTitle().length > 0 ? this.mediaTitle() : this.mediaUrl())
            .fontSize(15)
            .fontColor(ZhihuColors.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('↗')
          .fontSize(18)
          .fontColor(ZhihuColors.primary)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(ZhihuColors.backgroundTertiary)
      .borderRadius(8)
      .onClick(() => {
        this.openLink(this.mediaUrl());
      })
    }
  }

  @Builder
  selfReportBlock() {
    // 网友自述：配图 + 长文，超长带「展开全文/收起」。
    if (this.detailText().length > 0) {
      Column({ space: 8 }) {
        if (this.detailImages().length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.detailImages().slice(0, 3), (src: string) => {
              NetImage({ url: src, w: 110, h: 110, r: 8, mr: 8, mb: 8})
            }, (src: string) => src)
          }
          .width('100%')
        }

        Text(this.detailText())
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(16)
          .fontColor(ZhihuColors.textSecondary)
          .lineHeight(21)
          .width('100%')
          .textAlign(TextAlign.Start)
          .maxLines(this.detailExpanded ? 1000 : 6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if ((this.question?.detail ?? '').length > 0) {
          Text(this.detailExpanded ? '收起' : '展开全文')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(ZhihuColors.primary)
            .onClick(() => {
              this.detailExpanded = !this.detailExpanded;
            })
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  actionButton(label: string, isActive: boolean, onClick: () => void) {
    Text(label)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(ZhihuColors.primary)
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .padding({ top: 10, bottom: 10 })
      .borderRadius(20)
      .backgroundColor('#1a0084ff')
      .onClick(onClick)
  }

  @Builder
  sortTab(label: string, mode: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(16)
        .fontColor(this.sortBy === mode ? ZhihuColors.primary : ZhihuColors.textSecondary)
        .fontWeight(this.sortBy === mode ? FontWeight.Bold : FontWeight.Normal)
      if (this.sortBy === mode) {
        Row()
          .width(18)
          .height(2)
          .backgroundColor(ZhihuColors.primary)
          .borderRadius(1)
      }
    }
    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
    .onClick(() => {
      this.onSortChange(mode);
    })
  }

  @Builder
  headerContent() {
    Column({ space: 14 }) {
      if (this.loadingQ) {
        Row({ space: 8 }) {
          LoadingProgress().width(20).height(20).color(ZhihuColors.primary)
          Text('问题加载中…')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(24)
      } else if (this.qError.length > 0) {
        Column({ space: 12 }) {
          Text(this.qError)
          Button('重试').fontSize(15).backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loadQuestion();
            })
        }
        .width('100%')
        .padding(20)
      } else {
        // 1. 问题标题（粗体大字）
        Text(this.question?.title ?? '')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.text)
          .width('100%')
          .textAlign(TextAlign.Start)

        // 2. 话题标签行：浅灰圆角 chip 横排（可换行）
        if (this.question?.topics !== undefined && this.question.topics.length > 0) {
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.question.topics, (topic: ZhihuTopic) => {
              Text(topic.name)
                .fontSize(14)
                .fontColor(ZhihuColors.primary)
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .borderRadius(14)
                .backgroundColor('#1a0084ff')
                .margin({ right: 8, bottom: 8 })
                .onClick(() => {
                  this.openTopic(topic);
                })
            }, (topic: ZhihuTopic) => String(topic.id))
          }
          .width('100%')
        }

        // 3. 媒体报道摘要块（接口无数据时自动隐藏，骨架已留好）
        this.mediaReportBlock()

        // 4. 网友自述：图片+文字，长文展开/收起
        this.selfReportBlock()

        // 5. 关注·浏览数据行
        Text((this.followerCount) + ' 关注 · ' + (this.question?.visit_count ?? 0) + ' 浏览')
          .fontSize(15)
          .fontColor(ZhihuColors.textTertiary)
          .width('100%')

        // 6. 操作行：关注问题 / 评论 / 写回答
        Row({ space: 10 }) {
          this.actionButton(this.following ? '已关注' : '关注问题', this.following, (): void => {
            this.toggleFollow();
          })
          this.actionButton(formatCount(this.question?.comment_count ?? 0) + ' 条评论', false, (): void => {
            this.openComments();
          })
          this.actionButton('写回答', false, (): void => {
            this.onWriteAnswer();
          })
        }
        .width('100%')

        // 7. 回答数 + 排序切换（默认 / 时间）
        Row() {
          Text((this.question?.answer_count ?? 0) + ' 个回答')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(ZhihuColors.text)
            .layoutWeight(1)
          this.sortTab('默认', 'default')
          this.sortTab('时间', 'created')
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  footer() {
    Column() {
      if (this.answersLoading && this.answers.length > 0) {
        Row({ space: 8 }) {
          LoadingProgress().width(16).height(16).color(ZhihuColors.textTertiary)
          Text('加载中…')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(12)
      } else if (this.isEnd && this.answers.length > 0) {
        Text('— 没有更多回答了 —')
          .fontSize(15)
          .fontColor(ZhihuColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(12)
      }
    }
  }

  build() {
    Column() {
      DetailNavBar({ title: this.question?.title ?? '问题' })

      Stack({ alignContent: Alignment.TopStart }) {
        List({ space: 10, scroller: this.scroller }) {
          ListItem() {
            this.headerContent()
          }

          ForEach(this.answers, (item: AnswerDetail) => {
            ListItem() {
              AnswerCard({ item: item })
            }
          }, (item: AnswerDetail) => String(item.id))

          ListItem() {
            this.footer()
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 12, right: 12, top: 8 })
        .scrollBar(BarState.Off)
        .onReachEnd(() => {
          this.loadAnswers(false);
        })

        // 回答首屏加载 / 错误 / 空
        if (this.answersLoading && this.answers.length === 0) {
          Column({ space: 8 }) {
            LoadingProgress().width(40).height(40).color(ZhihuColors.primary)
            Text('回答加载中…')
          }
          .width('100%')
          .padding(60)
        }
        if (this.answersError.length > 0 && this.answers.length === 0) {
          Column({ space: 16 }) {
            Text(this.answersError)
            Button('重试').fontSize(16).backgroundColor(ZhihuColors.primary)
              .onClick(() => {
                this.loadAnswers(true);
              })
          }
          .width('100%')
          .padding(60)
        }
        if (!this.answersLoading && this.answersError.length === 0 && this.answers.length === 0 && !this.loadingQ) {
          Text('暂无回答')
            .fontSize(16)
            .fontColor(ZhihuColors.textTertiary)
            .width('100%')
            .padding(60)
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
