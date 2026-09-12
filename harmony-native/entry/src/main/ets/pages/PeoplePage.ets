/**
 * pages/PeoplePage —— 用户完整主页（按 Android v0.6.0 截图 01 重构布局）。
 * 上游：app/user/[id]/index.tsx。入参：{ urlToken }（兼容 { memberId }）。
 * 头部：返回 + 大头像 + 昵称 + 「最近发布/签名」+ 关注/私信按钮 + 统计行；
 * Tabs：回答 / 文章 / 想法 / 关注 / 粉丝 / 动态；
 * 动态卡片：类型行(回答了问题) + 作者 + 问题标题 + 摘要(右缩略图) + ▲/○/☆ 计数行；
 * 底部：「已看完本次更新」。
 */

import { router } from '@kit.ArkUI';
import {
  ZhihuMember,
  ZhihuMemberListItem,
  ZhihuMemberActivity,
  getMemberWithFallback,
  getMemberRelations,
  getMemberActivities,
  getMemberFollowers,
  getMemberFollowing,
  followMember,
  unfollowMember,
  MEMBER_ANSWERS_INCLUDE,
} from '../api/member';
import { ZhihuMemberRelation } from '../model/zhihu';
import { FeedItem } from '../api/feed';
import { getMe } from '../api/me';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { MemberRow } from '../components/profile/MemberRow';
import {
  relationToFeedItem,
  activityToFeedItem,
  feedDetailUrl,
} from '../components/profile/profileMappers';

interface ProfileTab {
  key: string;
  label: string;
}

const TABS: ProfileTab[] = [
  { key: 'answers', label: '回答' },
  { key: 'articles', label: '文章' },
  { key: 'pins', label: '想法' },
  { key: 'following', label: '关注' },
  { key: 'followers', label: '粉丝' },
  { key: 'activities', label: '动态' },
];

const ARTICLES_INCLUDE =
  'data[*].comment_count,content,voteup_count,favlists_count,created,updated,title,excerpt,reaction,relationship.voting;data[*].author';
const PINS_INCLUDE =
  'data[*].content,reaction_count,comment_count,created,reaction,relationship.voting;data[*].author';

function formatCount(count: number): string {
  if (count >= 100000000) {
    return (count / 100000000).toFixed(1) + '亿';
  }
  if (count >= 10000) {
    return (count / 10000).toFixed(1) + '万';
  }
  return String(count);
}

@Entry
@Component
export struct PeoplePage {
  @State token: string = '';
  @State member: ZhihuMember | null = null;
  @State loading: boolean = true;
  @State error: string = '';

  @State activeTab: string = 'answers';
  @State feedItems: FeedItem[] = [];
  @State members: ZhihuMemberListItem[] = [];
  @State loadingList: boolean = false;
  @State loadingMore: boolean = false;
  @State listError: string = '';
  @State isEnd: boolean = false;
  @State pageOffset: number = 0;

  @State isMe: boolean = false;
  @State isFollowing: boolean = false;
  @State followerCount: number = 0;
  @State followLoading: boolean = false;

  private scroller: Scroller = new Scroller();
  private inFlight: boolean = false;

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    if (p) {
      const t = p['urlToken'] ? String(p['urlToken']) : '';
      const m = p['memberId'] ? String(p['memberId']) : '';
      this.token = t.length > 0 ? t : m;
    }
    if (this.token.length === 0) {
      this.loading = false;
      this.error = '缺少用户标识';
      return;
    }
    this.loadMember();
  }

  async loadMember(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const u = await getMemberWithFallback(this.token);
      this.member = u;
      this.isFollowing = u.is_following ?? false;
      this.followerCount = u.follower_count ?? 0;
      if (authStore.isLoggedIn) {
        try {
          const me = await getMe();
          this.isMe = me.url_token === this.token;
        } catch (e) {
          this.isMe = false;
        }
      }
      await this.loadTabFirst();
    } catch (e) {
      this.error = '用户资料加载失败';
    } finally {
      this.loading = false;
    }
  }

  private isMemberTab(key: string): boolean {
    return key === 'followers' || key === 'following';
  }

  async selectTab(key: string): Promise<void> {
    if (key === this.activeTab) {
      return;
    }
    this.activeTab = key;
    await this.loadTabFirst();
  }

  async loadTabFirst(): Promise<void> {
    this.feedItems = [];
    this.members = [];
    this.pageOffset = 0;
    this.isEnd = false;
    this.listError = '';
    await this.fetchPage(true);
  }

  async loadMore(): Promise<void> {
    if (this.inFlight || this.isEnd) {
      return;
    }
    this.loadingMore = true;
    await this.fetchPage(false);
    this.loadingMore = false;
  }

  async fetchPage(reset: boolean): Promise<void> {
    if (this.token.length === 0) {
      return;
    }
    this.inFlight = true;
    this.loadingList = true;
    try {
      const tab = this.activeTab;
      if (tab === 'answers' || tab === 'articles' || tab === 'pins') {
        const relType = tab as 'answers' | 'articles' | 'pins';
        const include = relType === 'answers'
          ? MEMBER_ANSWERS_INCLUDE
          : (relType === 'articles' ? ARTICLES_INCLUDE : PINS_INCLUDE);
        const resp = await getMemberRelations(this.token, relType, {
          limit: 20,
          offset: this.pageOffset,
          include: include,
        });
        const list: FeedItem[] = [];
        for (const rel of resp.data) {
          list.push(relationToFeedItem(rel as ZhihuMemberRelation));
        }
        this.feedItems = reset ? list : this.feedItems.concat(list);
        this.isEnd = resp.paging.is_end;
      } else if (tab === 'activities') {
        const resp = await getMemberActivities(this.token, 20, this.pageOffset);
        const list: FeedItem[] = [];
        for (const act of resp.data) {
          list.push(activityToFeedItem(act as ZhihuMemberActivity,
            this.member?.name ?? '', this.member?.avatar_url ?? ''));
        }
        this.feedItems = reset ? list : this.feedItems.concat(list);
        this.isEnd = resp.paging.is_end;
      } else if (tab === 'following') {
        const resp = await getMemberFollowing(this.token, 20, this.pageOffset);
        this.members = reset ? resp.data : this.members.concat(resp.data);
        this.isEnd = resp.paging.is_end;
      } else if (tab === 'followers') {
        const resp = await getMemberFollowers(this.token, 20, this.pageOffset);
        this.members = reset ? resp.data : this.members.concat(resp.data);
        this.isEnd = resp.paging.is_end;
      }
      this.pageOffset = this.pageOffset + 20;
    } catch (e) {
      this.listError = '内容加载失败';
    } finally {
      this.inFlight = false;
      this.loadingList = false;
    }
  }

  async handleFollow(): Promise<void> {
    if (this.followLoading) {
      return;
    }
    if (!authStore.isLoggedIn) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.followLoading = true;
    const next = !this.isFollowing;
    // 乐观更新
    this.isFollowing = next;
    this.followerCount = Math.max(0, this.followerCount + (next ? 1 : -1));
    try {
      if (next) {
        await followMember(this.token);
      } else {
        await unfollowMember(this.token);
      }
    } catch (e) {
      // 回滚
      this.isFollowing = !next;
      this.followerCount = Math.max(0, this.followerCount + (next ? -1 : 1));
    } finally {
      this.followLoading = false;
    }
  }

  private openMessage(): void {
    if (!authStore.isLoggedIn) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    router.pushUrl({
      url: 'pages/ChatPage',
      params: { urlToken: this.token },
    });
  }

  private openFeed(item: FeedItem): void {
    router.pushUrl({
      url: feedDetailUrl(item),
      params: { id: item.id, questionId: item.questionId ?? '' },
    });
  }

  /** 动态类型文案：按 FeedItem.type 推导（mapper 未回填 actionText） */
  private typeText(item: FeedItem): string {
    if (item.type === 'answers') {
      return '回答了问题';
    }
    if (item.type === 'articles') {
      return '发表了文章';
    }
    if (item.type === 'pins') {
      return '发布了想法';
    }
    if (item.type === 'questions') {
      return '关注了问题';
    }
    if (item.type === 'video') {
      return '发布了视频';
    }
    return '';
  }

  private hasAnyItem(): boolean {
    return this.feedItems.length > 0 || this.members.length > 0;
  }

  // ---------------- UI ----------------
  @Builder
  statItem(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value).fontSize(17).fontWeight(FontWeight.Bold).fontColor(ZhihuColors.text)
      Text(label).fontSize(12).fontColor(ZhihuColors.textSecondary)
    }
    .layoutWeight(1)
  }

  @Builder
  headerBlock() {
    Column({ space: 0 }) {
      // 顶部行：返回 + 大头像 + 昵称/签名
      Row({ space: 12 }) {
        Text('‹')
          .fontSize(28)
          .fontColor(ZhihuColors.text)
          .padding({ left: 4, right: 4 })
          .onClick(() => {
            router.back();
          })
        Image(this.member?.avatar_url ?? '')
          .width(56)
          .height(56)
          .borderRadius(28)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(this.member?.name ?? '')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(ZhihuColors.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            if (!this.isMe) {
              Text(this.isFollowing ? '已关注' : '关注')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isFollowing ? ZhihuColors.textSecondary : ZhihuColors.primary)
                .height(30)
                .padding({ left: 14, right: 14 })
                .borderRadius(15)
                .backgroundColor(this.isFollowing
                  ? ZhihuColors.backgroundTertiary
                  : ZhihuColors.backgroundSecondary)
                .border({ width: 1, color: ZhihuColors.primary })
                .onClick(() => {
                  this.handleFollow();
                })
              Text('私信')
                .fontSize(13)
                .fontColor(ZhihuColors.textSecondary)
                .height(30)
                .padding({ left: 12, right: 12 })
                .borderRadius(15)
                .backgroundColor(ZhihuColors.backgroundSecondary)
                .border({ width: 1, color: ZhihuColors.border })
                .onClick(() => {
                  this.openMessage();
                })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          Text(this.member?.headline ?? '最近发布')
            .fontSize(13)
            .fontColor(ZhihuColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12, bottom: 12 })
      .alignItems(VerticalAlign.Center)

      if (this.member?.description && this.member.description.length > 0) {
        Text(this.member.description)
          .fontSize(13)
          .fontColor(ZhihuColors.textSecondary)
          .lineHeight(19)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      // 统计行
      Row() {
        this.statItem(String(this.followerCount), '关注者')
        this.statItem(String(this.member?.following_count ?? 0), '关注')
        this.statItem(String(this.member?.voteup_count ?? 0), '赞同')
        this.statItem(String(this.member?.answer_count ?? 0), '回答')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4, bottom: 12 })
    }
    .width('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  tabBar() {
    Row() {
      ForEach(TABS, (tab: ProfileTab) => {
        Column() {
          Text(tab.label)
            .fontSize(14)
            .fontWeight(this.activeTab === tab.key ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.activeTab === tab.key ? ZhihuColors.primary : ZhihuColors.textSecondary)
            .padding({ top: 12, bottom: 12 })
        }
        .layoutWeight(1)
        .onClick(() => {
          this.selectTab(tab.key);
        })
      }, (tab: ProfileTab) => tab.key)
    }
    .width('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .border({ width: 0.5, color: ZhihuColors.border })
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18).color(ZhihuColors.textTertiary)
          Text('加载中…').fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(12)
      } else if (this.isEnd && this.hasAnyItem()) {
        Text('已看完本次更新')
          .fontSize(13)
          .fontColor(ZhihuColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(16)
      }
    }
  }

  /** 动态卡片：类型行 + 作者 + 标题 + 摘要(右缩略图) + ▲/○/☆ 计数行 */
  @Builder
  activityCard(item: FeedItem) {
    Column({ space: 8 }) {
      Text(this.typeText(item))
        .fontSize(13)
        .fontColor(ZhihuColors.textTertiary)
        .width('100%')

      Row({ space: 8 }) {
        Image(item.author.avatar)
          .width(28)
          .height(28)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
        Text(item.author.name)
          .fontSize(14)
          .fontColor(ZhihuColors.text)
          .maxLines(1)
          .layoutWeight(1)
      }
      .width('100%')

      if (item.type !== 'pins' && item.title.length > 0) {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .maxLines(2)
          .lineHeight(23)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      if (item.excerpt.length > 0) {
        Row({ space: 10 }) {
          Text(item.excerpt)
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
            .lineHeight(20)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (item.image !== null && item.image.length > 0) {
            Image(item.image)
              .width(96)
              .height(72)
              .borderRadius(8)
              .objectFit(ImageFit.Cover)
              .backgroundColor(ZhihuColors.backgroundTertiary)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }

      Row({ space: 18 }) {
        Row({ space: 4 }) {
          Text('▲').fontSize(12).fontColor(ZhihuColors.textTertiary)
          Text(formatCount(item.voteCount)).fontSize(13).fontColor(ZhihuColors.textSecondary)
        }
        Row({ space: 4 }) {
          Text('○').fontSize(12).fontColor(ZhihuColors.textTertiary)
          Text(formatCount(item.commentCount)).fontSize(13).fontColor(ZhihuColors.textSecondary)
        }
        if (item.favlistsCount !== undefined && item.favlistsCount > 0) {
          Row({ space: 4 }) {
            Text('☆').fontSize(12).fontColor(ZhihuColors.textTertiary)
            Text(formatCount(item.favlistsCount)).fontSize(13).fontColor(ZhihuColors.textSecondary)
          }
        }
        Blank()
        Text('···').fontSize(13).fontColor(ZhihuColors.textTertiary)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  contentList() {
    if (this.isMemberTab(this.activeTab)) {
      List({ scroller: this.scroller }) {
        ForEach(this.members, (m: ZhihuMemberListItem, idx: number) => {
          ListItem() {
            MemberRow({
              name: m.name,
              avatar: m.avatar_url ?? '',
              headline: m.headline ?? '',
              urlToken: m.url_token ?? String(m.id),
            })
          }
        }, (m: ZhihuMemberListItem, idx: number) => String(idx) + '-' + m.id)
        ListItem() {
          this.footer()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .onReachEnd(() => {
        this.loadMore();
      })
      .scrollBar(BarState.Off)
    } else {
      List({ scroller: this.scroller }) {
        ForEach(this.feedItems, (item: FeedItem, idx: number) => {
          ListItem() {
            this.activityCard(item)
          }
          .onClick(() => {
            this.openFeed(item);
          })
        }, (item: FeedItem, idx: number) => String(idx) + '-' + item.id + '-' + item.type)
        ListItem() {
          this.footer()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .onReachEnd(() => {
        this.loadMore();
      })
      .padding({ left: 12, right: 12, top: 8 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  emptyOrError() {
    if (this.listError.length > 0 && !this.hasAnyItem()) {
      Column({ space: 12 }) {
        Text(this.listError).fontSize(14).fontColor(ZhihuColors.textSecondary)
        Button('重试')
          .fontSize(14)
          .backgroundColor(ZhihuColors.primary)
          .onClick(() => {
            this.loadTabFirst();
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (!this.loadingList && !this.loadingMore && !this.hasAnyItem()) {
      Column() {
        Text('暂无内容').fontSize(14).fontColor(ZhihuColors.textTertiary)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
  }

  build() {
    Column() {
      if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
          Text('加载中…').fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 || !this.member) {
        Column({ space: 16 }) {
          Text(this.error.length > 0 ? this.error : '用户不存在')
            .fontSize(14).fontColor(ZhihuColors.textSecondary)
          Button('重试')
            .fontSize(14)
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loadMember();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        this.headerBlock()
        this.tabBar()
        this.contentList()
        this.emptyOrError()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
