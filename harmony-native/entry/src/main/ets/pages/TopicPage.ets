/**
 * pages/TopicPage —— 话题详情。
 * 上游：app/topic/[id].tsx。
 * 结构：自绘导航栏 + 话题名/简介/关注按钮 + 内容列表(精华 / 等待回答)分页。
 * 降级：话题简介富文本剥标签；feed 卡片只渲染标题/摘要/作者/计数，按类型跳转对应详情页。
 */

import { router } from '@kit.ArkUI';
import { getTopic, getTopicFeed, followTopic, unfollowTopic } from '../api/topic';
import { ZhihuColors } from '../utils/theme';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import {
  formatCount,
  guardLogin,
  readStringParam,
  stripHtml,
} from '../components/detail/detailUtils';

interface TopicDetailInfo {
  id: string;
  name: string;
  introduction: string;
  is_following: boolean;
  followers_count: number;
  questions_count: number;
}

interface TopicFeedCard {
  id: string;
  type: string;
  title: string;
  excerpt: string;
  authorName: string;
  avatar: string;
  voteCount: number;
  commentCount: number;
}

function num(v: object | undefined, dflt: number): number {
  return v === undefined ? dflt : Number(v);
}

function str(v: object | undefined): string {
  return v === undefined ? '' : String(v);
}

function mapTopicItem(raw: object): TopicFeedCard | null {
  const r = raw as Record<string, object>;
  const targetRaw: object | undefined = r['target'];
  const t: Record<string, object> =
    targetRaw === undefined ? r : (targetRaw as Record<string, object>);

  const idRaw: object | undefined = t['id'];
  if (idRaw === undefined || String(idRaw).length === 0) {
    return null;
  }
  const type: string = str(t['type']);
  const questionObj: object | undefined = t['question'];
  let title: string = str(t['title']);
  if (title.length === 0 && questionObj !== undefined) {
    title = str((questionObj as Record<string, object>)['title']);
  }
  const authorObj: object | undefined = t['author'];
  let authorName: string = '';
  let avatar: string = '';
  if (authorObj !== undefined) {
    const a = authorObj as Record<string, object>;
    authorName = str(a['name']);
    avatar = str(a['avatar_url']);
  }

  return {
    id: String(idRaw),
    type: type,
    title: title,
    excerpt: stripHtml(str(t['excerpt'])),
    authorName: authorName,
    avatar: avatar,
    voteCount: num(t['voteup_count'], 0),
    commentCount: num(t['comment_count'], 0),
  };
}

@Entry
@Component
struct TopicPage {
  @State topicId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State topic: TopicDetailInfo | null = null;
  @State following: boolean = false;
  @State followerCount: number = 0;

  @State cards: TopicFeedCard[] = [];
  @State feedLoading: boolean = false;
  @State isEnd: boolean = false;
  @State tab: string = 'top-answers';
  pageOffset: number = 0;
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.topicId = readStringParam(p, 'id');
    this.loadTopic();
    this.loadFeed(true);
  }

  private async loadTopic(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const resp: object = await getTopic(this.topicId);
      const r = resp as Record<string, object>;
      this.topic = {
        id: str(r['id']),
        name: str(r['name']),
        introduction: stripHtml(str(r['introduction'])),
        is_following: Boolean(r['is_following']),
        followers_count: num(r['followers_count'], 0),
        questions_count: num(r['questions_count'], 0),
      };
      this.following = Boolean(r['is_following']);
      this.followerCount = num(r['followers_count'], 0);
    } catch (e) {
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.loading = false;
    }
  }

  private async loadFeed(reset: boolean): Promise<void> {
    if (this.inFlight) {
      return;
    }
    this.inFlight = true;
    if (reset) {
      this.pageOffset = 0;
      this.isEnd = false;
      this.feedLoading = true;
    }
    try {
      const resp = await getTopicFeed(this.topicId, this.tab, this.pageOffset);
      const list: TopicFeedCard[] = [];
      for (const raw of resp.data) {
        const card: TopicFeedCard | null = mapTopicItem(raw);
        if (card !== null) {
          list.push(card);
        }
      }
      this.cards = reset ? list : this.cards.concat(list);
      this.pageOffset = this.pageOffset + 20;
      this.isEnd = resp.paging.is_end;
    } catch (e) {
      // 翻页失败保留已加载
    } finally {
      this.inFlight = false;
      this.feedLoading = false;
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
        await unfollowTopic(this.topicId);
      } else {
        await followTopic(this.topicId);
      }
    } catch (e) {
      this.following = prev;
      this.followerCount = prevCount;
    }
  }

  private switchTab(mode: string): void {
    if (this.tab === mode) {
      return;
    }
    this.tab = mode;
    this.loadFeed(true);
  }

  private openCard(card: TopicFeedCard): void {
    if (card.type === 'answer') {
      router.pushUrl({ url: 'pages/AnswerDetailPage', params: { id: card.id } });
    } else if (card.type === 'article') {
      router.pushUrl({ url: 'pages/ArticleDetailPage', params: { id: card.id } });
    } else if (card.type === 'pin') {
      router.pushUrl({ url: 'pages/PinDetailPage', params: { id: card.id } });
    } else {
      router.pushUrl({ url: 'pages/QuestionDetailPage', params: { id: card.id } });
    }
  }

  @Builder
  tabBar() {
    Row() {
      Row() {
        Text('精华')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(15)
          .fontColor(this.tab === 'top-answers' ? ZhihuColors.primary : ZhihuColors.textSecondary)
          .fontWeight(this.tab === 'top-answers' ? FontWeight.Bold : FontWeight.Normal)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 12, bottom: 12 })
      .onClick(() => { this.switchTab('top-answers'); })

      Row() {
        Text('等待回答')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(15)
          .fontColor(this.tab === 'unanswered' ? ZhihuColors.primary : ZhihuColors.textSecondary)
          .fontWeight(this.tab === 'unanswered' ? FontWeight.Bold : FontWeight.Normal)
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding({ top: 12, bottom: 12 })
      .onClick(() => { this.switchTab('unanswered'); })
    }
    .width('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  headerContent() {
    Column({ space: 10 }) {
      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress().width(20).height(20).color(ZhihuColors.primary)
          Text('话题加载中…')
            .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center).width('100%').padding(24)
      } else if (this.error.length > 0) {
        Column({ space: 12 }) {
          Text(this.error)
            .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textSecondary)
          Button('重试').fontSize(13).backgroundColor(ZhihuColors.primary)
            .onClick(() => { this.loadTopic(); })
        }
        .width('100%').padding(20)
      } else if (this.topic !== null) {
        Row() {
          Column({ space: 4 }) {
            Text(this.topic.name)
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ZhihuColors.text)
            Text(formatCount(this.followerCount) + ' 关注者 · ' +
              formatCount(this.topic.questions_count) + ' 问题')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(12).fontColor(ZhihuColors.textTertiary)
          }
          .alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text(this.following ? '已关注' : '+ 关注')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.following ? ZhihuColors.textSecondary : ZhihuColors.textInverse)
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(15)
            .backgroundColor(this.following ? ZhihuColors.backgroundTertiary : ZhihuColors.primary)
            .onClick(() => { this.toggleFollow(); })
        }
        .width('100%').alignItems(VerticalAlign.Center)

        if (this.topic.introduction.length > 0) {
          Text(this.topic.introduction)
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(14).fontColor(ZhihuColors.textSecondary).lineHeight(21)
            .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%').textAlign(TextAlign.Start)
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  footer() {
    Column() {
      if (this.feedLoading && this.cards.length > 0) {
        Row({ space: 8 }) {
          LoadingProgress().width(16).height(16).color(ZhihuColors.textTertiary)
          Text('加载中…')
            .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center).width('100%').padding(12)
      } else if (this.isEnd && this.cards.length > 0) {
        Text('— 没有更多内容了 —')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(13).fontColor(ZhihuColors.textTertiary)
          .width('100%').textAlign(TextAlign.Center).padding(12)
      }
    }
  }

  build() {
    Column() {
      DetailNavBar({ title: this.topic ? this.topic.name : '话题' })
      this.tabBar()

      List({ space: 10, scroller: this.scroller }) {
        ListItem() {
          this.headerContent()
        }

        ForEach(this.cards, (card: TopicFeedCard) => {
          ListItem() {
            Column({ space: 6 }) {
              Row({ space: 8 }) {
                if (card.avatar.length > 0) {
                  Image(card.avatar)
                    .width(32).height(32).borderRadius(16)
                    .objectFit(ImageFit.Cover)
                    .backgroundColor(ZhihuColors.backgroundTertiary)
                }
                Text(card.authorName)
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(13).fontColor(ZhihuColors.textSecondary)
                  .maxLines(1).layoutWeight(1)
              }
              .width('100%').alignItems(VerticalAlign.Center)

              if (card.title.length > 0) {
                Text(card.title)
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor(ZhihuColors.text)
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              if (card.excerpt.length > 0) {
                Text(card.excerpt)
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(14).fontColor(ZhihuColors.textSecondary)
                  .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .lineHeight(21).width('100%')
              }
              Row({ space: 14 }) {
                Text('▲ ' + formatCount(card.voteCount))
                  .copyOption(CopyOptions.LocalDevice).fontSize(12).fontColor(ZhihuColors.textTertiary)
                Text('💬 ' + formatCount(card.commentCount))
                  .copyOption(CopyOptions.LocalDevice).fontSize(12).fontColor(ZhihuColors.textTertiary)
              }
              .width('100%')
            }
            .width('100%').padding(14)
            .backgroundColor(ZhihuColors.backgroundSecondary).borderRadius(12)
            .alignItems(HorizontalAlign.Start)
            .onClick(() => { this.openCard(card); })
          }
        }, (card: TopicFeedCard) => card.type + '-' + card.id)

        ListItem() {
          this.footer()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })
      .scrollBar(BarState.Off)
      .onReachEnd(() => { this.loadFeed(false); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
