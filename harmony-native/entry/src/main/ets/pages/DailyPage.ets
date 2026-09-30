/**
 * pages/DailyPage —— 日报流（按天分段显示）。
 * 结构：最新一期 header（9月30日 日报）+ 每期独立分段 header + 故事卡。
 * 下拉刷新加载最新一期，上拉加载更早一期（追加为新分段）。
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
import { cacheWrite, cacheRead, CACHE_TWO_DAYS_MS, DailyCachePayload, writeContentCache } from '../utils/cacheStore';
import { getDailyDetail } from '../api/daily';

/** 一期日报：日期 + 该期故事 */
interface DailySection {
  date: string; // YYYYMMDD
  stories: DailyStory[];
}

@Component
export struct DailyPage {
  @State sections: DailySection[] = [];
  @State latestDate: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State refreshing: boolean = false;
  @State loadingMore: boolean = false;
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadLatest();
  }

  /** 本地今天的 YYYYMMDD */
  private todayStr(): string {
    const d = new Date();
    const m: string = (d.getMonth() + 1).toString().padStart(2, '0');
    const day: string = d.getDate().toString().padStart(2, '0');
    return String(d.getFullYear()) + m + day;
  }

  private totalCount(): number {
    let n: number = 0;
    this.sections.forEach((sec: DailySection) => {
      n += sec.stories.length;
    });
    return n;
  }

  async loadLatest(): Promise<void> {
    // 缓存恰好是今天的 → 秒开，无需联网
    if (this.loadDailyCache(this.todayStr())) {
      this.loading = false;
      this.inFlight = false;
      return;
    }
    this.loading = true;
    this.error = '';
    this.inFlight = true;
    try {
      const resp = await getDailyLatest();
      this.latestDate = resp.date ?? '';
      this.sections = [{ date: this.latestDate, stories: resp.stories ?? [] }];
      this.error = this.totalCount() === 0 ? '本期日报暂无内容' : '';
      this.saveDailyCache();
      this.preCacheStories();
    } catch (e) {
      // 离线/失败：优先读两天内缓存兜底（可能是旧日期）
      if (this.loadDailyCache('')) {
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
      this.latestDate = resp.date ?? '';
      this.sections = [{ date: this.latestDate, stories: resp.stories ?? [] }];
      this.saveDailyCache();
      this.preCacheStories();
      this.error = '';
    } catch (e) {
      // 刷新失败保留旧内容
    } finally {
      this.refreshing = false;
    }
  }

  async loadBefore(): Promise<void> {
    if (this.inFlight || this.loadingMore || this.sections.length === 0) {
      return;
    }
    const oldest: string = this.sections[this.sections.length - 1].date;
    if (oldest.length === 0) {
      return;
    }
    this.loadingMore = true;
    this.inFlight = true;
    try {
      const resp = await getDailyBefore(oldest);
      const older: DailyStory[] = resp.stories ?? [];
      const existing = new Set<number>();
      this.sections.forEach((sec: DailySection) => {
        sec.stories.forEach((s: DailyStory) => {
          existing.add(s.id);
        });
      });
      const fresh: DailyStory[] = [];
      older.forEach((s: DailyStory) => {
        if (!existing.has(s.id)) {
          fresh.push(s);
        }
      });
      if (fresh.length > 0) {
        const next: DailySection[] = this.sections.slice();
        next.push({ date: resp.date && resp.date.length === 8 ? resp.date : oldest, stories: fresh });
        this.sections = next;
      }
    } catch (e) {
      // 加载更早失败保留已加载内容
    } finally {
      this.loadingMore = false;
      this.inFlight = false;
    }
  }

  /** 日报成功后写两天缓存（以最新一期为主） */
  private saveDailyCache(): void {
    if (this.sections.length === 0) {
      return;
    }
    const payload: DailyCachePayload = {
      savedAt: Date.now(),
      date: this.latestDate,
      stories: this.sections[0].stories.slice(),
    };
    cacheWrite('daily_cache_v2', payload);
  }

  /** 后台预缓存日报所有文章详情 */
  private preCacheStories(): void {
    const all: DailyStory[] = [];
    this.sections.forEach((sec: DailySection) => {
      sec.stories.forEach((s: DailyStory) => {
        all.push(s);
      });
    });
    const doCache = async (idx: number): Promise<void> => {
      if (idx >= all.length) {
        return;
      }
      const sid: string = String(all[idx].id ?? '');
      if (sid.length === 0) {
        await doCache(idx + 1);
        return;
      }
      try {
        const d = await getDailyDetail(sid);
        writeContentCache('daily', sid, d as object);
      } catch (e) {
        // 静默失败
      }
      await doCache(idx + 1);
    };
    doCache(0).catch(() => {});
  }

  /** 日报离线：读两天内缓存，成功返回 true；today 非空时仅接受当天缓存 */
  private loadDailyCache(today: string): boolean {
    const cached = cacheRead<DailyCachePayload>('daily_cache_v2', CACHE_TWO_DAYS_MS);
    if (cached === null || cached.stories === undefined || cached.stories.length === 0) {
      return false;
    }
    if (today.length > 0 && (cached.date ?? '') !== today) {
      return false;
    }
    const list: DailyStory[] = [];
    cached.stories.forEach((raw: object) => {
      const st = raw as DailyStory;
      if (st !== null && st !== undefined) {
        list.push(st);
      }
    });
    this.latestDate = cached.date ?? '';
    this.sections = [{ date: this.latestDate, stories: list }];
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
  sectionHeader(sec: DailySection, isLatest: boolean) {
    Row({ space: 8 }) {
      Row()
        .width(4)
        .height(16)
        .borderRadius(2)
        .backgroundColor(isLatest ? ZhihuColors.primary : ZhihuColors.textTertiary)
      Text(formatDailyDate(sec.date) + (isLatest ? ' 日报' : ' 日报'))
        .fontSize(15)
        .fontWeight(isLatest ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(isLatest ? ZhihuColors.primary : ZhihuColors.textSecondary)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 4 })
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
      } else if (this.totalCount() > 0) {
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
      Text(this.latestDate.length > 0 ? formatDailyDate(this.latestDate) + ' 日报' : '日报')
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
            ForEach(this.sections, (sec: DailySection, si: number) => {
              ListItem() {
                this.sectionHeader(sec, si === 0)
              }
              ForEach(sec.stories, (item: DailyStory) => {
                ListItem() {
                  this.storyRow(item)
                }
              }, (item: DailyStory) => String(item.id))
            }, (sec: DailySection, si: number) => String(si) + '-' + sec.date)
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
      if (this.loading && this.totalCount() === 0) {
        Column({ space: 8 }) {
          LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
          Text('日报加载中…')
        }
      }

      // 错误态（无数据时）
      if (this.error.length > 0 && this.totalCount() === 0) {
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
