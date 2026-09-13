/**
 * pages/SearchPage —— 搜索页（移植自上游 app/search.tsx，按 Android v0.6.0 截图 06 重构布局）。
 * 结构：返回箭头 + 搜索框(占位/清除×/右侧搜索) + 结果顶部「综合/用户」tab
 *       + 筛选行(筛选 badge / 时间下拉 / 重置) + 结果统计行 + 结果卡片。
 * 功能层保留：搜索建议、offset 分页、综合/用户两类结果解析。
 * 时间筛选接到 searchContent 的 SearchContentOptions.time_interval。
 */

import { router } from '@kit.ArkUI';
import { getSearchSuggest, searchContent, SearchContentOptions } from '../api/search';
import { ZhihuSearchResponse, ZhihuSearchResultItem } from '../model/zhihu';
import { FeedItem, FeedAuthor } from '../api/feed';
import { ZhihuColors } from '../utils/theme';
import { plainHighlight } from '../components/interaction/textUtil';

interface SuggestHit {
  query: string;
}

interface PeopleHit {
  id: string;
  name: string;
  headline: string;
  avatar: string;
}

const TABS: string[] = ['综合', '用户'];

/** time_interval 下拉选项：value 直接对应 SearchContentOptions.time_interval */
interface TimeOption {
  label: string;
  value: string;
}

const TIME_OPTIONS: TimeOption[] = [
  { label: '不限时间', value: '' },
  { label: '一天内', value: 'a_day' },
  { label: '一周内', value: 'a_week' },
  { label: '一月内', value: 'a_month' },
  { label: '三月内', value: 'three_months' },
];

function timeLabel(value: string): string {
  if (value.length === 0) {
    return '不限';
  }
  for (const opt of TIME_OPTIONS) {
    if (opt.value === value) {
      return opt.label;
    }
  }
  return '不限';
}

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
struct SearchPage {
  @State query: string = '';
  @State submitted: string = '';
  @State searching: boolean = false;
  @State activeTab: number = 0;

  @State suggestions: SuggestHit[] = [];
  @State showSuggest: boolean = false;

  @State timeFilter: string = '';

  @State feedResults: FeedItem[] = [];
  @State peopleResults: PeopleHit[] = [];
  @State loading: boolean = false;
  @State error: string = '';
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;

  pageOffset: number = 0;
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    // 进入即聚焦输入由系统接管；不自动发请求
  }

  // ---------------- Tab → API 参数 ----------------
  private tabIsPeople(): boolean {
    return this.activeTab === 1;
  }

  private tabSearchType(): string {
    return this.tabIsPeople() ? 'people' : 'general';
  }

  private tabOptions(): SearchContentOptions {
    const opt: SearchContentOptions = {};
    if (this.timeFilter.length > 0) {
      opt.time_interval =
        this.timeFilter as 'a_day' | 'a_week' | 'a_month' | 'three_months';
    }
    return opt;
  }

  // ---------------- 建议 ----------------
  async onInputChange(text: string): Promise<void> {
    this.query = text;
    if (this.searching) {
      this.showSuggest = false;
      return;
    }
    if (text.trim().length === 0) {
      this.suggestions = [];
      this.showSuggest = false;
      return;
    }
    this.showSuggest = true;
    try {
      const raw = await getSearchSuggest(text.trim());
      const rec = raw as object as Record<string, object>;
      const sug = rec['suggest'];
      const list: SuggestHit[] = [];
      if (Array.isArray(sug)) {
        const arr = sug as object[];
        for (const s of arr) {
          const sRec = s as Record<string, object>;
          list.push({ query: String(sRec['query'] ?? '') });
        }
      }
      this.suggestions = list;
    } catch (e) {
      this.suggestions = [];
    }
  }

  // ---------------- 搜索 ----------------
  async startSearch(kw: string): Promise<void> {
    const word: string = kw.trim();
    if (word.length === 0) {
      return;
    }
    this.query = word;
    this.submitted = word;
    this.searching = true;
    this.showSuggest = false;
    this.pageOffset = 0;
    await this.runSearch(0, true);
  }

  async switchTab(index: number): Promise<void> {
    this.activeTab = index;
    if (!this.searching || this.submitted.length === 0) {
      return;
    }
    this.pageOffset = 0;
    await this.runSearch(0, true);
  }

  async applyTimeFilter(value: string): Promise<void> {
    this.timeFilter = value;
    if (!this.searching || this.submitted.length === 0) {
      return;
    }
    this.pageOffset = 0;
    await this.runSearch(0, true);
  }

  async resetFilter(): Promise<void> {
    if (this.timeFilter.length === 0) {
      return;
    }
    await this.applyTimeFilter('');
  }

  async runSearch(offset: number, replace: boolean): Promise<void> {
    if (this.submitted.length === 0) {
      return;
    }
    this.inFlight = true;
    if (replace) {
      this.loading = true;
      this.error = '';
    } else {
      this.loadingMore = true;
    }
    try {
      const resp: ZhihuSearchResponse = await searchContent(
        this.submitted,
        offset,
        20,
        this.tabSearchType(),
        this.tabOptions(),
      );
      const feed: FeedItem[] = [];
      const people: PeopleHit[] = [];
      for (const item of resp.data) {
        if (this.tabIsPeople()) {
          people.push(this.parsePeople(item));
        } else {
          const fi = this.parseFeed(item);
          if (fi !== null) {
            feed.push(fi as FeedItem);
          }
        }
      }
      if (this.tabIsPeople()) {
        this.peopleResults = replace ? people : this.peopleResults.concat(people);
      } else {
        this.feedResults = replace ? feed : this.feedResults.concat(feed);
      }
      this.isEnd = resp.paging.is_end;
      this.pageOffset = offset + 20;
    } catch (e) {
      if (replace) {
        this.error = '搜索失败，请稍后重试';
      }
    } finally {
      this.inFlight = false;
      this.loading = false;
      this.loadingMore = false;
    }
  }

  private parsePeople(item: ZhihuSearchResultItem): PeopleHit {
    const obj = item.object as object as Record<string, object>;
    const name: string = plainHighlight(item.highlight.title ?? '') || String(obj['name'] ?? '知乎用户');
    const headline: string = plainHighlight(item.highlight.description ?? '') || String(obj['headline'] ?? '');
    return {
      id: String(obj['id'] ?? ''),
      name: name,
      headline: headline,
      avatar: String(obj['avatar_url'] ?? ''),
    };
  }

  private parseFeed(item: ZhihuSearchResultItem): FeedItem | null {
    const obj = item.object as object as Record<string, object>;
    const objType: string = String(obj['type'] ?? '');
    if (objType === 'people') {
      return null;
    }
    // question 子对象
    const question = obj['question'] as Record<string, object> | undefined;
    const title: string =
      plainHighlight(item.highlight.title ?? '') ||
      String(question !== undefined ? question['name'] ?? '' : '') ||
      String(obj['title'] ?? '无标题');
    const excerpt: string =
      plainHighlight(item.highlight.description ?? '') || String(obj['excerpt'] ?? '');

    // 作者
    const authorRec = obj['author'] as Record<string, object> | undefined;
    const author: FeedAuthor = {
      id: authorRec === undefined ? '' : String(authorRec['id'] ?? ''),
      name: authorRec === undefined ? '匿名用户' : String(authorRec['name'] ?? '匿名用户'),
      avatar: authorRec === undefined ? '' : String(authorRec['avatar_url'] ?? ''),
    };

    // 配图
    let image: string | null = null;
    const thumb = obj['thumbnail_info'] as Record<string, object> | undefined;
    if (thumb !== undefined) {
      const thumbs = thumb['thumbnails'] as object[] | undefined;
      if (Array.isArray(thumbs) && thumbs.length > 0) {
        const t0 = thumbs[0] as Record<string, object>;
        image = String(t0['url'] ?? '');
      }
    }

    const authorIdStr: string = String(obj['id'] ?? (question !== undefined ? question['id'] ?? '' : ''));
    const typeStr: string = objType + 's';
    const voteCount: number = Number(obj['voteup_count'] ?? 0);
    const commentCount: number = Number(obj['comment_count'] ?? 0);

    const rel = obj['relationship'] as Record<string, object> | undefined;
    const voted: number = rel === undefined ? 0 : Number(rel['voting'] ?? 0);

    const feedItem: FeedItem = {
      id: authorIdStr,
      type: typeStr,
      title: title,
      excerpt: excerpt,
      author: author,
      image: image,
      voteCount: voteCount,
      commentCount: commentCount,
      voted: voted,
    };
    if (question !== undefined) {
      feedItem.questionId = String(question['id'] ?? '');
    }
    return feedItem;
  }

  private openDetail(item: FeedItem): void {
    router.pushUrl({
      url: 'pages/DetailPage',
      params: {
        id: item.id,
        type: item.type,
        title: item.title,
        excerpt: item.excerpt,
        url: '',
        questionId: item.questionId ?? '',
      },
    });
  }

  async loadMore(): Promise<void> {
    if (this.inFlight || this.isEnd || !this.searching) {
      return;
    }
    await this.runSearch(this.pageOffset, false);
  }

  // ---------------- UI ----------------
  @Builder
  topBar() {
    Row({ space: 8 }) {
      Text('‹')
        .fontSize(28)
        .fontColor(ZhihuColors.text)
        .padding({ left: 4, right: 4 })
        .onClick(() => {
          router.back();
        })
      Row() {
        Text('🔍')
        TextInput({ placeholder: '搜索知乎内容…', text: this.query })
          .layoutWeight(1)
          .height(36)
          .backgroundColor(Color.Transparent)
          .fontSize(16)
          .placeholderColor(ZhihuColors.textTertiary)
          .onChange((v: string) => {
            this.onInputChange(v);
          })
          .onSubmit(() => {
            this.startSearch(this.query);
          })
        if (this.query.length > 0) {
          Stack() {
            Text('✕')
          }
          .width(18)
          .height(18)
          .borderRadius(9)
          .backgroundColor(ZhihuColors.textTertiary)
          .margin({ right: 4 })
          .onClick(() => {
            this.query = '';
            this.suggestions = [];
            this.showSuggest = false;
          })
        }
      }
      .layoutWeight(1)
      .height(36)
      .backgroundColor(ZhihuColors.backgroundTertiary)
      .borderRadius(18)
      .padding({ left: 12, right: 6 })
      .alignItems(VerticalAlign.Center)
      Text('搜索')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.primary)
        .padding({ left: 6, right: 6 })
        .onClick(() => {
          this.startSearch(this.query);
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 8 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  tabBar() {
    Row({ space: 28 }) {
      ForEach(TABS, (label: string, index: number) => {
        Column() {
          Text(label)
            .fontSize(18)
            .fontColor(this.activeTab === index ? ZhihuColors.primary : ZhihuColors.textSecondary)
            .fontWeight(this.activeTab === index ? FontWeight.Bold : FontWeight.Normal)
          Divider()
            .strokeWidth(3)
            .color(this.activeTab === index ? ZhihuColors.primary : Color.Transparent)
            .width(24)
            .padding({ top: 4 })
        }
        .onClick(() => {
          this.switchTab(index);
        })
      })
    }
    .width('100%')
    .height(46)
    .padding({ left: 14 })
    .alignItems(VerticalAlign.Bottom)
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  filterBar() {
    Row({ space: 10 }) {
      // 筛选 pill（带激活数 badge）
      Row({ space: 6 }) {
        Text('≡')
        Text('筛选')
        if (this.timeFilter.length > 0) {
          Stack() {
            Text('1')
          }
          .width(16)
          .height(16)
          .borderRadius(8)
          .backgroundColor(ZhihuColors.primary)
        }
      }
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(17)
      .backgroundColor(ZhihuColors.backgroundTertiary)
      // 时间下拉 pill
      Row({ space: 4 }) {
        Text('时间：' + timeLabel(this.timeFilter))
          .fontSize(16)
          .fontColor(ZhihuColors.primary)
        Text('▾')
      }
      .height(34)
      .padding({ left: 12, right: 12 })
      .borderRadius(17)
      .backgroundColor('#e3f0ff')
      .bindMenu(this.timeMenuItems())
      Blank()
      Text('重置')
        .fontSize(16)
        .fontColor(ZhihuColors.textSecondary)
        .onClick(() => {
          this.resetFilter();
        })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  private timeMenuItems(): MenuElement[] {
    const items: MenuElement[] = [];
    for (const opt of TIME_OPTIONS) {
      items.push({
        value: opt.label,
        action: () => {
          this.applyTimeFilter(opt.value);
        },
      });
    }
    return items;
  }

  @Builder
  statRow() {
    Row({ space: 8 }) {
      Text('“' + this.submitted + '”的结果')
        .fontSize(15)
        .fontColor(ZhihuColors.textTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      Text('已加载 ' + this.loadedCount() + ' 条')
        .fontSize(15)
        .fontColor(ZhihuColors.textTertiary)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 8 })
    .backgroundColor(ZhihuColors.background)
  }

  private loadedCount(): number {
    return this.tabIsPeople() ? this.peopleResults.length : this.feedResults.length;
  }

  @Builder
  suggestList() {
    List({ space: 0 }) {
      ForEach(this.suggestions, (s: SuggestHit, index: number) => {
        ListItem() {
          Row({ space: 12 }) {
            Text('🔍')
            Text(s.query)
              .fontSize(17)
              .fontColor(ZhihuColors.text)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 13, bottom: 13 })
          .border({ width: { bottom: 0.5 }, color: ZhihuColors.border })
          .onClick(() => {
            this.startSearch(s.query);
          })
        }
      }, (s: SuggestHit, index: number) => String(index) + '-' + s.query)
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
  }

  @Builder
  peopleRow(p: PeopleHit) {
    Row({ space: 12 }) {
      Image(p.avatar)
        .width(44)
        .height(44)
        .borderRadius(22)
        .objectFit(ImageFit.Cover)
        .backgroundColor(ZhihuColors.backgroundTertiary)
      Column({ space: 3 }) {
        Text(p.name)
        Text(p.headline)
          .fontSize(15)
          .fontColor(ZhihuColors.textSecondary)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .borderRadius(10)
  }

  /** 综合结果卡片：作者行 + 标题 + 摘要(右缩略图) + ▲/○/☆ 计数行 */
  @Builder
  resultCard(item: FeedItem) {
    Column({ space: 8 }) {
      if (item.author.avatar.length === 0 || item.author.name === '匿名用户') {
        Text('匿名用户')
          .fontSize(16)
          .fontColor(ZhihuColors.textSecondary)
          .width('100%')
          .textAlign(TextAlign.Center)
      } else {
        Row({ space: 8 }) {
          Image(item.author.avatar)
            .width(32)
            .height(32)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
            .backgroundColor(ZhihuColors.backgroundTertiary)
          Text(item.author.name)
            .fontSize(16)
            .fontColor(ZhihuColors.text)
            .maxLines(1)
            .layoutWeight(1)
        }
        .width('100%')
      }

      if (item.title.length > 0) {
        Text(item.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
      }

      if (item.excerpt.length > 0) {
        Row({ space: 10 }) {
          Text(item.excerpt)
            .fontSize(16)
            .fontColor(ZhihuColors.textSecondary)
            .maxLines(3)
            .lineHeight(20)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (item.image !== null && item.image.length > 0) {
            Image(item.image)
              .width(88)
              .height(88)
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
          Text('▲')
          Text(formatCount(item.voteCount))
        }
        Row({ space: 4 }) {
          Text('○')
          Text(formatCount(item.commentCount))
        }
        if (item.favlistsCount !== undefined && item.favlistsCount > 0) {
          Row({ space: 4 }) {
            Text('☆')
            Text(formatCount(item.favlistsCount))
          }
        }
        Blank()
        Text('···')
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
  resultList() {
    List({ scroller: this.scroller }) {
      if (this.tabIsPeople()) {
        ForEach(this.peopleResults, (p: PeopleHit, index: number) => {
          ListItem() {
            this.peopleRow(p)
          }
        }, (p: PeopleHit, index: number) => p.id + '-' + String(index))
      } else {
        ForEach(this.feedResults, (item: FeedItem, index: number) => {
          ListItem() {
            this.resultCard(item)
          }
          .onClick(() => {
            this.openDetail(item);
          })
        }, (item: FeedItem, index: number) => String(index) + '-' + item.id + '-' + item.type)
      }
      ListItem() {
        Column({ space: 6 }) {
          if (this.loadingMore) {
            Row({ space: 8 }) {
              LoadingProgress().width(16).height(16).color(ZhihuColors.textTertiary)
              Text('加载中…')
            }
          } else if (this.isEnd && (this.feedResults.length > 0 || this.peopleResults.length > 0)) {
            Text('— 没有更多了 —')
          }
        }
        .width('100%')
        .padding(14)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .onReachEnd(() => {
      this.loadMore();
    })
  }

  build() {
    Column() {
      this.topBar()

      if (this.searching) {
        this.tabBar()
        this.filterBar()
        this.statRow()
      }

      // 主体
      if (!this.searching && this.showSuggest && this.suggestions.length > 0) {
        this.suggestList()
      } else if (!this.searching) {
        Column() {
          Text('搜索你想知道的内容')
            .fontSize(17)
            .fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress().width(40).height(40).color(ZhihuColors.primary)
          Text('搜索中…')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0) {
        Column({ space: 16 }) {
          Text(this.error)
          Button('重试')
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.runSearch(0, true);
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.feedResults.length === 0 && this.peopleResults.length === 0) {
        Column({ space: 8 }) {
          Text('没有找到相关内容')
          Text('换个关键词试试')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        this.resultList()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
