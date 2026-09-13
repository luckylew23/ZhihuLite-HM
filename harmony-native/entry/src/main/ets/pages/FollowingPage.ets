/**
 * pages/FollowingPage —— 首页「关注」Tab。
 * 结构对齐上游 zhihu-- v0.6.0：
 *   顶部「最近更新」头像横排（圆形头像 + 红色未读角标）
 *   下方关注动态流卡片：
 *     类型行(actionText 灰色小字) + 作者名(粗体) + 问题标题(粗体可点)
 *     + 正文摘要 + 图片(如有) + 计数行(▲赞同 ○评论 ☆收藏)
 *   底部「已看完本次更新」。
 *
 * 数据：
 *   头像横排 → api/moments.ts fetchRecentMoments（未登录/失败时横排整体隐藏，优雅降级）
 *   动态流   → api/feed.ts getFeed(FEED_URLS.following) + api/feedParser.ts parseFollowingData
 */

import { router } from '@kit.ArkUI';
import {
  getFeed,
  FeedItem,
  FEED_URLS,
  ZhihuFeedResponse,
} from '../api/feed';
import { parseFollowingData } from '../api/feedParser';
import {
  fetchRecentMoments,
  RecentMomentItem,
} from '../api/moments';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';

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
export struct FollowingPage {
  @State recentItems: RecentMomentItem[] = [];
  @State items: FeedItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;
  private nextUrl: string = '';
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();
  private railScroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadRecent();
    this.loadFirst();
  }

  /** 「最近更新」头像横排：失败/无数据时整体不渲染（降级） */
  private async loadRecent(): Promise<void> {
    try {
      const resp = await fetchRecentMoments();
      this.recentItems = (resp && resp.data) ? resp.data : [];
    } catch (e) {
      this.recentItems = [];
    }
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
      const resp = await getFeed(FEED_URLS.following, authStore.cookies);
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
      const resp = await getFeed(
        this.appendActionUp(FEED_URLS.following),
        authStore.cookies,
      );
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
    const list: FeedItem[] = [];
    resp.data.forEach((raw) => {
      const item = parseFollowingData(raw);
      if (item) {
        list.push(item);
      }
    });
    this.items = replace ? list : this.items.concat(list);
  }

  private openDetail(item: FeedItem): void {
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
    } else {
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

  @Builder
  recentRail() {
    if (this.recentItems.length > 0) {
      Column({ space: 8 }) {
        Text('最近更新')
          .fontSize(14)
          .fontColor(ZhihuColors.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Start)
        List({ scroller: this.railScroller }) {
          ForEach(
            this.recentItems,
            (r: RecentMomentItem) => {
              ListItem() {
                Column({ space: 4 }) {
                  Stack({ alignContent: Alignment.TopEnd }) {
                    Image(r.actor.avatar_url)
                      .width(48)
                      .height(48)
                      .borderRadius(24)
                      .objectFit(ImageFit.Cover)
                      .backgroundColor(ZhihuColors.backgroundTertiary)
                    if (r.unread_count > 0) {
                      Text(r.unread_count > 99 ? '99+' : String(r.unread_count))
                        .fontSize(9)
                        .fontColor(ZhihuColors.textInverse)
                        .backgroundColor(ZhihuColors.danger)
                        .borderRadius(8)
                        .textAlign(TextAlign.Center)
                        .width(16)
                        .height(16)
                        .offset({ x: 4, y: -2 })
                    }
                  }
                  .width(48)
                  .height(48)
                  Text(r.actor.name)
                    .fontSize(12)
                    .fontColor(ZhihuColors.textSecondary)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width(52)
                    .textAlign(TextAlign.Center)
                }
                .width(56)
              }
            },
            (r: RecentMomentItem) => (r.actor.id || '') + '-' + (r.brief ?? ''),
          )
        }
        .listDirection(Axis.Horizontal)
        .height(78)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 4 })
      .backgroundColor(ZhihuColors.backgroundSecondary)
    }
  }

  @Builder
  momentCard(item: FeedItem) {
    Column({ space: 6 }) {
      // 类型行（「回答了问题」/「发布了想法」灰色小字）——无动作文案时整行不渲染
      if (item.actionText && item.actionText.length > 0) {
        Text(item.actionText)
          .fontSize(13)
          .fontColor(ZhihuColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      // 作者名（粗体）
      Text(item.author.name)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(ZhihuColors.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Start)
      // 问题标题（粗体可点）
      if (item.title.length > 0) {
        Text(item.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.text)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      // 正文摘要
      if (item.excerpt.length > 0) {
        Text(item.excerpt)
          .fontSize(15)
          .fontColor(ZhihuColors.textSecondary)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
          .lineHeight(21)
      }
      // 图片（如有）——无图时不渲染
      if (item.image && item.image.length > 0) {
        Image(item.image)
          .width('100%')
          .height(180)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
      }
      // 计数行：▲赞同 ○评论 ☆收藏
      Row({ space: 18 }) {
        Row({ space: 4 }) {
          Text('▲')
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
          Text(formatCount(item.voteCount))
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
        }
        Row({ space: 4 }) {
          Text('○')
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
          Text(formatCount(item.commentCount))
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
        }
        Row({ space: 4 }) {
          Text('☆')
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
          Text(formatCount(item.favlistsCount ?? 0))
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
        }
      }
      .width('100%')
      .margin({ top: 2 })
    }
    .padding(12)
    .width('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .borderRadius(8)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18).color(ZhihuColors.textTertiary)
          Text('加载中…')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(12)
      } else if (this.isEnd && this.items.length > 0) {
        Text('— 已看完本次更新 —')
          .fontSize(14)
          .fontColor(ZhihuColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(16)
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        this.recentRail()
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 10, scroller: this.scroller }) {
            ForEach(
              this.items,
              (item: FeedItem) => {
                ListItem() {
                  this.momentCard(item)
                }
                .onClick(() => {
                  this.openDetail(item);
                })
              },
              (item: FeedItem) => item.id + '-' + item.type,
            )
            ListItem() {
              this.footer()
            }
          }
          .onReachEnd(() => {
            this.loadMore();
          })
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 10, bottom: 12 })
          .scrollBar(BarState.Off)
          .width('100%')
        }
        .onRefreshing(() => {
          this.refresh();
        })
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')

      // 首屏加载
      if (this.loading && this.items.length === 0) {
        Column({ space: 8 }) {
          LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
          Text('加载中…')
        }
      }

      // 错误态（无数据时）
      if (this.error.length > 0 && this.items.length === 0) {
        Column({ space: 16 }) {
          Text(this.error)
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
