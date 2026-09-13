/**
 * pages/CollectionsListPage —— 我的收藏夹列表。
 * 上游：app/collections/index.tsx。
 * 降级：上游的"新建/编辑收藏夹"BottomSheet 表单暂未移植（见汇报遗留），
 *       保留长按删除与点击进入详情。
 */

import { router, promptAction } from '@kit.ArkUI';
import {
  ZhihuCollection,
  getMyCollections,
  deleteCollection,
} from '../api/collection';
import { ApiError } from '../api/httpClient';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { ProfileTopBar } from '../components/profile/ProfileTopBar';

@Entry
@Component
export struct CollectionsListPage {
  @State items: ZhihuCollection[] = [];
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
      const resp = await getMyCollections(20, this.pageOffset);
      this.items = reset ? resp.data : this.items.concat(resp.data);
      this.isEnd = resp.paging.is_end;
      this.pageOffset = this.pageOffset + 20;
    } catch (e) {
      // 显示真实原因（HTTP 状态码 + 服务端消息），便于定位
      let detail: string = String(e);
      if (e instanceof ApiError) {
        detail = 'HTTP ' + String(e.status) + ' ' + e.message;
      }
      console.error('[ZhihuLite] collections failed: ' + detail);
      this.error = '收藏夹加载失败：' + detail;
    } finally {
      this.inFlight = false;
    }
  }

  private openDetail(item: ZhihuCollection): void {
    router.pushUrl({
      url: 'pages/CollectionDetailPage',
      params: { id: String(item.id) },
    });
  }

  private askDelete(item: ZhihuCollection): void {
    AlertDialog.show({
      message: '确定要删除"' + item.title + '"吗？内部内容也会一并移出。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '删除',
        fontColor: '#ff4d4f',
        action: () => {
          deleteCollection(item.id)
            .then(() => {
              this.loadFirst();
            })
            .catch(() => {
              promptAction.showToast({ message: '删除失败' });
            });
        },
      },
    });
  }

  @Builder
  rowItem(item: ZhihuCollection, idx: number) {
    Row({ space: 14 }) {
      // 图标块
      Row() {
        Text(item.is_public ? '📁' : '🔒')
          .fontSize(22)
      }
      .width(48)
      .height(48)
      .borderRadius(8)
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(0,132,255,0.06)')
      Column({ space: 3 }) {
        Text(item.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (item.description && item.description.length > 0) {
          Text(item.description)
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        Text((item.answer_count ?? 0) + ' 内容 · ' + (item.follower_count ?? 0) + ' 关注')
          .fontSize(13)
          .fontColor(ZhihuColors.textTertiary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .onClick(() => {
      this.openDetail(item);
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.askDelete(item);
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
          .fontSize(14).fontColor(ZhihuColors.textTertiary)
          .width('100%').textAlign(TextAlign.Center).padding(12)
      }
    }
  }

  build() {
    Column() {
      ProfileTopBar({ title: '我的收藏夹' })
      if (!this.loggedIn) {
        Column({ space: 16 }) {
          Blank()
          Text('登录后才能查看收藏夹')
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
            .fontSize(15).backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loggedIn = authStore.isLoggedIn;
              if (this.loggedIn) {
                this.loadFirst();
              }
            })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column() {
          Text('你还没有收藏夹')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8, scroller: this.scroller }) {
          ForEach(this.items, (item: ZhihuCollection, idx: number) => {
            ListItem() {
              this.rowItem(item, idx)
            }
          }, (item: ZhihuCollection, idx: number) => String(idx) + '-' + String(item.id))
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
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
