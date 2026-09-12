/**
 * pages/NotificationsPage —— 消息通知列表（赞同/评论/关注/邀请）+ 一键已读。
 * 上游: ~/workbuddy/zhihu--/app/notifications/index.tsx
 * API: getNotifications(nextUrl, entryName)、markAllNotificationsRead()
 * 降级: 上游点击通知跳转详情（answer/question/article/user）未接入，本页仅展示，不响应点击；
 *       通知卡片图标按 verb 类型用自绘彩色圆 + 文字表达，不使用矢量图标库。
 */

import { router } from '@kit.ArkUI';
import { getNotifications, markAllNotificationsRead } from '../api/notification';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { formatRelativeTime } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';

interface NContent {
  verb?: string;
  text?: string;
  title?: string;
  sub_text?: string;
}

interface NItem {
  id: string;
  type?: string;
  create_time?: number;
  content?: NContent;
}

interface NPaging {
  is_end?: boolean;
  next?: string;
}

interface NResponse {
  data?: NItem[];
  paging?: NPaging;
}

interface NotifyTab {
  label: string;
  value: string;
}

const TABS: NotifyTab[] = [
  { label: '全部', value: 'all' },
  { label: '赞同', value: 'like' },
  { label: '评论', value: 'comment' },
  { label: '关注', value: 'follow' },
  { label: '邀请', value: 'invite' },
];

@Entry
@Component
struct NotificationsPage {
  @State items: NItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;
  @State tabValue: string = 'all';
  @State marking: boolean = false;
  private nextUrl: string = '';
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadFirst();
  }

  private iconColor(item: NItem): string {
    const verb: string = item.content?.verb ?? '';
    const type: string = item.type ?? '';
    if (verb.includes('赞') || verb.includes('喜欢') || type.includes('VOTE_UP')) {
      return ZhihuColors.danger;
    }
    if (verb.includes('评论') || verb.includes('回复') || type.includes('COMMENT')) {
      return ZhihuColors.primary;
    }
    if (verb.includes('关注') || type.includes('FOLLOW')) {
      return ZhihuColors.success;
    }
    if (verb.includes('邀请') || type.includes('INVITE')) {
      return ZhihuColors.warning;
    }
    return ZhihuColors.textTertiary;
  }

  private bodyText(item: NItem): string {
    const c = item.content;
    if (c === undefined) {
      return '新的动态';
    }
    if (typeof c.text === 'string' && c.text.length > 0) {
      return c.text;
    }
    if (typeof c.title === 'string' && c.title.length > 0) {
      return c.title;
    }
    if (typeof c.sub_text === 'string' && c.sub_text.length > 0) {
      return c.sub_text;
    }
    return '新的动态';
  }

  async loadFirst(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.inFlight = true;
    try {
      const resp = await getNotifications('', this.tabValue);
      this.applyPage(resp, true);
    } catch (e) {
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.loading = false;
      this.inFlight = false;
    }
  }

  async loadMore(): Promise<void> {
    if (this.inFlight || this.isEnd || this.nextUrl.length === 0) {
      return;
    }
    this.inFlight = true;
    this.loadingMore = true;
    try {
      const resp = await getNotifications(this.nextUrl, this.tabValue);
      this.applyPage(resp, false);
    } catch (e) {
      // 翻页失败保留旧数据
    } finally {
      this.inFlight = false;
      this.loadingMore = false;
    }
  }

  private applyPage(resp: object, replace: boolean): void {
    const r = resp as NResponse;
    this.nextUrl = r.paging?.next ?? '';
    this.isEnd = r.paging?.is_end ?? true;
    const incoming: NItem[] = r.data ?? [];
    this.items = replace ? incoming : this.items.concat(incoming);
  }

  private switchTab(value: string): void {
    if (this.tabValue === value) {
      return;
    }
    this.tabValue = value;
    this.items = [];
    this.nextUrl = '';
    this.isEnd = false;
    this.loadFirst();
  }

  private async markAllRead(): Promise<void> {
    if (this.marking) {
      return;
    }
    this.marking = true;
    try {
      await markAllNotificationsRead();
    } catch (e) {
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.marking = false;
    }
  }

  @Builder
  topBar() {
    Row() {
      Text('←')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(22)
        .fontColor(ZhihuColors.text)
        .width(40)
        .onClick(() => {
          router.back();
        })
      Blank()
      Text('消息通知')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
      Blank()
      if (this.marking) {
        LoadingProgress().width(18).height(18).color(ZhihuColors.primary)
      } else {
        Text('全部已读')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(14)
          .fontColor(ZhihuColors.primary)
          .onClick(() => {
            this.markAllRead();
          })
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  tabBar() {
    Row({ space: 8 }) {
      ForEach(TABS, (tab: NotifyTab) => {
        Text(tab.label)
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(13)
          .fontWeight(this.tabValue === tab.value ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.tabValue === tab.value ? ZhihuColors.primary : ZhihuColors.textSecondary)
          .padding({ left: 14, right: 14, top: 7, bottom: 7 })
          .backgroundColor(
            this.tabValue === tab.value ? ZhihuColors.primary + '1A' : ZhihuColors.backgroundSecondary)
          .borderRadius(16)
          .onClick(() => {
            this.switchTab(tab.value);
          })
      }, (tab: NotifyTab) => tab.value)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(16).height(16).color(ZhihuColors.textTertiary)
          Text('加载中…')
            .copyOption(CopyOptions.LocalDevice).fontSize(12).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(12)
      } else if (this.isEnd && this.items.length > 0) {
        Text('— 没有更多了 —')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(12)
          .fontColor(ZhihuColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(12)
      }
    }
  }

  @Builder
  listView() {
    List({ space: 10, scroller: this.scroller }) {
      ForEach(this.items, (item: NItem, index: number) => {
        ListItem() {
          Row({ space: 12 }) {
            Column()
              .width(40)
              .height(40)
              .borderRadius(20)
              .backgroundColor(this.iconColor(item) + '1A')
            Column({ space: 4 }) {
              Row() {
                Text(item.content?.verb ?? '系统通知')
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.iconColor(item))
                Blank()
                Text(formatRelativeTime(item.create_time ?? 0))
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(11)
                  .fontColor(ZhihuColors.textTertiary)
              }
              .width('100%')
              Text(this.bodyText(item))
                .copyOption(CopyOptions.LocalDevice)
                .fontSize(13)
                .fontColor(ZhihuColors.text)
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(14)
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .borderRadius(10)
        }
      }, (item: NItem, index: number) => String(index) + '-' + item.id)
      ListItem() {
        this.footer()
      }
    }
    .onReachEnd(() => {
      this.loadMore();
    })
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 12, right: 12, top: 8, bottom: 12 })
    .scrollBar(BarState.Off)
  }

  @Builder
  loginPrompt() {
    Column({ space: 16 }) {
      Blank()
      Text('查看消息通知前请先登录知乎账号')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(14)
        .fontColor(ZhihuColors.textSecondary)
      Button('去登录')
        .width(200)
        .height(42)
        .fontSize(15)
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

  build() {
    Column() {
      this.topBar()
      if (!authStore.isLoggedIn) {
        this.loginPrompt()
      } else {
        this.tabBar()
        if (this.loading && this.items.length === 0) {
          Column({ space: 8 }) {
            LoadingProgress().width(40).height(40).color(ZhihuColors.primary)
            Text('加载中…')
              .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary)
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.error.length > 0 && this.items.length === 0) {
          Column({ space: 16 }) {
            Text(this.error)
              .copyOption(CopyOptions.LocalDevice).fontSize(14).fontColor(ZhihuColors.textSecondary)
            Button('重试')
              .fontSize(14)
              .backgroundColor(ZhihuColors.primary)
              .onClick(() => {
                this.loadFirst();
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.items.length === 0) {
          Column({ space: 8 }) {
            Blank()
            Text('暂无通知')
              .copyOption(CopyOptions.LocalDevice).fontSize(14).fontColor(ZhihuColors.textTertiary)
            Blank()
          }
          .width('100%')
          .layoutWeight(1)
        } else {
          this.listView()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
