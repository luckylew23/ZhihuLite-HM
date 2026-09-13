/**
 * pages/FeedListPage —— 通用 Feed 列表页。
 * feedMode: 'recommend' | 'following' | 'hot' | 'daily'
 * 支持下拉刷新、上拉分页、首屏加载/错误态。
 */

import { router } from '@kit.ArkUI';
import {
  getFeed,
  FeedItem,
  FEED_URLS,
  ZhihuFeedResponse,
} from '../api/feed';
import {
  parseRecommendData,
  parseFollowingData,
  parseHotData,
  HotItem,
} from '../api/feedParser';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { FeedCard } from '../components/FeedCard';
import { HotCard } from '../components/HotCard';

@Component
export struct FeedListPage {
  @Prop feedMode: string = 'recommend';
  @State items: FeedItem[] = [];
  @State hotItems: HotItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;
  private nextUrl: string = '';
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadFirst();
  }

  private isHot(): boolean {
    return this.feedMode === 'hot';
  }

  private entryUrl(): string {
    if (this.feedMode === 'following') {
      return FEED_URLS.following;
    }
    if (this.feedMode === 'hot') {
      return FEED_URLS.hot;
    }
    if (this.feedMode === 'daily') {
      return FEED_URLS.daily;
    }
    return FEED_URLS.recommend;
  }

  private appendActionUp(url: string): string {
    const sep = url.includes('?') ? '&' : '?';
    return url + sep + 'action=up&t=' + String(Date.now());
  }

  async loadFirst(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.inFlight = true;
    try {
      const resp = await getFeed(this.entryUrl(), authStore.cookies);
      this.applyPage(resp, true);
    } catch (e) {
      let detail = '网络异常';
      if (e instanceof Error && e.message) {
        detail = e.message;
      }
      this.error = '加载失败：' + detail;
    } finally {
      this.loading = false;
      this.inFlight = false;
    }
  }

  async refresh(): Promise<void> {
    this.refreshing = true;
    try {
      const url = this.isHot() ? this.entryUrl() : this.appendActionUp(this.entryUrl());
      const resp = await getFeed(url, authStore.cookies);
      this.applyPage(resp, true);
      this.error = '';
    } catch (e) {
      // 刷新失败保留旧列表
    } finally {
      this.refreshing = false;
    }
  }

  async loadMore(): Promise<void> {
    if (this.inFlight || this.isEnd || this.nextUrl.length === 0) {
      return;
    }
    this.inFlight = true;
    this.loadingMore = true;
    try {
      const resp = await getFeed(this.nextUrl, authStore.cookies);
      this.applyPage(resp, false);
    } catch (e) {
      // 翻页失败保留已加载内容
    } finally {
      this.inFlight = false;
      this.loadingMore = false;
    }
  }

  private applyPage(resp: ZhihuFeedResponse, replace: boolean): void {
    this.nextUrl = resp.paging?.next ?? '';
    this.isEnd = resp.paging?.is_end ?? true;
    if (this.isHot()) {
      const hot: HotItem[] = [];
      resp.data.forEach((raw, idx: number) => {
        const parsed = parseHotData(raw, idx);
        if (parsed) {
          hot.push(parsed);
        }
      });
      this.hotItems = replace ? hot : this.hotItems.concat(hot);
    } else {
      const list: FeedItem[] = [];
      resp.data.forEach((raw) => {
        const item = this.feedMode === 'following'
          ? parseFollowingData(raw)
          : parseRecommendData(raw);
        if (item) {
          list.push(item);
        }
      });
      this.items = replace ? list : this.items.concat(list);
    }
  }

  private openDetail(item: FeedItem): void {
    // 按 feed 类型分发到新详情页
    const t: string = item.type;
    if (t === 'questions') {
      router.pushUrl({
        url: 'pages/QuestionDetailPage',
        params: { id: item.questionId ?? item.id },
      });
    } else if (t === 'answers') {
      router.pushUrl({
        url: 'pages/AnswerDetailPage',
        params: { id: item.id },
      });
    } else if (t === 'articles') {
      router.pushUrl({
        url: 'pages/ArticleDetailPage',
        params: { id: item.id },
      });
    } else if (t === 'pins') {
      router.pushUrl({
        url: 'pages/PinDetailPage',
        params: { id: item.id },
      });
    } else if (t === 'videos') {
      router.pushUrl({
        url: 'pages/VideoPage',
        params: {
          id: item.id,
          title: item.title ?? '',
          author: item.author?.name ?? '',
          description: item.excerpt ?? '',
        },
      });
    } else {
      // 无法识别类型保留跳旧 DetailPage
      router.pushUrl({
        url: 'pages/DetailPage',
        params: {
          id: item.id,
          type: item.type,
          title: item.title,
          excerpt: item.excerpt,
          url: item.url ?? '',
          questionId: item.questionId ?? '',
        },
      });
    }
  }

  private openHotDetail(item: HotItem): void {
    // v1.3.0：热榜条目均为问题，直接跳原生问题详情页（不再走旧 DetailPage/浏览器）
    router.pushUrl({
      url: 'pages/QuestionDetailPage',
      params: { id: item.questionId.length > 0 ? item.questionId : item.id },
    });
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18).color(ZhihuColors.textTertiary)
          Text('加载中…')
            .copyOption(CopyOptions.LocalDevice).fontSize(14).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(12)
      } else if (this.isEnd && (this.items.length > 0 || this.hotItems.length > 0)) {
        Text('— 没有更多了 —')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(14)
          .fontColor(ZhihuColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(12)
      }
    }
  }

  @Builder
  searchHeader() {
    Row({ space: 8 }) {
      Text('🔍')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(16)
        .fontColor(ZhihuColors.textTertiary)
      Text('搜索知乎')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(15)
        .fontColor(ZhihuColors.textTertiary)
        .layoutWeight(1)
    }
    .width('100%')
    .height(40)
    .padding({ left: 12, right: 12 })
    .backgroundColor(ZhihuColors.backgroundTertiary)
    .borderRadius(20)
    .margin({ left: 12, right: 12, top: 8, bottom: 4 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/SearchPage' });
    })
  }

  @Builder
  feedListNormal() {
    Refresh({ refreshing: $$this.refreshing }) {
      Column() {
        this.searchHeader()
        List({ space: 10, scroller: this.scroller }) {
        ForEach(this.items, (item: FeedItem, index: number) => {
          ListItem() {
            FeedCard({ item: item })
          }
          .onClick(() => {
            this.openDetail(item);
          })
        }, (item: FeedItem, index: number) => String(index) + '-' + item.id + '-' + item.type)
        ListItem() {
          this.footer()
        }
      }
      .onReachEnd(() => {
        this.loadMore();
      })
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .scrollBar(BarState.Off)
      }
      }
      .onRefreshing(() => {
        this.refresh();
      })
      .width('100%')
      .height('100%')
  }

  @Builder
  feedListHot() {
    Refresh({ refreshing: $$this.refreshing }) {
      Column() {
        this.searchHeader()
        List({ space: 6, scroller: this.scroller }) {
        ForEach(this.hotItems, (item: HotItem, index: number) => {
          ListItem() {
            HotCard({ item: item })
          }
          .onClick(() => {
            this.openHotDetail(item);
          })
        }, (item: HotItem, index: number) => String(index) + '-' + item.id)
        ListItem() {
          this.footer()
        }
      }
      .onReachEnd(() => {
        this.loadMore();
      })
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .scrollBar(BarState.Off)
      }
      }
      .onRefreshing(() => {
        this.refresh();
      })
      .width('100%')
      .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isHot()) {
        this.feedListHot()
      } else {
        this.feedListNormal()
      }

      // 首屏加载
      if (this.loading && this.items.length === 0 && this.hotItems.length === 0) {
        Column({ space: 8 }) {
          LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
          Text('加载中…')
            .copyOption(CopyOptions.LocalDevice).fontSize(14).fontColor(ZhihuColors.textTertiary)
        }
      }

      // 错误态（无数据时）
      if (this.error.length > 0 && this.items.length === 0 && this.hotItems.length === 0) {
        Column({ space: 16 }) {
          Text(this.error)
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(15)
            .fontColor(ZhihuColors.textSecondary)
          Button('重试')
            .fontSize(15)
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loadFirst();
            })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
