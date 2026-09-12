/**
 * pages/InboxPage —— 私信会话列表。
 * 上游: ~/workbuddy/zhihu--/app/inbox.tsx
 * API: getInbox(nextUrl?) → InboxThread[]；点击进入 ChatPage。
 */

import { router } from '@kit.ArkUI';
import { getInbox, InboxThread, InboxResponse } from '../api/chat';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { formatRelativeTime } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';

@Entry
@Component
struct InboxPage {
  @State threads: InboxThread[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;
  private nextUrl: string = '';
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.loadFirst();
  }

  async loadFirst(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.inFlight = true;
    try {
      const resp = await getInbox('');
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
      const resp = await getInbox(this.nextUrl);
      this.applyPage(resp, false);
    } catch (e) {
      // 翻页失败保留旧数据
    } finally {
      this.inFlight = false;
      this.loadingMore = false;
    }
  }

  private applyPage(resp: import('../api/chat').InboxResponse, replace: boolean): void {
    this.nextUrl = resp.paging?.next ?? '';
    this.isEnd = resp.paging?.is_end ?? true;
    this.threads = replace ? resp.data : this.threads.concat(resp.data);
  }

  private openChat(thread: InboxThread): void {
    router.pushUrl({
      url: 'pages/ChatPage',
      params: {
        userId: thread.participant.id,
        name: thread.participant.name,
      },
    });
  }

  @Builder
  topBar() {
    Row() {
      Text('←')
        .fontSize(22)
        .fontColor(ZhihuColors.text)
        .width(40)
        .onClick(() => {
          router.back();
        })
      Blank()
      Text('我的私信')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
      Blank()
      Text('   ').fontSize(22).width(40)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(16).height(16).color(ZhihuColors.textTertiary)
          Text('加载中…').fontSize(12).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(12)
      } else if (this.isEnd && this.threads.length > 0) {
        Text('— 没有更多了 —')
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
      ForEach(this.threads, (thread: InboxThread, index: number) => {
        ListItem() {
          Row({ space: 12 }) {
            Stack({ alignContent: Alignment.TopEnd }) {
              Image(thread.participant.avatar_url)
                .width(52)
                .height(52)
                .borderRadius(26)
                .objectFit(ImageFit.Cover)
                .backgroundColor(ZhihuColors.backgroundTertiary)
              if (thread.unread_count > 0) {
                Text(thread.unread_count > 99 ? '99+' : String(thread.unread_count))
                  .fontSize(10)
                  .fontColor(ZhihuColors.textInverse)
                  .backgroundColor(ZhihuColors.danger)
                  .borderRadius(9)
                  .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                  .translate({ x: 4, y: -4 })
              }
            }
            Column({ space: 4 }) {
              Row() {
                Text(thread.participant.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ZhihuColors.text)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Blank()
                Text(formatRelativeTime(thread.updated_time))
                  .fontSize(11)
                  .fontColor(ZhihuColors.textTertiary)
              }
              .width('100%')
              Text(thread.snippet)
                .fontSize(13)
                .fontColor(ZhihuColors.textSecondary)
                .maxLines(2)
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
        .onClick(() => {
          this.openChat(thread);
        })
      }, (thread: InboxThread, index: number) => String(index) + '-' + thread.id)
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
      Text('查看私信前请先登录知乎账号')
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
      } else if (this.loading && this.threads.length === 0) {
        Column({ space: 8 }) {
          LoadingProgress().width(40).height(40).color(ZhihuColors.primary)
          Text('加载中…').fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.threads.length === 0) {
        Column({ space: 16 }) {
          Text(this.error).fontSize(14).fontColor(ZhihuColors.textSecondary)
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
      } else if (this.threads.length === 0) {
        Column({ space: 8 }) {
          Blank()
          Text('暂无私信').fontSize(14).fontColor(ZhihuColors.textTertiary)
          Blank()
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        this.listView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
