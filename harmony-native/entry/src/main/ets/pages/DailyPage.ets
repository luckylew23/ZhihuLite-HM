/**
 * pages/DailyPage —— 日报流（对齐上游 components/DailyList.tsx）。
 * 仅作为 Index 首页组 "daily" 栏目的内嵌组件（非路由页）。
 * 结构：日期分隔行 + 故事卡（缩略图 / 标题 / hint）。
 * 下拉刷新加载最新一期，上拉加载更早一期。
 */

import { router } from '@kit.ArkUI';
import { NetImage } from '../components/NetImage';
import {
  DailyStory,
  getDailyLatest,
  getDailyBefore,
  formatDailyDate,
} from '../api/daily';
import { ZhihuColors } from '../utils/theme';
import { cacheWrite, cacheRead, CACHE_TWO_DAYS_MS, DailyCachePayload } from '../utils/cacheStore';

@Component
export struct DailyPage {
  @State stories: DailyStory[] = [];
  @State date: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadLatest();
  }

  async loadLatest(): Promise<void> {
    // 先读缓存即时展示
    if (this.loadDailyCache()) {
      this.loading = false;
      this.inFlight = false;
      // 后台静默刷新
      this.refresh();
      return;
    }
    this.loading = true;
    this.error = '';
    this.inFlight = true;
    try {
      const resp = await getDailyLatest();
      this.date = resp.date ?? '';
      this.stories = resp.stories ?? [];
      this.error = this.stories.length === 0 ? '本期日报暂无内容' : '';
      this.saveDailyCache();
    } catch (e) {
      // 离线/失败：优先读两天内缓存
      if (this.loadDailyCache()) {
        this.error = '';
      } else {
        let detail = '网络异常';
        if (e instanceof Error && e.message) {
          detail = e.message;
        }
        this.error = '日报加载失败：' + detail;
      }
    } finally {
      this.loading = false;
      this.inFlight = false;
    }
  }

  async refresh(): Promise<void> {
    this.refreshing = true;
    try {
      const resp = await getDailyLatest();
      this.date = resp.date ?? '';
      this.stories = resp.stories ?? [];
      this.saveDailyCache();
      this.error = '';
    } catch (e) {
      // 刷新失败保留旧内容
    } finally {
      this.refreshing = false;
    }
  }

  async loadBefore(): Promise<void> {
    if (this.inFlight || this.loadingMore || this.date.length === 0) {
      return;
    }
    this.loadingMore = true;
    this.inFlight = true;
    try {
      const resp = await getDailyBefore(this.date);
      const older: DailyStory[] = resp.stories ?? [];
      const existing = new Set<number>();
      this.stories.forEach((s: DailyStory) => {
        existing.add(s.id);
      });
      const merged: DailyStory[] = this.stories.slice();
      older.forEach((s: DailyStory) => {
        if (!existing.has(s.id)) {
          merged.push(s);
        }
      });
      this.stories = merged;
      if (resp.date && resp.date.length === 8) {
        this.date = resp.date;
      }
    } catch (e) {
      // 加载更早失败保留已加载内容
    } finally {
      this.loadingMore = false;
      this.inFlight = false;
    }
  }

  /** 日报成功后写两天缓存 */
  private saveDailyCache(): void {
    const stories = this.stories.slice();
    const payload: DailyCachePayload = { savedAt: Date.now(), date: this.date, stories: stories };
    cacheWrite('daily_cache_v2', payload);
  }

  /** 日报离线：读两天内缓存，成功返回 true */
  private loadDailyCache(): boolean {
    const cached = cacheRead<DailyCachePayload>('daily_cache_v2', CACHE_TWO_DAYS_MS);
    if (cached === null || cached.stories === undefined || cached.stories.length === 0) {
      return false;
    }
    const list: DailyStory[] = [];
    cached.stories.forEach((raw: object) => {
      const st = raw as DailyStory;
      if (st !== null && st !== undefined) {
        list.push(st);
      }
    });
    this.date = cached.date ?? '';
    this.stories = list;
    return true;
  }

  private openStory(story: DailyStory): void {
    router.pushUrl({
      url: 'pages/DailyDetailPage',
      params: { id: String(story.id), title: story.title ?? '' },
    });
  }

  @Builder
  storyRow(item: DailyStory) {
    Row({ space: 12 }) {
      // 缩略图（无图时占位色块）
      if (item.images && item.images.length > 0 && item.images[0].length > 0) {
        NetImage({ url: item.images[0], w: 88, h: 88, r: 10 })
      } else if (item.image && item.image.length > 0) {
        NetImage({ url: item.image, w: 88, h: 88, r: 10 })
      } else {
        Row()
          .width(88)
          .height(88)
          .borderRadius(10)
          .backgroundColor(ZhihuColors.backgroundTertiary)
      }
      Column({ space: 6 }) {
        Text(item.title ?? '')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (item.hint && item.hint.length > 0) {
          Text(item.hint)
            .fontSize(14)
            .fontColor(ZhihuColors.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .borderRadius(12)
    .onClick(() => {
      this.openStory(item);
    })
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18).color(ZhihuColors.textTertiary)
          Text('加载更早…')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(12)
      } else if (this.stories.length > 0) {
        Text('— 已加载全部日报 —')
          .fontSize(15)
          .fontColor(ZhihuColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(12)
      }
    }
  }

  @Builder
  dateHeader() {
    Row() {
      Text(this.date.length > 0 ? formatDailyDate(this.date) + ' 日报' : '日报')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(ZhihuColors.primary)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 4 })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Refresh({ refreshing: $$this.refreshing }) {
        Column() {
          this.dateHeader()
          List({ space: 8, scroller: this.scroller }) {
            ForEach(this.stories, (item: DailyStory, idx: number) => {
              ListItem() {
                this.storyRow(item)
              }
            }, (item: DailyStory, idx: number) => String(idx) + '-' + String(item.id))
            ListItem() {
              this.footer()
            }
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 12 })
          .onReachEnd(() => {
            this.loadBefore();
          })
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .height('100%')
      }
      .onRefreshing(() => {
        this.refresh();
      })
      .width('100%')
      .height('100%')

      // 首屏加载
      if (this.loading && this.stories.length === 0) {
        Column({ space: 8 }) {
          LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
          Text('日报加载中…')
        }
      }

      // 错误态（无数据时）
      if (this.error.length > 0 && this.stories.length === 0) {
        Column({ space: 16 }) {
          Text(this.error)
            .fontSize(16)
            .fontColor(ZhihuColors.textSecondary)
          Button('重试')
            .fontSize(16)
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loadLatest();
            })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
