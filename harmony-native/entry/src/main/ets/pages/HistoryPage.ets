/**
 * pages/HistoryPage —— 浏览历史列表 + 批量删除。
 * 上游：app/history.tsx。
 * 长按进入多选；右上角清空；底部"删除选中"。
 */

import { router, promptAction } from '@kit.ArkUI';
import {
  ReadHistoryDataItem,
  AddReadHistoryPayload,
  ReadHistoryContentType,
  getReadHistory,
  batchDelReadHistory,
} from '../api/history';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { formatDate } from '../utils/date';
import { ProfileTopBar } from '../components/profile/ProfileTopBar';
import { ReadHistoryExtra } from '../api/history';

/** 最近两天（秒）——默认加载范围；read_time 为秒级时间戳 */
const RECENT_TWO_DAYS_S: number = 2 * 24 * 3600;

@Entry
@Component
export struct HistoryPage {
  @State items: ReadHistoryDataItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;
  @State loggedIn: boolean = false;
  @State filteredEmpty: boolean = false;
  @State selecting: boolean = false;
  @State selectedKeys: string[] = [];

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
      const resp = await getReadHistory(20, this.pageOffset);
      const list: ReadHistoryDataItem[] = [];
      // 逐条防护：null 条目/结构残缺只跳过该条，不拖垮整页
      for (const raw of resp.data) {
        if (raw === undefined || raw === null) {
          continue;
        }
        try {
          const d = raw.data;
          if (d === undefined || d === null) {
            continue;
          }
          list.push(raw);
        } catch (e) {
          console.error('[ZhihuLite] history item skip: ' + String(e));
        }
      }
      // 默认加载最近两天（reset 首屏过滤）；翻页（loadMore）继续追加更早记录
      if (reset) {
        const recent: ReadHistoryDataItem[] = [];
        for (const it of list) {
          if (this.isWithinTwoDays(it)) {
            recent.push(it);
          }
        }
        this.items = recent;
        this.filteredEmpty = list.length > 0 && recent.length === 0;
      } else {
        this.items = this.items.concat(list);
      }
      this.isEnd = resp.paging.is_end;
      this.pageOffset = this.pageOffset + 20;
    } catch (e) {
      console.error('[ZhihuLite] history load failed: ' + String(e));
      this.error = '浏览历史加载失败';
    } finally {
      this.inFlight = false;
    }
  }

  /** read_time（秒）是否落在最近两天内 */
  private isWithinTwoDays(item: ReadHistoryDataItem): boolean {
    const extra = this.safeExtra(item);
    if (extra === null || extra.read_time <= 0) {
      return false;
    }
    const ageS: number = Date.now() / 1000 - extra.read_time;
    return ageS >= 0 && ageS <= RECENT_TWO_DAYS_S;
  }

  private safeExtra(item: ReadHistoryDataItem): ReadHistoryExtra | null {
    if (item === null || item === undefined) {
      return null;
    }
    const d = item.data;
    if (d === null || d === undefined || d.extra === null || d.extra === undefined) {
      return null;
    }
    return d.extra;
  }

  private safeTitle(item: ReadHistoryDataItem): string {
    if (item === null || item === undefined) {
      return '';
    }
    const d = item.data;
    if (d === null || d === undefined || d.header === null || d.header === undefined) {
      return '';
    }
    return d.header.title || '';
  }

  private safeSummary(item: ReadHistoryDataItem): string {
    if (item === null || item === undefined) {
      return '';
    }
    const d = item.data;
    if (d === null || d === undefined || d.content === null || d.content === undefined) {
      return '';
    }
    return d.content.summary || '';
  }

  private safeMatrixText(item: ReadHistoryDataItem): string {
    if (item === null || item === undefined) {
      return '';
    }
    const d = item.data;
    if (d === null || d === undefined || d.matrix === null || d.matrix === undefined ||
      d.matrix.length === 0) {
      return '';
    }
    const m0 = d.matrix[0];
    if (m0 === null || m0 === undefined || m0.data === null || m0.data === undefined) {
      return '';
    }
    return m0.data.text || '';
  }

  private safeReadTime(item: ReadHistoryDataItem): number {
    const extra = this.safeExtra(item);
    return extra !== null ? extra.read_time : 0;
  }

  private makeKey(item: ReadHistoryDataItem): string {
    const extra = this.safeExtra(item);
    return (extra !== null ? extra.content_type : 'unknown') + '-' +
      (extra !== null ? extra.content_token : '');
  }

  private isSelected(key: string): boolean {
    return this.selectedKeys.indexOf(key) >= 0;
  }

  private toggleSelect(key: string): void {
    const next: string[] = [];
    for (const k of this.selectedKeys) {
      next.push(k);
    }
    const idx = next.indexOf(key);
    if (idx >= 0) {
      next.splice(idx, 1);
    } else {
      next.push(key);
    }
    this.selectedKeys = next;
  }

  private exitSelection(): void {
    this.selecting = false;
    this.selectedKeys = [];
  }

  private openItem(item: ReadHistoryDataItem): void {
    const key = this.makeKey(item);
    if (this.selecting) {
      this.toggleSelect(key);
      return;
    }
    const extra = this.safeExtra(item);
    if (extra === null) {
      promptAction.showToast({ message: '记录不完整' });
      return;
    }
    const type = extra.content_type;
    const token = extra.content_token;
    if (type === 'profile') {
      router.pushUrl({ url: 'pages/PeoplePage', params: { urlToken: token } });
      return;
    }
    if (type === 'article') {
      router.pushUrl({ url: 'pages/ArticleDetailPage', params: { id: token } });
    } else if (type === 'pin') {
      router.pushUrl({ url: 'pages/PinDetailPage', params: { id: token } });
    } else if (type === 'question') {
      router.pushUrl({ url: 'pages/QuestionDetailPage', params: { id: token } });
    } else {
      router.pushUrl({ url: 'pages/AnswerDetailPage', params: { id: token } });
    }
  }

  private handleDeleteSelected(): void {
    if (this.selectedKeys.length === 0) {
      return;
    }
    const pairs: AddReadHistoryPayload[] = [];
    for (const key of this.selectedKeys) {
      const sep = key.indexOf('-');
      const type = key.substring(0, sep);
      const token = key.substring(sep + 1);
      pairs.push({ content_token: token, content_type: type as ReadHistoryContentType });
    }
    AlertDialog.show({
      message: '确定要删除选中的 ' + String(pairs.length) + ' 条记录吗？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        fontColor: '#ff4d4f',
        action: () => {
          batchDelReadHistory({ pairs: pairs, clear: false })
            .then(() => {
              this.exitSelection();
              this.loadFirst();
            })
            .catch(() => {
              promptAction.showToast({ message: '删除失败' });
            });
        },
      },
    });
  }

  private handleClearAll(): void {
    AlertDialog.show({
      message: '确定要清空所有浏览历史吗？此操作不可撤销。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '清空',
        fontColor: '#ff4d4f',
        action: () => {
          batchDelReadHistory({ clear: true })
            .then(() => {
              this.loadFirst();
            })
            .catch(() => {
              promptAction.showToast({ message: '清空失败' });
            });
        },
      },
    });
  }

  private onTopRight(): void {
    if (this.selecting) {
      this.exitSelection();
    } else if (this.items.length > 0) {
      this.handleClearAll();
    }
  }

  @Builder
  rowItem(item: ReadHistoryDataItem, idx: number) {
    Row({ space: 10 }) {
      if (this.selecting) {
        Text(this.isSelected(this.makeKey(item)) ? '●' : '○')
          .fontSize(18)
          .fontColor(this.isSelected(this.makeKey(item))
            ? ZhihuColors.primary : ZhihuColors.textTertiary)
      }
      Column({ space: 6 }) {
        Text(this.safeTitle(item))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (this.safeSummary(item).length > 0) {
          Text(this.safeSummary(item))
            .fontSize(15)
            .fontColor(ZhihuColors.textSecondary)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        Row() {
          Text(this.safeMatrixText(item))
            .fontSize(14)
            .fontColor(ZhihuColors.textTertiary)
            .layoutWeight(1)
          Text(this.safeReadTime(item) > 0
            ? formatDate(this.safeReadTime(item)) : '')
            .fontSize(14)
            .fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .borderRadius(12)
    .onClick(() => {
      this.openItem(item);
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          if (!this.selecting) {
            this.selecting = true;
          }
        })
    )
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18).color(ZhihuColors.textTertiary)
          Text('加载中…')
        }
        .justifyContent(FlexAlign.Center).width('100%').padding(12)
      } else if (this.isEnd && this.items.length > 0) {
        Text('— 没有更多了 —')
          .fontSize(15).fontColor(ZhihuColors.textTertiary)
          .width('100%').textAlign(TextAlign.Center).padding(12)
      }
    }
  }

  build() {
    Column() {
      ProfileTopBar({
        title: '最近浏览',
        rightText: this.selecting ? '完成' : (this.items.length > 0 ? '清空' : ''),
        onRightClick: () => {
          this.onTopRight();
        },
      })
      if (!this.loggedIn) {
        Column({ space: 16 }) {
          Blank()
          Text('登录后才能查看浏览历史')
          Button('登录知乎')
            .width(220).height(44).backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              router.pushUrl({ url: 'pages/LoginPage' });
            })
          Blank()
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
          Text('加载中…')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.items.length === 0) {
        Column({ space: 16 }) {
          Text(this.error)
          Button('重试')
            .fontSize(16).backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loadFirst();
            })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column({ space: 8 }) {
          Text(this.filteredEmpty ? '最近两天暂无浏览记录' : '这里空空如也')
            .fontSize(15)
            .fontColor(ZhihuColors.textSecondary)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8, scroller: this.scroller }) {
          ForEach(this.items, (item: ReadHistoryDataItem, idx: number) => {
            ListItem() {
              this.rowItem(item, idx)
            }
          }, (item: ReadHistoryDataItem, idx: number) => {
            const extra = this.safeExtra(item);
            const tok = extra !== null ? extra.content_token : '';
            return 'history-' + tok + '-' + String(idx);
          })
          ListItem() {
            this.footer()
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 12 })
        .onReachEnd(() => {
          this.loadMore();
        })
        .scrollBar(BarState.Off)

        if (this.selecting && this.selectedKeys.length > 0) {
          Button('删除选中 (' + String(this.selectedKeys.length) + ')')
            .width('90%')
            .height(44)
            .fontSize(17)
            .fontColor(ZhihuColors.textInverse)
            .backgroundColor(ZhihuColors.danger)
            .margin({ bottom: 16 })
            .onClick(() => {
              this.handleDeleteSelected();
            })
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
