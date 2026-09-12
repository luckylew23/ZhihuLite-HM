/**
 * pages/UserLikesPage —— 我赞过的内容（回答/文章）。
 * 上游：app/user/likes.tsx。
 */

import { router } from '@kit.ArkUI';
import { getMyLikes } from '../api/me';
import { ZhihuMemberRelation } from '../model/zhihu';
import { FeedItem } from '../api/feed';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { FeedCard } from '../components/FeedCard';
import { ProfileTopBar } from '../components/profile/ProfileTopBar';
import { relationToFeedItem, feedDetailUrl } from '../components/profile/profileMappers';

@Entry
@Component
export struct UserLikesPage {
  @State activeTab: string = 'answers';
  @State items: FeedItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;
  @State loggedIn: boolean = false;

  pageOffset: number = 0;
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loggedIn = authStore.isLoggedIn;
    if (this.loggedIn) {
      this.loadFirst();
    } else {
      this.loading = false;
    }
  }

  async switchTab(key: string): Promise<void> {
    if (key === this.activeTab) {
      return;
    }
    this.activeTab = key;
    await this.loadFirst();
  }

  async loadFirst(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.items = [];
    this.pageOffset = 0;
    this.isEnd = false;
    await this.fetchPage(true);
    this.loading = false;
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
    this.inFlight = true;
    try {
      const resp = await getMyLikes(
        this.activeTab === 'articles' ? 'articles' : 'answers',
        20,
        this.pageOffset,
      );
      const list: FeedItem[] = [];
      for (const rel of resp.data) {
        list.push(relationToFeedItem(rel as ZhihuMemberRelation));
      }
      this.items = reset ? list : this.items.concat(list);
      this.isEnd = resp.paging.is_end;
      this.pageOffset = this.pageOffset + 20;
    } catch (e) {
      this.error = '点赞内容加载失败';
    } finally {
      this.inFlight = false;
    }
  }

  private openDetail(item: FeedItem): void {
    router.pushUrl({
      url: feedDetailUrl(item),
      params: { id: item.id, questionId: item.questionId ?? '' },
    });
  }

  @Builder
  guestView() {
    Column({ space: 16 }) {
      Blank()
      Text('登录后才能查看我赞过的内容')
        .fontSize(14)
        .fontColor(ZhihuColors.textSecondary)
      Button('登录知乎')
        .width(220)
        .height(44)
        .backgroundColor(ZhihuColors.primary)
        .onClick(() => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  tabBar() {
    Row() {
      this.tabItem('回答')
      this.tabItem('文章')
    }
    .width('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .border({ width: 0.5, color: ZhihuColors.border })
  }

  @Builder
  tabItem(key: string) {
    Text(key)
      .fontSize(15)
      .fontWeight(this.activeTab === (key === '文章' ? 'articles' : 'answers')
        ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.activeTab === (key === '文章' ? 'articles' : 'answers')
        ? ZhihuColors.primary : ZhihuColors.iconMuted)
      .padding({ top: 14, bottom: 14 })
      .layoutWeight(1)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        this.switchTab(key === '文章' ? 'articles' : 'answers');
      })
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18).color(ZhihuColors.textTertiary)
          Text('加载中…').fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center).width('100%').padding(12)
      } else if (this.isEnd && this.items.length > 0) {
        Text('— 没有更多了 —')
          .fontSize(13).fontColor(ZhihuColors.textTertiary)
          .width('100%').textAlign(TextAlign.Center).padding(12)
      }
    }
  }

  build() {
    Column() {
      ProfileTopBar({ title: '我的点赞' })
      if (!this.loggedIn) {
        this.guestView()
      } else {
        this.tabBar()
        if (this.loading) {
          Column({ space: 8 }) {
            LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
            Text('加载中…').fontSize(13).fontColor(ZhihuColors.textTertiary)
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.error.length > 0 && this.items.length === 0) {
          Column({ space: 16 }) {
            Text(this.error).fontSize(14).fontColor(ZhihuColors.textSecondary)
            Button('重试')
              .fontSize(14)
              .backgroundColor(ZhihuColors.primary)
              .onClick(() => {
                this.loadFirst();
              })
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.items.length === 0) {
          Column() {
            Text('还没有点赞过内容').fontSize(14).fontColor(ZhihuColors.textTertiary)
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List({ scroller: this.scroller }) {
            ForEach(this.items, (item: FeedItem, idx: number) => {
              ListItem() {
                FeedCard({ item: item })
              }
              .onClick(() => {
                this.openDetail(item);
              })
            }, (item: FeedItem, idx: number) => String(idx) + '-' + item.id)
            ListItem() {
              this.footer()
            }
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 12, right: 12 })
          .onReachEnd(() => {
            this.loadMore();
          })
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
